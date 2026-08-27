import 'dart:async';

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ha_entity.dart';
import '../services/ha_api_service.dart';

/// Grouped entity lists parsed from the raw state stream.
class HaStatesData {
  const HaStatesData({
    required this.personEntities,
    required this.lightEntities,
    required this.sceneEntities,
    required this.sensorEntities,
    required this.weatherEntities,
    required this.securityEntities,
    this.loadingEntityIds = const {},
    this.connectionError,
  });

  final List<HaEntity> personEntities;
  final List<HaEntity> lightEntities;
  final List<HaEntity> sceneEntities;
  final List<HaEntity> sensorEntities;
  final List<HaEntity> weatherEntities;
  final List<HaEntity> securityEntities;
  final Set<String> loadingEntityIds;
  final String? connectionError;

  HaStatesData copyWith({
    List<HaEntity>? personEntities,
    List<HaEntity>? lightEntities,
    List<HaEntity>? sceneEntities,
    List<HaEntity>? sensorEntities,
    List<HaEntity>? weatherEntities,
    List<HaEntity>? securityEntities,
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

/// Controller to fetch, parse and hold the Home Assistant entities.
class HaStatesController extends AsyncNotifier<HaStatesData> {
  @override
  FutureOr<HaStatesData> build() async {
    return _fetchStates();
  }

  Future<HaStatesData> _fetchStates() async {
    final apiService = ref.read(haApiServiceProvider);
    final entities = await apiService.getStates();

    final persons = <HaEntity>[];
    var lights = <HaEntity>[];
    final scenes = <HaEntity>[];
    final sensors = <HaEntity>[];
    final weather = <HaEntity>[];
    final security = <HaEntity>[];

    for (final e in entities) {
      switch (e.domain) {
        case 'person':
          persons.add(e);
          break;
        case 'light':
          lights.add(e);
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

    // --- Persistencia: Cargar mapeo de áreas y orden ---
    final prefs = await SharedPreferences.getInstance();

    // 1. Cargar áreas asignadas
    final areaMapStr = prefs.getString('lights_area');
    final Map<String, String> areaMap = areaMapStr != null
        ? Map<String, String>.from(jsonDecode(areaMapStr))
        : {};

    // Asignar área a cada luz
    lights = lights
        .map((l) => l.copyWith(area: areaMap[l.entityId] ?? 'TODAS'))
        .toList();

    // 2. Cargar orden personalizado
    final orderList = prefs.getStringList('lights_order') ?? [];

    if (orderList.isNotEmpty) {
      lights.sort((a, b) {
        var indexA = orderList.indexOf(a.entityId);
        var indexB = orderList.indexOf(b.entityId);
        // Si no están en la lista guardada, los mandamos al final
        if (indexA == -1) indexA = 999999;
        if (indexB == -1) indexB = 999999;
        return indexA.compareTo(indexB);
      });
    }

    return HaStatesData(
      personEntities: persons,
      lightEntities: lights,
      sceneEntities: scenes,
      sensorEntities: sensors,
      weatherEntities: weather,
      securityEntities: security,
      loadingEntityIds: const {},
      connectionError: null,
    );
  }

  /// Explicitly refresh the states (e.g. pull-to-refresh or polling).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchStates());
  }

  /// Actualiza el orden de las luces (Drag & Drop) y lo guarda en SharedPreferences.
  Future<void> updateLightsOrder(int oldIndex, int newIndex) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final lights = List<HaEntity>.from(currentData.lightEntities);
    final item = lights.removeAt(oldIndex);
    lights.insert(newIndex, item);

    // Actualizamos el estado optimísticamente
    state = AsyncValue.data(currentData.copyWith(lightEntities: lights));

    // Persistimos en SharedPreferences
    final orderList = lights.map((l) => l.entityId).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('lights_order', orderList);
  }

  /// Asigna una luz a una pestaña/área específica y guarda en SharedPreferences.
  Future<void> updateLightArea(String entityId, String newArea) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final lights = currentData.lightEntities.map((l) {
      if (l.entityId == entityId) {
        return l.copyWith(area: newArea);
      }
      return l;
    }).toList();

    // Actualizamos el estado
    state = AsyncValue.data(currentData.copyWith(lightEntities: lights));

    // Leemos, actualizamos y persistimos el mapa de áreas
    final prefs = await SharedPreferences.getInstance();
    final areaMapStr = prefs.getString('lights_area');
    final areaMap = areaMapStr != null
        ? Map<String, String>.from(jsonDecode(areaMapStr))
        : <String, String>{};
    areaMap[entityId] = newArea;
    await prefs.setString('lights_area', jsonEncode(areaMap));
  }

  void clearError() {
    final currentData = state.valueOrNull;
    if (currentData == null) return;
    state = AsyncValue.data(currentData.copyWith(clearError: true));
  }

  /// Toggle light with optimistic UI and HA real state validation.
  Future<void> toggleLight(String entityId, bool turnOn) async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;
    if (currentData.loadingEntityIds.contains(entityId)) return;

    // 1. Optimistic UI + mark as loading
    final originalLights = List<HaEntity>.from(currentData.lightEntities);
    final updatedLights = originalLights.map((l) {
      if (l.entityId == entityId) {
        return l.copyWith(state: turnOn ? 'on' : 'off');
      }
      return l;
    }).toList();

    state = AsyncValue.data(
      currentData.copyWith(
        lightEntities: updatedLights,
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

      var finalLights = latestData.lightEntities;

      // Parse changed_states to confirm real HA state
      if (changedStates.isNotEmpty) {
        for (final s in changedStates) {
          if (s is Map<String, dynamic> && s['entity_id'] == entityId) {
            final realState = s['state'] as String;
            finalLights = finalLights.map((l) {
              if (l.entityId == entityId) return l.copyWith(state: realState);
              return l;
            }).toList();
            break;
          }
        }
      }

      final newLoading = Set<String>.from(latestData.loadingEntityIds)
        ..remove(entityId);
      state = AsyncValue.data(
        latestData.copyWith(
          lightEntities: finalLights,
          loadingEntityIds: newLoading,
        ),
      );
    } catch (e) {
      final latestData = state.valueOrNull;
      if (latestData == null) return;

      // Rollback
      final newLoading = Set<String>.from(latestData.loadingEntityIds)
        ..remove(entityId);
      state = AsyncValue.data(
        latestData.copyWith(
          lightEntities: originalLights, // Revert to original
          loadingEntityIds: newLoading,
          connectionError:
              'No se pudo conectar con Home Assistant. Verifica tu red.',
        ),
      );
    }
  }
}
