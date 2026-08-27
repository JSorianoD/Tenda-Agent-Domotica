import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ha_credentials.dart';
import '../services/ha_connection_service.dart';

/// Exposes the persisted authentication credentials reactively.
/// Useful for features that need the raw token or base URL synchronously
/// after initialization (e.g., rendering secure images via Image.network).
final haCredentialsProvider = FutureProvider<HaCredentials?>((ref) async {
  final authService = ref.watch(haConnectionServiceProvider);
  return authService.getCredentials();
});
