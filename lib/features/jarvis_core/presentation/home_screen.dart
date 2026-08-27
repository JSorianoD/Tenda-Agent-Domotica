import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/greeting.dart';
import '../../../services/home_connector/home_connector.dart';
import '../../devices/state/devices_controller.dart';
import '../../home_assistant/domain/ha_entity.dart';
import '../../home_assistant/state/ha_states_controller.dart';
import '../state/jarvis_core_controller.dart';
import 'jarvis_core_widget.dart';
import 'lights_screen.dart';
import 'security_screen.dart';
import 'weather_screen.dart';

/// Main home screen — status bar, Jarvis core orb, status message, and bottom dock.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _stateLabels = {
    JarvisState.idle: 'EN ESPERA',
    JarvisState.listening: 'ESCUCHANDO',
    JarvisState.processing: 'PROCESANDO',
    JarvisState.responding: 'RESPONDIENDO',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreState = ref.watch(jarvisCoreProvider);
    final currentState = coreState.animationState;
    final haStatesAsync = ref.watch(haStatesProvider);

    return Scaffold(
      body: SafeArea(
        child: haStatesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.tendaGold),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error de conexión:\n$err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(haStatesProvider.notifier).refresh(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.tendaGold,
                      side: const BorderSide(color: AppColors.tendaGold),
                    ),
                    child: const Text('REINTENTAR'),
                  ),
                ],
              ),
            ),
          ),
          data: (haData) => Column(
            children: [
              // ── Status bar & User header ─────────────────────────────
              _StatusBar(personEntities: haData.personEntities),

              const Spacer(flex: 2),

              // ── State label ──────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _stateLabels[currentState]!,
                  key: ValueKey(currentState),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.tendaGrayMuted,
                    letterSpacing: 4,
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Divider ──────────────────────────────────────────────
              Container(
                width: 200,
                height: 1,
                color: AppColors.tendaGold.withValues(alpha: 0.3),
              ),

              const SizedBox(height: 32),

              // ── Core orb ─────────────────────────────────────────────
              const JarvisCoreWidget(),

              const SizedBox(height: 40),

              // ── Status message (subtitle from controller) ───────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey('msg_${coreState.subtitle}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: coreState.subtitle.startsWith('Error')
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.divider,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    coreState.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: coreState.subtitle.startsWith('Error')
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── History hint ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 1,
                    color: AppColors.tendaGold.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'desliza para historial',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.tendaGrayMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 1,
                    color: AppColors.tendaGold.withValues(alpha: 0.3),
                  ),
                ],
              ),

              const Spacer(flex: 3),

              // ── Bottom dock ──────────────────────────────────────────
              _BottomDock(haData: haData),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Status bar
// ═══════════════════════════════════════════════════════════════════════════

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.personEntities});

  final List<HaEntity> personEntities;

  @override
  Widget build(BuildContext context) {
    final person = personEntities.isNotEmpty ? personEntities.first : null;
    final friendlyName = person?.friendlyName ?? 'Usuario';
    final stateStr = person?.state == 'home'
        ? 'En Casa'
        : (person?.state == 'not_home' ? 'Fuera' : (person?.state ?? ''));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Greeting & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${greetingForNow()}, $friendlyName',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.tendaWhite,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: stateStr == 'En Casa'
                          ? AppColors.tendaGold
                          : AppColors.tendaGrayMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    stateStr.isNotEmpty ? stateStr : 'Desconectado',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.tendaGrayMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Clock
          StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 30)),
            builder: (_, snapshot) {
              final now = DateTime.now();
              final time =
                  '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
              return Text(
                time,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.tendaGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              );
            },
          ),

          const Spacer(),

          // Settings icon
          InkWell(
            onTap: () => context.push('/login'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.tendaGold.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.settings_outlined,
                size: 18,
                color: AppColors.tendaWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom dock
// ═══════════════════════════════════════════════════════════════════════════

class _BottomDock extends ConsumerWidget {
  const _BottomDock({required this.haData});

  final HaStatesData haData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _DockItem(
            icon: Icons.lightbulb_outline,
            label: 'LUCES',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LightsScreen()),
            ),
          ),
          _DockItem(
            icon: Icons.thermostat_outlined,
            label: 'CLIMA',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeatherScreen()),
            ),
          ),
          _DockItem(
            icon: Icons.shield_outlined,
            label: 'SEGURIDAD',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecurityScreen()),
            ),
          ),
          _DockItem(
            icon: Icons.power_settings_new,
            label: 'APAGAR TODO',
            onTap: () {
              ref.read(devicesProvider.notifier).turnOffAll();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Apagando todos los dispositivos…'),
                  backgroundColor: AppColors.surface,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Dock item widget
// ═══════════════════════════════════════════════════════════════════════════

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.tendaGold.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(icon, color: AppColors.tendaGold, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.tendaGrayMuted,
                fontSize: 9,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
