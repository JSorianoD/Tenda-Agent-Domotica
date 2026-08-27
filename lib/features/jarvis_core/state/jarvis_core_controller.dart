import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/agent/n8n_agent_service.dart';
import '../../../services/home_connector/ha_home_connector.dart';
import '../../../services/home_connector/home_connector.dart';

/// The full state exposed by [JarvisCoreController].
///
/// Combines the animation state with an optional subtitle message
/// (agent reply, error text, or default status).
class JarvisCoreState {
  const JarvisCoreState({
    this.animationState = JarvisState.idle,
    this.subtitle = 'Conectado · En espera',
  });

  final JarvisState animationState;
  final String subtitle;

  JarvisCoreState copyWith({JarvisState? animationState, String? subtitle}) {
    return JarvisCoreState(
      animationState: animationState ?? this.animationState,
      subtitle: subtitle ?? this.subtitle,
    );
  }
}

/// Riverpod provider for the Jarvis core state.
final jarvisCoreProvider =
    StateNotifierProvider<JarvisCoreController, JarvisCoreState>((ref) {
      final connector = ref.watch(homeConnectorProvider);
      final agent = ref.watch(agentServiceProvider);
      return JarvisCoreController(connector, agent);
    });

/// Controls the Jarvis core animation state and orchestrates the n8n agent.
///
/// Audio playback uses [AudioPlayer] (audioplayers package) to play the
/// neural audio returned by the n8n workflow.  The transition back to idle
/// is driven by the real [PlayerState.completed] event — not a fixed timer
/// — so short replies return quickly and long ones play fully.
///
/// If [AgentReply.audioBytes] is null (TTS skipped or failed in n8n) a
/// 3-second fallback timer is used so the app never gets stuck.
///
/// On any error the state reverts to idle and the subtitle shows the reason.
class JarvisCoreController extends StateNotifier<JarvisCoreState> {
  JarvisCoreController(this._connector, this._agent)
    : super(const JarvisCoreState()) {
    _subscription = _connector.coreStateChanges.listen((incoming) {
      if (mounted) state = state.copyWith(animationState: incoming);
    });
  }

  final HomeConnector _connector;
  final JarvisAgentService _agent;
  late final StreamSubscription<JarvisState> _subscription;

  // ── Audio player ───────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Public API ─────────────────────────────────────────────────────

  /// Cycles through the four animation states on tap (visual testing only).
  // TODO: reemplazar por eventos reales del backend (voz entrante,
  //       respuesta del agente, etc.)
  void cycleState() {
    const values = JarvisState.values;
    final next = (state.animationState.index + 1) % values.length;
    state = JarvisCoreState(
      animationState: values[next],
      subtitle: _defaultSubtitle(values[next]),
    );
  }

  /// Switches the visual state to [JarvisState.listening].
  ///
  /// Called by the widget when microphone recording starts.
  /// The API call is triggered only on the second tap (stop recording).
  void startListening() {
    state = const JarvisCoreState(
      animationState: JarvisState.listening,
      subtitle: 'Escuchando… toca de nuevo para enviar',
    );
  }

  /// Reverts to idle immediately (used when recording is aborted).
  void abortToIdle([String? reason]) {
    state = JarvisCoreState(
      animationState: JarvisState.idle,
      subtitle: reason ?? 'Conectado · En espera',
    );
  }

  /// Send a text command through the full
  /// listening → processing → responding (+ audio) → idle flow.
  Future<void> sendTextCommand(String text) async {
    state = const JarvisCoreState(
      animationState: JarvisState.listening,
      subtitle: 'Escuchando tu comando…',
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));

    state = const JarvisCoreState(
      animationState: JarvisState.processing,
      subtitle: 'Procesando solicitud…',
    );

    try {
      final reply = await _agent.sendText(text);
      if (!mounted) return;
      await _respondAndPlay(reply);
    } catch (e) {
      if (!mounted) return;
      state = JarvisCoreState(
        animationState: JarvisState.idle,
        subtitle: 'Error: $e',
      );
    }
  }

  /// Send an audio file through the full
  /// processing → responding (+ audio) → idle flow.
  Future<void> sendAudioCommand(File audioFile) async {
    state = const JarvisCoreState(
      animationState: JarvisState.processing,
      subtitle: 'Procesando audio…',
    );

    try {
      final reply = await _agent.sendAudio(audioFile);
      if (!mounted) return;
      await _respondAndPlay(reply);
    } catch (e) {
      if (!mounted) return;
      state = JarvisCoreState(
        animationState: JarvisState.idle,
        subtitle: 'Error: $e',
      );
    }
  }

  // ── Internal ───────────────────────────────────────────────────────

  /// Sets responding state and shows [reply.text] in the subtitle immediately,
  /// then plays [reply.audioBytes] if present.
  ///
  /// Idle transition fires on [PlayerState.completed].
  /// If no audio bytes, falls back to a 3-second timeout.
  Future<void> _respondAndPlay(AgentReply reply) async {
    // Show text right away — don't wait for audio to start.
    state = JarvisCoreState(
      animationState: JarvisState.responding,
      subtitle: reply.text,
    );

    if (reply.audioBytes != null) {
      await _playAudioAndWait(reply.audioBytes!);
    } else {
      // Fallback: no audio — hold responding for 3 s then go idle.
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    if (!mounted) return;

    state = const JarvisCoreState(
      animationState: JarvisState.idle,
      subtitle: 'Conectado · En espera',
    );
  }

  /// Plays raw audio bytes and awaits the [PlayerState.completed] event.
  ///
  /// Uses a [Completer] to bridge the stream callback back into async flow.
  /// A guard subscription is cancelled after the first completion event so
  /// the completer is never resolved twice.
  Future<void> _playAudioAndWait(Uint8List bytes) async {
    final completer = Completer<void>();

    StreamSubscription<void>? sub;
    sub = _audioPlayer.onPlayerComplete.listen((_) {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await _audioPlayer.play(BytesSource(bytes));
      await completer.future;
    } catch (e) {
      sub.cancel();
      // Audio playback failure is non-fatal — text is already visible.
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _subscription.cancel();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  static String _defaultSubtitle(JarvisState s) {
    return switch (s) {
      JarvisState.idle => 'Conectado · En espera',
      JarvisState.listening => 'Escuchando tu comando…',
      JarvisState.processing => 'Procesando solicitud…',
      JarvisState.responding => 'Respondiendo…',
    };
  }
}
