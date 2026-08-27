/// Type of smart device (used for icon selection in the UI)
enum DeviceType { light, ambientLight, spotLight, underglow }

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.type,
    this.isOn = false,
    this.sortIndex, // null = no custom order yet, goes to the end
  });

  final String id;
  final String name;
  final DeviceType type;
  final bool isOn;

  /// Client-side sort position. Not persisted in Home Assistant.
  final int? sortIndex;

  Device copyWith({bool? isOn, int? sortIndex}) {
    return Device(
      id: id,
      name: name,
      type: type,
      isOn: isOn ?? this.isOn,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          isOn == other.isOn &&
          sortIndex == other.sortIndex;

  @override
  int get hashCode => Object.hash(id, name, type, isOn, sortIndex);
}
