import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/device.dart';
import '../domain/room.dart';
import '../state/devices_controller.dart';

/// The "Iluminación" screen — lists all rooms with collapsible device sections
/// and per-room drag-and-drop reordering.
///
/// Architecture note: the entire screen is a single [CustomScrollView] with
/// [SliverReorderableList]s instead of a [ListView] + nested
/// [ReorderableListView]. This prevents the gesture conflict where the outer
/// scroll steals the vertical drag before the inner list can detect it.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    // Force refresh the connection check and states when the screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(devicesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escucha errores de toggle/conexión y muestra un SnackBar al usuario.
    // Esto cubre: timeout, 401, host inalcanzable, etc.
    ref.listen<DevicesState>(devicesProvider, (previous, next) {
      if (next.connectionError != null &&
          next.connectionError != previous?.connectionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(next.connectionError!)),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        // Limpiar el error del estado para no re-mostrarlo.
        ref.read(devicesProvider.notifier).clearError();
      }
    });

    final state = ref.watch(devicesProvider);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.tendaGold),
        ),
      );
    }

    final totalActive = state.totalActive;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.tendaWhite,
                          ),
                          onPressed: () => context.go('/'),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Iluminación',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: AppColors.tendaWhite,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$totalActive '
                                '${totalActive == 1 ? 'luz activa' : 'luces activas'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.tendaGrayMuted),
                              ),
                            ],
                          ),
                        ),
                        _ActionChip(
                          label: 'APAGAR TODO',
                          onTap: () =>
                              ref.read(devicesProvider.notifier).turnOffAll(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    color: AppColors.tendaGold.withValues(alpha: 0.3),
                    height: 1,
                  ),
                ],
              ),
            ),

            // ── Empty State ─────────────────────────────────────────
            if (state.rooms.isEmpty ||
                state.rooms.every((r) => r.devices.isEmpty))
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.tendaGold.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // Si hay error de conexión, lo mostramos en lugar del mensaje genérico.
                      if (state.connectionError != null)
                        Text(
                          state.connectionError!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.red.shade300),
                        )
                      else
                        Text(
                          'Asegúrate de que la instancia de HA\ntenga luces o interruptores configurados.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.tendaGrayMuted),
                        ),
                    ],
                  ),
                ),
              ),

            // ── Rooms — each room gets its own SliverReorderableList ─
            for (final room in state.rooms) ...[
              // Room header sliver
              SliverToBoxAdapter(child: _RoomHeader(room: room)),

              // Device list sliver — only rendered when room is expanded
              if (state.expandedRoomIds.contains(room.id))
                SliverReorderableList(
                  itemCount: room.devices.length,
                  proxyDecorator: _proxyDecorator,
                  itemBuilder: (context, index) {
                    final device = room.devices[index];
                    return ReorderableDragStartListener(
                      key: ValueKey(device.id),
                      index: index,
                      child: _DeviceRow(device: device),
                    );
                  },
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    // SliverReorderableList still uses the old API; the
                    // standard adjustment (subtract 1 when moving down) is
                    // needed here because onReorderItem is only on
                    // ReorderableListView, not SliverReorderableList.
                    if (newIndex > oldIndex) newIndex -= 1;
                    ref
                        .read(devicesProvider.notifier)
                        .reorderDevice(room.id, oldIndex, newIndex);
                  },
                ),

              // Divider after each section
              SliverToBoxAdapter(
                child: Divider(
                  color: AppColors.tendaGold.withValues(alpha: 0.2),
                  height: 1,
                  indent: 16,
                ),
              ),
            ],

            // Bottom padding sliver
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  /// Lifted-item decorator while dragging — adds gold shadow.
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Material(
          color: AppColors.tendaDeepBlack,
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
      devicesProvider.select((s) => s.expandedRoomIds.contains(room.id)),
    );

    return InkWell(
      onTap: () => ref.read(devicesProvider.notifier).toggleRoom(room.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              color: AppColors.tendaGrayMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              room.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.tendaWhite,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              '${room.activeCount}/${room.devices.length}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.tendaGrayMuted),
            ),
            if (isExpanded && room.activeCount > 0) ...[
              const SizedBox(width: 12),
              _ActionChip(
                label: 'APAGAR',
                onTap: () =>
                    ref.read(devicesProvider.notifier).turnOffRoom(room.id),
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
  const _DeviceRow({required this.device});

  final Device device;

  IconData _iconFor(DeviceType type) {
    return switch (type) {
      DeviceType.light => Icons.lightbulb_outline,
      DeviceType.ambientLight => Icons.wb_twilight_outlined,
      DeviceType.spotLight => Icons.highlight_outlined,
      DeviceType.underglow => Icons.wb_twilight_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      devicesProvider.select((s) => s.loadingDeviceIds.contains(device.id)),
    );

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            // Drag handle — entire row wrapped in ReorderableDragStartListener
            // above, so this icon is purely visual.
            MouseRegion(
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
            Icon(
              _iconFor(device.type),
              color: device.isOn
                  ? AppColors.tendaGold
                  : AppColors.tendaGrayMuted,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                device.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: device.isOn
                      ? AppColors.tendaWhite
                      : AppColors.tendaGrayMuted,
                ),
              ),
            ),
            Switch(
              value: device.isOn,
              onChanged: isLoading
                  ? null
                  : (_) => ref
                        .read(devicesProvider.notifier)
                        .toggleDevice(device.id),
              activeThumbColor: AppColors.tendaGold,
              activeTrackColor: AppColors.tendaGold.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.tendaGrayMuted,
              inactiveTrackColor: AppColors.tendaDeepBlack,
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
