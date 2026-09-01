import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
    final endpoint = '$base/api/';

    debugPrint('╔══ [HA LOGIN] ════════════════════════════════════════════');
    debugPrint('║  URL original : $url');
    debugPrint('║  URL base     : $base');
    debugPrint('║  Endpoint     : $endpoint');
    debugPrint(
      '║  Token (10ch) : ${token.length > 10 ? '${token.substring(0, 10)}…' : token}',
    );
    debugPrint('╚══════════════════════════════════════════════════════════');

    http.Response response;
    try {
      debugPrint('[HA LOGIN] ► Iniciando petición HTTP GET…');
      final stopwatch = Stopwatch()..start();

      response = await http
          .get(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));

      stopwatch.stop();
      debugPrint(
        '[HA LOGIN] ◄ Respuesta en ${stopwatch.elapsedMilliseconds}ms',
      );
      debugPrint('[HA LOGIN]   Status code : ${response.statusCode}');
      debugPrint('[HA LOGIN]   Headers     : ${response.headers}');
      debugPrint(
        '[HA LOGIN]   Body (200ch): ${response.body.length > 200 ? '${response.body.substring(0, 200)}…' : response.body}',
      );
    } on TimeoutException catch (e) {
      debugPrint('[HA LOGIN] ✗ TIMEOUT después de 20s — $e');
      throw const ConnectionException(
        'Tiempo de espera agotado (20s). Verifica que la URL sea accesible desde tu red.',
      );
    } on HandshakeException catch (e) {
      debugPrint('[HA LOGIN] ✗ ERROR SSL/TLS HANDSHAKE — $e');
      throw ConnectionException('Error de certificado SSL: ${e.message}');
    } on SocketException catch (e) {
      debugPrint('[HA LOGIN] ✗ SOCKET EXCEPTION — $e');
      debugPrint('[HA LOGIN]   osError : ${e.osError}');
      debugPrint('[HA LOGIN]   address : ${e.address}');
      debugPrint('[HA LOGIN]   port    : ${e.port}');
      throw ConnectionException(
        'Error de red: ${e.message}. Verifica la URL o tu conexión.',
      );
    } on FormatException catch (e) {
      debugPrint('[HA LOGIN] ✗ FORMAT EXCEPTION (URI inválida) — $e');
      throw ConnectionException('URL inválida: ${e.message}');
    } catch (e, stack) {
      debugPrint('[HA LOGIN] ✗ EXCEPCIÓN INESPERADA — ${e.runtimeType}: $e');
      debugPrint('[HA LOGIN]   Stack: $stack');
      throw ConnectionException('Error inesperado (${e.runtimeType}): $e');
    }

    // ── Validar código HTTP ────────────────────────────────────────────
    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint(
        '[HA LOGIN] ✗ CREDENCIALES RECHAZADAS (HTTP ${response.statusCode})',
      );
      throw const InvalidCredentialsException();
    }

    if (response.statusCode != 200) {
      debugPrint(
        '[HA LOGIN] ✗ CÓDIGO HTTP INESPERADO: ${response.statusCode}',
      );
      throw ConnectionException(
        'Respuesta inesperada del servidor (${response.statusCode})',
      );
    }

    // ── Validar body ──────────────────────────────────────────────────
    debugPrint('[HA LOGIN] ► Validando body JSON…');
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('[HA LOGIN]   body["message"] = ${body['message']}');
      if (body['message'] != 'API running.') {
        debugPrint('[HA LOGIN] ✗ La URL no devuelve el mensaje esperado de HA');
        throw const InvalidCredentialsException(
          'La URL no apunta a una instancia de Home Assistant',
        );
      }
    } catch (e) {
      if (e is InvalidCredentialsException) rethrow;
      debugPrint('[HA LOGIN] ✗ Error parseando JSON del body: $e');
      throw const ConnectionException('Respuesta de la API no reconocida');
    }

    // ── Persistir credenciales ────────────────────────────────────────
    debugPrint('[HA LOGIN] ► Guardando credenciales en SecureStorage…');
    await _storage.write(key: _keyUrl, value: base);
    await _storage.write(key: _keyToken, value: token);
    debugPrint('[HA LOGIN] ✓ Credenciales guardadas. Login completado.');
  }

  // ── Session checks ─────────────────────────────────────────────────

  /// Returns `true` if stored credentials exist (app can skip login screen).
  Future<bool> isLoggedIn() async {
    final url = await _storage.read(key: _keyUrl);
    final token = await _storage.read(key: _keyToken);
    final result =
        url != null && url.isNotEmpty && token != null && token.isNotEmpty;
    debugPrint(
      '[HA AUTH] isLoggedIn() → $result '
      '(url: ${url != null ? '✓' : '✗'}, token: ${token != null ? '✓' : '✗'})',
    );
    return result;
  }

  /// Returns the stored credentials, or `null` if none exist.
  Future<HaCredentials?> getCredentials() async {
    final url = await _storage.read(key: _keyUrl);
    final token = await _storage.read(key: _keyToken);
    if (url == null || token == null) {
      debugPrint('[HA AUTH] getCredentials() → null (sin credenciales guardadas)');
      return null;
    }
    debugPrint('[HA AUTH] getCredentials() → HaCredentials(url: $url)');
    return HaCredentials(url: url, token: token);
  }

  /// Deletes all stored credentials (logout).
  Future<void> logout() async {
    debugPrint('[HA AUTH] logout() — eliminando credenciales de SecureStorage');
    await _storage.delete(key: _keyUrl);
    await _storage.delete(key: _keyToken);
    debugPrint('[HA AUTH] logout() ✓');
  }
}
