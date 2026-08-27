import 'dart:async';

import '../../features/devices/domain/room.dart';

/// The four possible states of the Jarvis core animation.
enum JarvisState { idle, listening, processing, responding }

/// Abstract interface for communication with a home-automation backend.
///
/// Today this is implemented by [MockHomeConnector].
/// When the real Home Assistant integration lands, a
/// `HomeAssistantConnector` will implement this same interface via
/// REST / WebSocket — without touching any UI or controller code.
abstract class HomeConnector {
  /// Fetch the full list of rooms and their devices.
  Future<List<Room>> getRooms();

  /// Toggle the on/off state of the device identified by [deviceId].
  Future<List<dynamic>> toggleDevice(String deviceId);

  /// Turn off every active device across all rooms.
  Future<void> turnOffAllDevices();

  /// Send a voice/text command to the backend agent.
  Future<void> sendVoiceCommand(String text);

  /// Stream of core-state changes pushed by the backend
  /// (e.g. the agent started listening, finished responding, etc.).
  Stream<JarvisState> get coreStateChanges;

  /// Clean up resources (stream controllers, sockets, etc.).
  void dispose();
}
