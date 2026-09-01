import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../home_assistant/domain/ha_entity.dart';
import '../../home_assistant/state/ha_states_controller.dart';
import '../domain/room.dart';

/// The "Iluminación" screen — uses tabs to switch between individual devices
/// and scenes (Ambientes).
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(haStatesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<HaStatesData>>(haStatesProvider, (previous, next) {
      final prevData = previous?.valueOrNull;
      final nextData = next.valueOrNull;
      if (nextData != null &&
          nextData.connectionError != null &&
          nextData.connectionError != prevData?.connectionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(nextData.connectionError!)),
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

    final stateAsync = ref.watch(haStatesProvider);

    return stateAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.tendaGold),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(error.toString(), style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      data: (state) {
        final totalActive = state.totalActiveLights;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Iluminación',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                  ),
                  Text(
                    '$totalActive ${totalActive == 1 ? 'luz activa' : 'luces activas'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _ActionChip(
                      label: 'APAGAR TODO',
                      onTap: () =>
                          ref.read(haStatesProvider.notifier).turnOffAll(),
                    ),
                  ),
                ),
              ],
              bottom: const TabBar(
                indicatorColor: AppColors.tendaGold,
                labelColor: AppColors.tendaGold,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Dispositivos'),
                  Tab(text: 'Ambientes'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildDevicesTab(state),
                _buildScenesTab(state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevicesTab(HaStatesData state) {
    if (state.rooms.isEmpty || state.rooms.every((r) => r.devices.isEmpty)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: AppColors.tendaGold.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron luces',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.tendaGold.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        for (final room in state.rooms) ...[
          SliverToBoxAdapter(child: _RoomHeader(room: room)),
          if (state.expandedRoomIds.contains(room.id))
            SliverReorderableList(
              itemCount: room.devices.length,
              proxyDecorator: _proxyDecorator,
              itemBuilder: (context, index) {
                final device = room.devices[index];
                return _DeviceRow(
                  key: ValueKey(device.entityId),
                  device: device,
                  index: index,
                );
              },
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                ref
                    .read(haStatesProvider.notifier)
                    .reorderDevice(room.id, oldIndex, newIndex);
              },
            ),
          SliverToBoxAdapter(
            child: Divider(
              color: AppColors.tendaGold.withValues(alpha: 0.2),
              height: 1,
              indent: 16,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildScenesTab(HaStatesData state) {
    if (state.sceneEntities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: AppColors.tendaGold.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ambientes configurados',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.tendaGold.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: state.sceneEntities.length,
      itemBuilder: (context, index) {
        final scene = state.sceneEntities[index];
        final name = scene.attributes['friendly_name'] ?? scene.entityId;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.tendaGold.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              try {
                await ref.read(haStatesProvider.notifier).turnOnScene(scene.entityId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ambiente "$name" activado'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                // El error ya lo maneja el listener global arriba
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 32,
                    color: AppColors.tendaGold,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          elevation: 8 * animation.value,
          shadowColor: AppColors.tendaGold.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          child: child,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Room header
// ═══════════════════════════════════════════════════════════════════════════

class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(
      haStatesProvider.select((s) => s.valueOrNull?.expandedRoomIds.contains(room.id) ?? false),
    );

    return InkWell(
      onTap: () => ref.read(haStatesProvider.notifier).toggleRoom(room.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              room.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              '${room.activeCount}/${room.devices.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (isExpanded && room.activeCount > 0) ...[
              const SizedBox(width: 12),
              _ActionChip(
                label: 'APAGAR',
                onTap: () =>
                    ref.read(haStatesProvider.notifier).turnOffRoom(room.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Device row
// ═══════════════════════════════════════════════════════════════════════════

class _DeviceRow extends ConsumerWidget {
  const _DeviceRow({super.key, required this.device, required this.index});

  final HaEntity device;
  final int index;

  IconData _iconFor(HaEntity entity) {
    if (entity.domain == 'light') {
      return Icons.lightbulb_outline;
    } else {
      return Icons.wb_twilight_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      haStatesProvider.select((s) => s.valueOrNull?.loadingEntityIds.contains(device.entityId) ?? false),
    );

    final isOn = device.state == 'on';
    final name = device.attributes['friendly_name'] ?? device.entityId;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                  child: Icon(
                    Icons.drag_handle,
                    color: AppColors.tendaGold.withValues(alpha: 0.45),
                    size: 22,
                  ),
                ),
              ),
            ),
            Icon(
              _iconFor(device),
              color: isOn
                  ? AppColors.tendaGold
                  : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
                  color: isOn ? null : Colors.grey,
                ),
              ),
            ),
            Switch(
              value: isOn,
              onChanged: isLoading
                  ? null
                  : (_) => ref
                        .read(haStatesProvider.notifier)
                        .toggleLight(device.entityId, !isOn),
              activeThumbColor: AppColors.tendaGold,
              activeTrackColor: AppColors.tendaGold.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Action chip (reusable)
// ═══════════════════════════════════════════════════════════════════════════

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.tendaGold.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.tendaGold,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
