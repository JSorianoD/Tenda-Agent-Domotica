/// Credentials for connecting to a Home Assistant instance.
class HaCredentials {
  const HaCredentials({required this.url, required this.token});

  /// Base URL of the HA instance, e.g. `https://homeassistant.local:8123`
  final String url;

  /// Long-Lived Access Token generated in HA's user profile.
  final String token;
}
