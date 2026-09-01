import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/domain/room.dart';
import '../../../services/device_order/device_order_service.dart';
import '../domain/ha_entity.dart';
import '../services/ha_api_service.dart';

/// Grouped entity lists parsed from the raw state stream, along with rooms and UI state.
class HaStatesData {
  const HaStatesData({
    required this.personEntities,
    required this.lightEntities, // Kept for reference, though grouped in rooms
    required this.sceneEntities,
    required this.sensorEntities,
    required this.weatherEntities,
    required this.securityEntities,
    this.rooms = const [],
    this.expandedRoomIds = const {},
    this.loadingEntityIds = const {},
    this.connectionError,
  });

  final List<HaEntity> personEntities;
  final List<HaEntity> lightEntities;
  final List<HaEntity> sceneEntities;
  final List<HaEntity> sensorEntities;
  final List<HaEntity> weatherEntities;
  final List<HaEntity> securityEntities;
  
  final List<Room> rooms;
  final Set<String> expandedRoomIds;
  final Set<String> loadingEntityIds;
  final String? connectionError;

  /// Total active lights across all rooms.
  int get totalActiveLights => rooms.fold<int>(0, (sum, r) => sum + r.activeCount);

  HaStatesData copyWith({
    List<HaEntity>? personEntities,
    List<HaEntity>? lightEntities,
    List<HaEntity>? sceneEntities,
    List<HaEntity>? sensorEntities,
    List<HaEntity>? weatherEntities,
    List<HaEntity>? securityEntities,
    List<Room>? rooms,
    Set<String>? expandedRoomIds,
    Set<String>? loadingEntityIds,
    String? connectionError,
    bool clearError = false,
  }) {
    return HaStatesData(
      personEntities: personEntities ?? this.personEntities,
      lightEntities: lightEntities ?? this.lightEntities,
      sceneEntities: sceneEntities ?? this.sceneEntities,
      sensorEntities: sensorEntities ?? this.sensorEntities,
      weatherEntities: weatherEntities ?? this.weatherEntities,
      securityEntities: securityEntities ?? this.securityEntities,
      rooms: rooms ?? this.rooms,
      expandedRoomIds: expandedRoomIds ?? this.expandedRoomIds,
      loadingEntityIds: loadingEntityIds ?? this.loadingEntityIds,
      connectionError: clearError
          ? null
          : (connectionError ?? this.connectionError),
    );
  }
}

final haStatesProvider =
    AsyncNotifierProvider<HaStatesController, HaStatesData>(
      HaStatesController.new,
    );

/// Controller to fetch, parse and hold the Home Assistant entities, 
/// as well as manage the UI state for DevicesScreen (rooms, expansion, ordering).
class HaStatesController extends AsyncNotifier<HaStatesData> {
  @override
  FutureOr<HaStatesData> build() async {
    return _fetchStates();
  }

