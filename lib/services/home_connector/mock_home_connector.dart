import 'dart:async';
import 'dart:math';

import '../../features/devices/domain/device.dart';
import '../../features/devices/domain/room.dart';
import 'home_connector.dart';

/// Mock implementation of [HomeConnector] backed by in-memory data.
///
/// Every mutation simulates network latency with a short random delay
/// (200-400 ms) so the UI already handles the "in-transition" UX that
/// will happen with real Home Assistant latency.
class MockHomeConnector implements HomeConnector {
  MockHomeConnector() : _rooms = _buildInitialRooms();

  List<Room> _rooms;
  final _rng = Random(42);

  final _coreStateController = StreamController<JarvisState>.broadcast();

  // ── HomeConnector API ──────────────────────────────────────────────

  @override
  Future<List<Room>> getRooms() async {
    // Simulate initial fetch latency.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return List.unmodifiable(_rooms);
  }

  @override
  Future<List<dynamic>> toggleDevice(String deviceId) async {
    await _simulateDelay();
    _rooms = _rooms.map((room) {
      final updated = room.devices.map((d) {
        if (d.id == deviceId) return d.copyWith(isOn: !d.isOn);
        return d;
      }).toList();
      return room.copyWith(devices: updated);
    }).toList();
    return [];
  }

  @override
  Future<void> turnOffAllDevices() async {
    await _simulateDelay();
    _rooms = _rooms.map((room) {
      final updated = room.devices.map((d) => d.copyWith(isOn: false)).toList();
      return room.copyWith(devices: updated);
    }).toList();
  }

  @override
  Future<void> sendVoiceCommand(String text) async {
    // No-op in mock — will be wired to the real agent later.
    await _simulateDelay();
  }

  @override
  Stream<JarvisState> get coreStateChanges => _coreStateController.stream;

  @override
  void dispose() {
    _coreStateController.close();
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Future<void> _simulateDelay() =>
      Future<void>.delayed(Duration(milliseconds: 200 + _rng.nextInt(200)));

  /// The mock fixture data — matches the reference screenshots exactly.
  static List<Room> _buildInitialRooms() {
    return [
      Room(
        id: 'sala',
        name: 'SALA',
        devices: [
          const Device(
            id: 'sala_principal',
            name: 'Lámpara Principal',
            type: DeviceType.light,
            isOn: true,
          ),
          const Device(
            id: 'sala_ambiental',
            name: 'Luz Ambiental',
            type: DeviceType.ambientLight,
          ),
          const Device(
            id: 'sala_spot',
            name: 'Spot Lectura',
            type: DeviceType.spotLight,
            isOn: true,
          ),
        ],
      ),
      Room(
        id: 'cocina',
        name: 'COCINA',
        devices: [
          const Device(
            id: 'cocina_principal',
            name: 'Luz Principal',
            type: DeviceType.light,
            isOn: true,
          ),
          const Device(
            id: 'cocina_gabinetes',
            name: 'Bajo Gabinetes',
            type: DeviceType.underglow,
            isOn: true,
          ),
        ],
      ),
      Room(
        id: 'dormitorio',
        name: 'DORMITORIO',
        devices: [
          const Device(
            id: 'dorm_principal',
            name: 'Lámpara Principal',
            type: DeviceType.light,
          ),
          const Device(
            id: 'dorm_velador',
            name: 'Velador',
            type: DeviceType.ambientLight,
          ),
        ],
      ),
      Room(
        id: 'exterior',
        name: 'EXTERIOR',
        devices: [
          const Device(
            id: 'ext_porche',
            name: 'Porche',
            type: DeviceType.light,
            isOn: true,
          ),
          const Device(
            id: 'ext_jardin',
            name: 'Jardín',
            type: DeviceType.spotLight,
            isOn: true,
          ),
        ],
      ),
    ];
  }
}
