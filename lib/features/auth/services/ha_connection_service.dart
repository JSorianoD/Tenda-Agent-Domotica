import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/ha_credentials.dart';

// ── Storage keys ─────────────────────────────────────────────────────────
const _keyUrl = 'ha_url';
const _keyToken = 'ha_token';

// ── Providers ─────────────────────────────────────────────────────────────

/// Provides the singleton [HaConnectionService].
final haConnectionServiceProvider = Provider<HaConnectionService>(
  (ref) => HaConnectionService(),
);

// ── Exceptions ────────────────────────────────────────────────────────────

/// Thrown when credentials are rejected by the HA API.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException([this.message = 'Credenciales inválidas']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when the network request fails (timeout, unreachable host, etc.).
class ConnectionException implements Exception {
  const ConnectionException([this.message = 'Error de conexión']);
  final String message;
  @override
  String toString() => message;
}

// ── Service ───────────────────────────────────────────────────────────────

/// Handles Home Assistant authentication and secure credential storage.
///
/// Uses a Long-Lived Access Token (PoC approach).
/// Credentials are persisted via [FlutterSecureStorage]:
///   - Windows: DPAPI-encrypted file
///   - Android: EncryptedSharedPreferences
class HaConnectionService {
  HaConnectionService()
    : _storage = const FlutterSecureStorage(
        // Windows options — store alongside the app data.
        wOptions: WindowsOptions(useBackwardCompatibility: false),
      );

  final FlutterSecureStorage _storage;

  // ── Login ──────────────────────────────────────────────────────────

  /// Validates [url] + [token] against the HA REST API, then persists them.
  ///
  /// Throws [ConnectionException] on network errors,
  /// [InvalidCredentialsException] when HA rejects the token.
  Future<void> login(String url, String token) async {
    // Normalise: strip trailing slash
    final base = url.trimRight().replaceAll(RegExp(r'/+$'), '');

    http.Response response;
    try {
      response = await http
          .get(
            Uri.parse('$base/api/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      throw const ConnectionException('Tiempo de espera agotado.');
    } on SocketException catch (_) {
      throw const ConnectionException(
        'Error de red. Verifica la URL o tu conexión.',
      );
    } catch (e) {
      throw ConnectionException('Error inesperado: $e');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const InvalidCredentialsException();
    }

    if (response.statusCode != 200) {
      throw ConnectionException(
        'Respuesta inesperada del servidor (${response.statusCode})',
      );
    }

    // Verify the canonical HA API response.
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['message'] != 'API running.') {
        throw const InvalidCredentialsException(
          'La URL no apunta a una instancia de Home Assistant',
        );
      }
    } catch (e) {
      if (e is InvalidCredentialsException) rethrow;
      throw const ConnectionException('Respuesta de la API no reconocida');
    }

    // Persist credentials.
    await _storage.write(key: _keyUrl, value: base);
    await _storage.write(key: _keyToken, value: token);
  }

  // ── Session checks ─────────────────────────────────────────────────

  /// Returns `true` if stored credentials exist (app can skip login screen).
  Future<bool> isLoggedIn() async {
    final url = await _storage.read(key: _keyUrl);
    final token = await _storage.read(key: _keyToken);
    return url != null && url.isNotEmpty && token != null && token.isNotEmpty;
  }

  /// Returns the stored credentials, or `null` if none exist.
  Future<HaCredentials?> getCredentials() async {
    final url = await _storage.read(key: _keyUrl);
    final token = await _storage.read(key: _keyToken);
    if (url == null || token == null) return null;
    return HaCredentials(url: url, token: token);
  }

  /// Deletes all stored credentials (logout).
  Future<void> logout() async {
    await _storage.delete(key: _keyUrl);
    await _storage.delete(key: _keyToken);
  }
}