  Future<HaStatesData> _fetchStates() async {
    final apiService = ref.read(haApiServiceProvider);
    
    // Check connection first
    try {
      await apiService.ping();
    } catch (e) {
      // If we fail here, we return an empty state with an error
      return const HaStatesData(
        personEntities: [],
        lightEntities: [],
        sceneEntities: [],
        sensorEntities: [],
        weatherEntities: [],
        securityEntities: [],
        rooms: [],
        connectionError: 'Sin conexión con Home Assistant. Verifica tu red o URL.',
      );
    }

    // Fetch states and areas in parallel
    final results = await Future.wait([
      apiService.getStates(),
      apiService.getEntityAreas(),
    ]);

    final entities = results[0] as List<HaEntity>;
    final areaMap = results[1] as Map<String, String>;
    final orderMap = await ref.read(deviceOrderServiceProvider).getOrder();

    final persons = <HaEntity>[];
    final lightsAndSwitches = <HaEntity>[];
    final scenes = <HaEntity>[];
    final sensors = <HaEntity>[];
    final weather = <HaEntity>[];
    final security = <HaEntity>[];

    for (var e in entities) {
      // Inject area from the Jinja template mapping
      if (areaMap.containsKey(e.entityId)) {
        e = e.copyWith(area: areaMap[e.entityId]!);
      }

      switch (e.domain) {
        case 'person':
          persons.add(e);
          break;
        case 'light':
        case 'switch': // Include switches in the lights group
          lightsAndSwitches.add(e);
          break;
        case 'scene':
          scenes.add(e);
          break;
        case 'weather':
          weather.add(e);
          break;
        case 'camera':
        case 'alarm_control_panel':
          security.add(e);
          break;
        case 'sensor':
          if (e.attributes['device_class'] == 'temperature' ||
              e.attributes['device_class'] == 'humidity') {
            weather.add(e);
          } else {
            sensors.add(e);
          }
          break;
        case 'binary_sensor':
          if (e.attributes['device_class'] == 'door' ||
              e.attributes['device_class'] == 'window' ||
              e.attributes['device_class'] == 'motion') {
            security.add(e);
          } else {
            sensors.add(e);
          }
          break;
      }
    }

    // Group lights/switches into Rooms (Areas)
    final Map<String, List<HaEntity>> groupedByArea = {};
    for (final device in lightsAndSwitches) {
      final areaName = device.area;
      groupedByArea.putIfAbsent(areaName, () => []).add(device);
    }

    var rooms = groupedByArea.entries.map((entry) {
      final areaName = entry.key;
      var devices = entry.value;

      // Sort by orderMap
      devices.sort((a, b) {
        final ia = orderMap[a.entityId] ?? double.maxFinite.toInt();
        final ib = orderMap[b.entityId] ?? double.maxFinite.toInt();
        return ia.compareTo(ib);
      });

      // Assign sequential sortIndex based on final order
      devices = devices.asMap().entries.map((e) {
        // We reuse the 'order' field in HaEntity or just know they are sorted.
        // Actually, we need to pass sortIndex to the UI? Reorderable list just uses index.
        return e.value;
      }).toList();

      return Room(id: areaName, name: areaName, devices: devices);
    }).toList();

    // Sort rooms alphabetically
    rooms.sort((a, b) => a.name.compareTo(b.name));

    // Expand rooms that have active devices by default
    final expanded = rooms
        .where((r) => r.activeCount > 0)
        .map((r) => r.id)
        .toSet();

    return HaStatesData(
      personEntities: persons,
      lightEntities: lightsAndSwitches,
      sceneEntities: scenes,
      sensorEntities: sensors,
      weatherEntities: weather,
      securityEntities: security,
      rooms: rooms,
      expandedRoomIds: expanded,
      loadingEntityIds: const {},
      connectionError: null,
    );
  }

