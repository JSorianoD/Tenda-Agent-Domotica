/// Returns a time-based greeting in Spanish using the device's local clock.
///
/// Ranges:
///   00:00 – 11:59 → "Buenos días"
///   12:00 – 18:59 → "Buenas tardes"
///   19:00 – 23:59 → "Buenas noches"
String greetingForNow() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Buenos días';
  if (hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}
