import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/device_order/device_order_service.dart';
import '../../../services/home_connector/home_connector.dart';
import '../../../services/home_connector/ha_home_connector.dart';
import '../../home_assistant/services/ha_api_service.dart';
import '../domain/room.dart';

/// The full state for the devices/illumination screen.
class DevicesState {
  const DevicesState({
    this.rooms = const [],
    this.expandedRoomIds = const {},
    this.isLoading = true,
    this.connectionError,
    this.loadingDeviceIds = const {},
  });

  final List<Room> rooms;
  final Set<String> expandedRoomIds;
  final bool isLoading;
  final Set<String> loadingDeviceIds;

  /// Set when a HA connection check or toggle fails.
  /// The widget should consume this once and clear it.
  final String? connectionError;

  /// Total active lights across all rooms.
  int get totalActive => rooms.fold<int>(0, (sum, r) => sum + r.activeCount);

  DevicesState copyWith({
    List<Room>? rooms,
    Set<String>? expandedRoomIds,
    bool? isLoading,
    String? connectionError,
    bool clearError = false,
    Set<String>? loadingDeviceIds,
  }) {
    return DevicesState(
      rooms: rooms ?? this.rooms,
      expandedRoomIds: expandedRoomIds ?? this.expandedRoomIds,
      isLoading: isLoading ?? this.isLoading,
      connectionError: clearError
          ? null
          : (connectionError ?? this.connectionError),
      loadingDeviceIds: loadingDeviceIds ?? this.loadingDeviceIds,
    );
  }
}

/// Riverpod provider for the devices screen state.
final devicesProvider = StateNotifierProvider<DevicesController, DevicesState>((
  ref,
) {
  final connector = ref.watch(homeConnectorProvider);
  final orderService = ref.watch(deviceOrderServiceProvider);
  final apiService = ref.watch(haApiServiceProvider);
  return DevicesController(connector, orderService, apiService);
});

/// Manages the list of rooms/devices and their expansion state.
///
/// Uses **optimistic updates**: toggles are reflected immediately in the UI,
/// and only reverted if the [HomeConnector] call fails.
///
/// Device order is persisted locally via [DeviceOrderService] (SharedPrefs).
/// On load, the saved sortIndex map is applied on top of what HA returns.
class DevicesController extends StateNotifier<DevicesState> {
  DevicesController(this._connector, this._orderService, this._apiService)
    : super(const DevicesState()) {
    _loadRooms();
  }

  final HomeConnector _connector;
  final DeviceOrderService _orderService;
  final HaApiService _apiService;

  Future<void> refresh() async => _loadRooms();

  Future<void> _loadRooms() async {
    // 3. Chequeo de conexión antes de listar dispositivos.
    // Si HA no responde, mostramos un error claro en vez de una lista vacía.
    try {
      await _apiService.ping();
    } catch (e) {
      if (!mounted) return;
      state = DevicesState(
        rooms: const [],
        expandedRoomIds: const {},
        isLoading: false,
        connectionError:
            'Sin conexión con Home Assistant. Verifica tu red o URL.',
      );
      return;
    }

    final rooms = await _connector.getRooms();
    // Apply persisted sort order on top of HA data.
    final orderMap = await _orderService.getOrder();
    final sortedRooms = _applyOrder(rooms, orderMap);
    if (!mounted) return;
    // Expand rooms that have active devices by default.
    final expanded = sortedRooms
        .where((r) => r.activeCount > 0)
        .map((r) => r.id)
        .toSet();
    state = state.copyWith(
      rooms: sortedRooms,
      expandedRoomIds: expanded,
      isLoading: false,
    );
  }

  /// Apply a persisted [orderMap] (entity_id → sortIndex) to [rooms].
  ///
  /// Devices with an entry are placed first by ascending sortIndex; devices
  /// without an entry retain their original relative HA order at the end.
  List<Room> _applyOrder(List<Room> rooms, Map<String, int> orderMap) {
    if (orderMap.isEmpty) return rooms;
    return rooms.map((room) {
      final sorted = [...room.devices]
        ..sort((a, b) {
          final ia = orderMap[a.id] ?? double.maxFinite.toInt();
          final ib = orderMap[b.id] ?? double.maxFinite.toInt();
          return ia.compareTo(ib);
        });
      final withIndex = sorted
          .asMap()
          .entries
          .map((e) => e.value.copyWith(sortIndex: orderMap[e.value.id]))
          .toList();
      return room.copyWith(devices: withIndex);
    }).toList();
  }

  // ── Reorder ────────────────────────────────────────────────────────