  /// Explicitly refresh the states (e.g. pull-to-refresh or polling).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchStates());
  }

  // ── Reorder ────────────────────────────────────────────────────────

  /// Reorder devices within [roomId] (area) using ReorderableListView indices.
  Future<void> reorderDevice(String roomId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final updatedRooms = currentData.rooms.map((room) {
      if (room.id != roomId) return room;
      final devices = [...room.devices];
      final item = devices.removeAt(oldIndex);
      devices.insert(newIndex, item);
      return room.copyWith(devices: devices);
    }).toList();

    // Optimistic update
    state = AsyncValue.data(currentData.copyWith(rooms: updatedRooms));

    // Merge and persist
    final fullMap = <String, int>{};
    for (final room in updatedRooms) {
      for (var i = 0; i < room.devices.length; i++) {
        fullMap[room.devices[i].entityId] = i;
      }
    }
    
    await ref.read(deviceOrderServiceProvider).saveOrder(fullMap);
  }

  // ── Room collapse ──────────────────────────────────────────────────

  void toggleRoom(String roomId) {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final updated = Set<String>.from(currentData.expandedRoomIds);
    if (updated.contains(roomId)) {
      updated.remove(roomId);
    } else {
      updated.add(roomId);
    }
    state = AsyncValue.data(currentData.copyWith(expandedRoomIds: updated));
  }

  // ── Toggle / Turn off ──────────────────────────────────────────────

  void clearError() {
    final currentData = state.valueOrNull;
    if (currentData == null) return;
    state = AsyncValue.data(currentData.copyWith(clearError: true));
  }

  Future<void> toggleLight(String entityId, bool turnOn) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;
    if (currentData.loadingEntityIds.contains(entityId)) return;

    // 1. Optimistic UI + mark as loading
    final originalRooms = currentData.rooms;
    final updatedRooms = originalRooms.map((room) {
      final devices = room.devices.map((d) {
        if (d.entityId == entityId) return d.copyWith(state: turnOn ? 'on' : 'off');
        return d;
      }).toList();
      return room.copyWith(devices: devices);
    }).toList();

    state = AsyncValue.data(
      currentData.copyWith(
        rooms: updatedRooms,
        loadingEntityIds: {...currentData.loadingEntityIds, entityId},
        clearError: true,
      ),
    );

    try {
      final domain = entityId.split('.').first;
      final service = turnOn ? 'turn_on' : 'turn_off';

      final changedStates = await ref.read(haApiServiceProvider).callService(
        domain,
        service,
        {'entity_id': entityId},
      );

      final latestData = state.valueOrNull;
      if (latestData == null) return;

      var finalRooms = latestData.rooms;

      // Parse changed_states to confirm real HA state
      if (changedStates.isNotEmpty) {
        for (final s in changedStates) {
          if (s is Map<String, dynamic> && s['entity_id'] == entityId) {
            final realState = s['state'] as String;
            finalRooms = finalRooms.map((room) {
              final devices = room.devices.map((d) {
                if (d.entityId == entityId) return d.copyWith(state: realState);
                return d;
              }).toList();
              return room.copyWith(devices: devices);
            }).toList();
            break;
          }
        }
      }

      final newLoading = Set<String>.from(latestData.loadingEntityIds)..remove(entityId);
      state = AsyncValue.data(
        latestData.copyWith(rooms: finalRooms, loadingEntityIds: newLoading),
      );
    } catch (e) {
      final latestData = state.valueOrNull;
      if (latestData == null) return;

      final newLoading = Set<String>.from(latestData.loadingEntityIds)..remove(entityId);
      state = AsyncValue.data(
        latestData.copyWith(
          rooms: originalRooms,
          loadingEntityIds: newLoading,
          connectionError: 'No se pudo conectar con Home Assistant. Verifica tu red.',
        ),
      );
    }
  }

  void turnOffAll() {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final originalRooms = currentData.rooms;
    final updatedRooms = originalRooms.map((room) {
      final updated = room.devices.map((d) => d.copyWith(state: 'off')).toList();
      return room.copyWith(devices: updated);
    }).toList();
    
    state = AsyncValue.data(currentData.copyWith(rooms: updatedRooms));

    final apiService = ref.read(haApiServiceProvider);
    
    Future.wait([
      apiService.callService('light', 'turn_off', {'entity_id': 'all'}),
      apiService.callService('switch', 'turn_off', {'entity_id': 'all'}),
    ]).catchError((_) {
      final latestData = state.valueOrNull;
      if (latestData != null) {
        state = AsyncValue.data(latestData.copyWith(rooms: originalRooms));
      }
      return <List<dynamic>>[];
    });
  }

  void turnOffRoom(String roomId) {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final originalRooms = currentData.rooms;
    final updatedRooms = originalRooms.map((room) {
      if (room.id != roomId) return room;
      final updated = room.devices.map((d) => d.copyWith(state: 'off')).toList();
      return room.copyWith(devices: updated);
    }).toList();
    
    state = AsyncValue.data(currentData.copyWith(rooms: updatedRooms));

    final devicesToTurnOff = originalRooms
        .firstWhere((r) => r.id == roomId)
        .devices
        .where((d) => d.state == 'on');
        
    final apiService = ref.read(haApiServiceProvider);

    Future.wait(
      devicesToTurnOff.map((d) {
        final domain = d.entityId.split('.').first;
        return apiService.callService(domain, 'turn_off', {'entity_id': d.entityId});
      }),
    ).catchError((_) {
      final latestData = state.valueOrNull;
      if (latestData != null) {
        state = AsyncValue.data(latestData.copyWith(rooms: originalRooms));
      }
      return <List<dynamic>>[];
    });
  }

  // ── Scenes ─────────────────────────────────────────────────────────

  Future<void> turnOnScene(String entityId) async {
    final apiService = ref.read(haApiServiceProvider);
    try {
      await apiService.callService('scene', 'turn_on', {'entity_id': entityId});
    } catch (e) {
      final latestData = state.valueOrNull;
      if (latestData != null) {
        state = AsyncValue.data(
          latestData.copyWith(
            connectionError: 'Error al activar escena: $e',
          ),
        );
      }
      rethrow;
    }
  }
}
