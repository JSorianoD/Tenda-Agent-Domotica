import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/devices/domain/device.dart';
import '../../features/devices/domain/room.dart';
import '../../features/home_assistant/services/ha_api_service.dart';
import 'home_connector.dart';

/// Proveedor del conector real a Home Assistant.
final homeConnectorProvider = Provider<HomeConnector>((ref) {
  final apiService = ref.watch(haApiServiceProvider);
  final connector = HaHomeConnector(apiService);
  ref.onDispose(connector.dispose);
  return connector;
});

/// Conector real que utiliza HaApiService para interactuar con la instancia.
class HaHomeConnector implements HomeConnector {
  HaHomeConnector(this._apiService);

  final HaApiService _apiService;
  final _coreStateController = StreamController<JarvisState>.broadcast();

  @override
  Future<List<Room>> getRooms() async {
    final entities = await _apiService.getStates();

    // Extraer luces y switches (los switches muchas veces controlan luces)
    final lightEntities = entities.where((e) {
      return e.domain == 'light' || e.domain == 'switch';
    }).toList();

    if (lightEntities.isEmpty) {
      return [];
    }

    // Convertir las entidades de HA a nuestro modelo de dominio Device
    final devices = lightEntities.map((e) {
      return Device(
        id: e.entityId,
        name: e.attributes['friendly_name'] ?? e.entityId,
        type: e.domain == 'light' ? DeviceType.light : DeviceType.ambientLight,
        isOn: e.state == 'on',
      );
    }).toList();

    // Como /api/states no expone información de "Área" (Room) directamente
    // en HA sin hacer consultas más complejas al registro de dispositivos,
    // agrupamos todo en una habitación genérica.
    return [Room(id: 'all_lights', name: 'TODAS LAS LUCES', devices: devices)];
  }

  @override
  Future<List<dynamic>> toggleDevice(String deviceId) async {
    final domain = deviceId.split('.').first; // 'light' o 'switch'
    return await _apiService.callService(domain, 'toggle', {
      'entity_id': deviceId,
    });
  }

  @override
  Future<void> turnOffAllDevices() async {
    // Apagamos todas las luces y switches
    await _apiService.callService('light', 'turn_off', {'entity_id': 'all'});
    await _apiService.callService('switch', 'turn_off', {'entity_id': 'all'});
  }

  @override
  Future<void> sendVoiceCommand(String text) async {
    // La interacción de voz va por N8N, aquí podríamos simular los estados del orbe si hiciera falta.
  }

  @override
  Stream<JarvisState> get coreStateChanges => _coreStateController.stream;

  @override
  void dispose() {
    _coreStateController.close();
  }
}