  /// Reorder devices within [roomId] using ReorderableListView indices.
  ///
  /// Updates sortIndex for ALL devices in the room, then persists
  /// the full merged map via [DeviceOrderService].
  Future<void> reorderDevice(String roomId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    // NOTE: callers are responsible for the standard ReorderableListView
    // newIndex adjustment (subtract 1 when moving down) before calling this
    // method. SliverReorderableList's onReorder provides the raw newIndex.

    final updatedRooms = state.rooms.map((room) {
      if (room.id != roomId) return room;
      final devices = [...room.devices];
      final item = devices.removeAt(oldIndex);
      devices.insert(newIndex, item);
      // Assign fresh consecutive sortIndex values (0, 1, 2…).
      final reindexed = devices
          .asMap()
          .entries
          .map((e) => e.value.copyWith(sortIndex: e.key))
          .toList();
      return room.copyWith(devices: reindexed);
    }).toList();

    // Optimistic update.
    state = state.copyWith(rooms: updatedRooms);

    // Merge and persist: build a map that includes all rooms, not just the
    // reordered one, so we don't wipe previously saved orderings.
    final fullMap = <String, int>{};
    for (final room in updatedRooms) {
      for (final device in room.devices) {
        if (device.sortIndex != null) {
          fullMap[device.id] = device.sortIndex!;
        }
      }
    }
    await _orderService.saveOrder(fullMap);
  }

  // ── Room collapse ──────────────────────────────────────────────────

  /// Expand or collapse a room section.
  void toggleRoom(String roomId) {
    final updated = Set<String>.from(state.expandedRoomIds);
    if (updated.contains(roomId)) {
      updated.remove(roomId);
    } else {
      updated.add(roomId);
    }
    state = state.copyWith(expandedRoomIds: updated);
  }

  // ── Toggle / Turn off ──────────────────────────────────────────────

  /// Toggle a single device — optimistic update.
  ///
  /// On success: the local state stays flipped (HA confirmed the change).
  /// On failure: reverts the optimistic flip and sets [connectionError] so
  /// the UI can display a visible error message (SnackBar, banner, etc.).
  void toggleDevice(String deviceId) {
    if (state.loadingDeviceIds.contains(deviceId)) return;

    // 1. Immediately flip the device in local state (optimistic update).
    // And mark as loading to prevent double taps.
    final previousRooms = state.rooms;
    final updatedRooms = _flipDevice(previousRooms, deviceId);

    state = state.copyWith(
      rooms: updatedRooms,
      clearError: true,
      loadingDeviceIds: {...state.loadingDeviceIds, deviceId},
    );

    // 2. Fire the real HA REST call — POST /api/services/light/toggle.
    _connector
        .toggleDevice(deviceId)
        .then((changedStates) {
          if (!mounted) return;

          var finalRooms = state.rooms;

          // Parse changed_states to see the real confirmed state from HA
          if (changedStates.isNotEmpty) {
            for (final s in changedStates) {
              if (s is Map<String, dynamic> && s['entity_id'] == deviceId) {
                final realState = s['state'] == 'on';
                finalRooms = finalRooms.map((room) {
                  final devices = room.devices.map((d) {
                    if (d.id == deviceId) return d.copyWith(isOn: realState);
                    return d;
                  }).toList();
                  return room.copyWith(devices: devices);
                }).toList();
                break;
              }
            }
          }

          final newLoading = Set<String>.from(state.loadingDeviceIds)
            ..remove(deviceId);
          state = state.copyWith(
            rooms: finalRooms,
            loadingDeviceIds: newLoading,
          );
        })
        .catchError((error) {
          if (!mounted) return;
          // Revert optimistic flip so the UI shows the real HA state.
          final newLoading = Set<String>.from(state.loadingDeviceIds)
            ..remove(deviceId);
          state = state.copyWith(
            rooms: previousRooms,
            loadingDeviceIds: newLoading,
            connectionError:
                'No se pudo conectar con Home Assistant. Verifica tu red.',
          );
        });
  }

  /// Limpia el error de conexión del estado (llamar después de mostrar el SnackBar).
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Turn off every active device — optimistic update.
  void turnOffAll() {
    final previousRooms = state.rooms;
    final updatedRooms = previousRooms.map((room) {
      final updated = room.devices.map((d) => d.copyWith(isOn: false)).toList();
      return room.copyWith(devices: updated);
    }).toList();
    state = state.copyWith(rooms: updatedRooms);

    _connector.turnOffAllDevices().catchError((_) {
      if (mounted) {
        state = state.copyWith(rooms: previousRooms);
      }
    });
  }

  /// Turn off all devices in a specific room.
  void turnOffRoom(String roomId) {
    final previousRooms = state.rooms;
    final updatedRooms = previousRooms.map((room) {
      if (room.id != roomId) return room;
      final updated = room.devices.map((d) => d.copyWith(isOn: false)).toList();
      return room.copyWith(devices: updated);
    }).toList();
    state = state.copyWith(rooms: updatedRooms);

    // Turn off each device individually via the connector.
    final devicesToTurnOff = previousRooms
        .firstWhere((r) => r.id == roomId)
        .devices
        .where((d) => d.isOn);
    Future.wait(
      devicesToTurnOff.map((d) => _connector.toggleDevice(d.id)),
    ).catchError((_) {
      if (mounted) {
        state = state.copyWith(rooms: previousRooms);
      }
      return <List<dynamic>>[];
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────

  List<Room> _flipDevice(List<Room> rooms, String deviceId) {
    return rooms.map((room) {
      final devices = room.devices.map((d) {
        if (d.id == deviceId) return d.copyWith(isOn: !d.isOn);
        return d;
      }).toList();
      return room.copyWith(devices: devices);
    }).toList();
  }
}
