import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../services/home_connector/home_connector.dart';
import '../state/jarvis_core_controller.dart';
import 'painters/idle_painter.dart';
import 'painters/listening_painter.dart';
import 'painters/processing_painter.dart';
import 'painters/responding_painter.dart';

/// The animated Jarvis core orb.
///
/// Tap flow:
///   • Idle tap   → checks mic permission, starts recording, state = listening
///   • Listening tap → stops recording, calls [JarvisCoreController.sendAudioCommand]
///                     (processing → responding → idle handled by controller)
///
/// Manages four independent [AnimationController]s — one per [JarvisState].
/// Only the controller for the *current* state runs; the others are stopped
/// to save CPU/battery. All controllers and the [AudioRecorder] are disposed.
class JarvisCoreWidget extends ConsumerStatefulWidget {
  const JarvisCoreWidget({super.key});

  @override
  ConsumerState<JarvisCoreWidget> createState() => _JarvisCoreWidgetState();
}

class _JarvisCoreWidgetState extends ConsumerState<JarvisCoreWidget>
    with TickerProviderStateMixin {
  // ── Animation controllers (one per state) ──────────────────────────
  late final AnimationController _idleController;
  late final AnimationController _listeningController;
  late final AnimationController _processingController;
  late final AnimationController _respondingController;

  // Responding uses 3 staggered sub-animations.
  late final Animation<double> _wave1;
  late final Animation<double> _wave2;
  late final Animation<double> _wave3;

  JarvisState? _activeState;

  // ── Audio recording ────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();

  @override
  void initState() {
    super.initState();

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _listeningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _processingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Responding: total cycle ≈ 2.88 s (3 waves at 0 / 0.72 / 1.44 s offset).
    _respondingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2880),
    );

    _wave1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _respondingController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );
    _wave2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _respondingController,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );
    _wave3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _respondingController,
        curve: const Interval(0.50, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    _listeningController.dispose();
    _processingController.dispose();
    _respondingController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Tap handler ────────────────────────────────────────────────────

  Future<void> _onTap() async {
    final currentState = ref.read(jarvisCoreProvider).animationState;
    final notifier = ref.read(jarvisCoreProvider.notifier);

    switch (currentState) {
      case JarvisState.idle:
        await _startRecording(notifier);

      case JarvisState.listening:
        await _stopAndSend(notifier);

      // Ignore taps while processing or responding.
      case JarvisState.processing:
      case JarvisState.responding:
        break;
    }
  }

  Future<void> _startRecording(JarvisCoreController notifier) async {
    // Check microphone permission.
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de micrófono denegado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Build a unique temp path.
    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}/jarvis_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: path,
    );

    notifier.startListening();
  }

  Future<void> _stopAndSend(JarvisCoreController notifier) async {
    final path = await _recorder.stop();

    if (path == null) {
      notifier.abortToIdle('No se grabó audio');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se grabó audio'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Hands off to controller: processing → responding → idle.
    notifier.sendAudioCommand(File(path));
  }

  // ── Animation state machine ────────────────────────────────────────

  /// Start only the controller matching [state], stop the rest.
  void _activateState(JarvisState state) {
    if (_activeState == state) return;
    _activeState = state;

    // Stop all first.
    _idleController.stop();
    _listeningController.stop();
    _processingController.stop();
    _respondingController.stop();

    switch (state) {
      case JarvisState.idle:
        _idleController.repeat(reverse: true);
      case JarvisState.listening:
        _listeningController.repeat();
      case JarvisState.processing:
        _processingController.repeat();
      case JarvisState.responding:
        _respondingController.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentState = ref.watch(jarvisCoreProvider).animationState;
    _activateState(currentState);

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        width: 260,
        height: 260,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _buildPainter(currentState),
        ),
      ),
    );
  }

  Widget _buildPainter(JarvisState state) {
    switch (state) {
      case JarvisState.idle:
        return AnimatedBuilder(
          key: const ValueKey('idle'),
          animation: _idleController,
          builder: (_, child) => CustomPaint(
            size: const Size(260, 260),
            painter: IdlePainter(animationValue: _idleController.value),
          ),
        );
      case JarvisState.listening:
        return AnimatedBuilder(
          key: const ValueKey('listening'),
          animation: _listeningController,
          builder: (_, child) => CustomPaint(
            size: const Size(260, 260),
            painter: ListeningPainter(
              animationValue: _listeningController.value,
            ),
          ),
        );
      case JarvisState.processing:
        return AnimatedBuilder(
          key: const ValueKey('processing'),
          animation: _processingController,
          builder: (_, child) => CustomPaint(
            size: const Size(260, 260),
            painter: ProcessingPainter(
              animationValue: _processingController.value,
            ),
          ),
        );
      case JarvisState.responding:
        return AnimatedBuilder(
          key: const ValueKey('responding'),
          animation: _respondingController,
          builder: (_, child) => CustomPaint(
            size: const Size(260, 260),
            painter: RespondingPainter(
              wave1: _wave1.value,
              wave2: _wave2.value,
              wave3: _wave3.value,
            ),
          ),
        );
    }
  }
}
