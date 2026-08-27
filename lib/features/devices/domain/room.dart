import 'device.dart';

/// A room (or zone) containing one or more [Device]s.
class Room {
  const Room({required this.id, required this.name, required this.devices});

  final String id;
  final String name;
  final List<Device> devices;

  /// Number of devices currently turned on.
  int get activeCount => devices.where((d) => d.isOn).length;

  Room copyWith({List<Device>? devices}) {
    return Room(id: id, name: name, devices: devices ?? this.devices);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          _listEquals(devices, other.devices);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(devices));

  static bool _listEquals(List<Device> a, List<Device> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
