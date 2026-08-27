import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../home_assistant/domain/ha_entity.dart';
import '../../home_assistant/state/ha_states_controller.dart';

/// Full-screen view for Home Assistant lights with categorized tabs.
class LightsScreen extends ConsumerStatefulWidget {
  const LightsScreen({super.key});

  @override
  ConsumerState<LightsScreen> createState() => _LightsScreenState();
}

class _LightsScreenState extends ConsumerState<LightsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh states on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(haStatesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for connection errors
    ref.listen<AsyncValue<HaStatesData>>(haStatesProvider, (previous, next) {
      if (next.valueOrNull?.connectionError != null &&
          next.valueOrNull?.connectionError !=
              previous?.valueOrNull?.connectionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(next.valueOrNull!.connectionError!)),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(haStatesProvider.notifier).clearError();
      }
    });

    final haStatesAsync = ref.watch(haStatesProvider);

    return haStatesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.tendaGold),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
      data: (haData) {
        final lights = haData.lightEntities;

        final giovanniLights = lights
            .where((l) => l.area == 'CASA GIOVANNI')
            .toList();
        final tendaLights = lights
            .where((l) => l.area == 'TENDA OFICINA')
            .toList();

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppColors.textPrimary),
              title: Text(
                'LUCES',
                style: GoogleFonts.rajdhani(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 4,
                ),
              ),
              bottom: TabBar(
                indicatorColor: AppColors.tendaGold,
                labelColor: AppColors.tendaGold,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
                unselectedLabelStyle: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
                tabs: const [
                  Tab(text: 'TODAS'),
                  Tab(text: 'CASA GIOVANNI'),
                  Tab(text: 'TENDA OFICINA'),
                ],
              ),
            ),
            body: TabBarView(
              // Desactivamos el deslizamiento horizontal para evitar conflictos
              // con el gesto de reordenamiento de las tarjetas.
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _LightList(lights: lights),
                _LightList(lights: giovanniLights),
                _LightList(lights: tendaLights),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LightList extends ConsumerWidget {
  const _LightList({required this.lights});

  final List<HaEntity> lights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lights.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron luces en esta área.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: lights.length,
      // 1. Desactivar el agarre automático para evitar que toda la tarjeta inicie el drag
      buildDefaultDragHandles: false,
      onReorderItem: (oldIndex, newIndex) {
        ref
            .read(haStatesProvider.notifier)
            .updateLightsOrder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final light = lights[index];
        final isOn = light.state == 'on';

        final isLoading = ref.watch(
          haStatesProvider.select(
            (s) =>
                s.valueOrNull?.loadingEntityIds.contains(light.entityId) ??
                false,
          ),
        );

        return Padding(
          key: ValueKey(light.entityId), // Obligatorio para ReorderableListView
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      value: isOn,
                      onChanged: isLoading
                          ? null
                          : (value) {
                              ref
                                  .read(haStatesProvider.notifier)
                                  .toggleLight(light.entityId, value);
                            },
                      title: Text(
                        light.friendlyName,
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isOn
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      secondary: Icon(
                        Icons.lightbulb,
                        color: isOn ? AppColors.tendaGold : AppColors.textMuted,
                      ),
                      activeThumbColor: AppColors.tendaGold,
                      activeTrackColor: AppColors.tendaGold.withValues(
                        alpha: 0.4,
                      ),
                      inactiveTrackColor: AppColors.tendaInputBackground,
                      inactiveThumbColor: AppColors.tendaGrayMuted,
                      // Removemos el tileColor y shape de aquí para controlarlo en el Container padre
                      // y que el icono de drag tenga el mismo fondo
                      contentPadding: const EdgeInsets.only(left: 16, right: 8),
                    ),
                  ),
                  // 2 y 3. Implementar controlador visual explícito envuelto en ReorderableDragStartListener
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.textMuted,
                        ),
                        color: AppColors.surface,
                        onSelected: (newArea) {
                          ref
                              .read(haStatesProvider.notifier)
                              .updateLightArea(light.entityId, newArea);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'TODAS',
                            child: Text(
                              'Mover a: TODAS',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'CASA GIOVANNI',
                            child: Text(
                              'Mover a: CASA GIOVANNI',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'TENDA OFICINA',
                            child: Text(
                              'Mover a: TENDA OFICINA',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(8, 16, 16, 16),
                          child: Icon(Icons.drag_handle, color: Colors.white54),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
