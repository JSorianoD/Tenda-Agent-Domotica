import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/ha_entity.dart';
import '../../auth/services/ha_connection_service.dart';

final haApiServiceProvider = Provider<HaApiService>((ref) {
  final authService = ref.watch(haConnectionServiceProvider);
  return HaApiService(authService);
});

/// Service to interact directly with Home Assistant API.
class HaApiService {
  HaApiService(this._authService);

  final HaConnectionService _authService;

  /// Verifica que la instancia de Home Assistant sea alcanzable.
  ///
  /// Llama a GET /api/ y comprueba que devuelva 200 con el mensaje correcto.
  /// Lanza [ConnectionException] si la red falla, [InvalidCredentialsException]
  /// si el token es rechazado.
  Future<void> ping() async {
    final credentials = await _authService.getCredentials();
    if (credentials == null) {
      throw Exception('No se encontraron credenciales guardadas.');
    }
    final response = await http
        .get(
          Uri.parse('${credentials.url}/api/'),
          headers: {
            'Authorization': 'Bearer ${credentials.token}',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Token inválido o expirado (HTTP ${response.statusCode}).',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('HA devolvio HTTP ${response.statusCode}.');
    }
  }

  /// Fetches all entities from /api/states.
  Future<List<HaEntity>> getStates() async {
    final credentials = await _authService.getCredentials();
    if (credentials == null) {
      throw Exception('No valid credentials found for Home Assistant.');
    }

    final url = Uri.parse('${credentials.url}/api/states');

    final response = await http
        .get(
          url,
          headers: {
            'Authorization': 'Bearer ${credentials.token}',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Error fetching states. Status code: ${response.statusCode}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;

    return data
        .cast<Map<String, dynamic>>()
        .map((json) => HaEntity.fromJson(json))
        .toList();
  }

  /// Calls a Home Assistant service.
  /// Example: domain = "light", service = "turn_on", data = {"entity_id": "light.main"}
  Future<List<dynamic>> callService(
    String domain,
    String service,
    Map<String, dynamic> data,
  ) async {
    final credentials = await _authService.getCredentials();
    if (credentials == null) {
      throw Exception('No valid credentials found for Home Assistant.');
    }

    final url = Uri.parse('${credentials.url}/api/services/$domain/$service');

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer ${credentials.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Error calling service $domain.$service. Status code: ${response.statusCode}',
      );
    }

    if (response.body.isNotEmpty) {
      final json = jsonDecode(response.body);
      if (json is List) return json;
    }
    return [];
  }

  /// Fetches the mapping of light entity IDs to their area names from Home Assistant.
  /// 
  /// Home Assistant's REST API doesn't expose areas directly in `/api/states`, 
  /// so we evaluate a Jinja2 template to extract this information natively.
  Future<Map<String, String>> getEntityAreas() async {
    final credentials = await _authService.getCredentials();
    if (credentials == null) {
      throw Exception('No valid credentials found for Home Assistant.');
    }

    final url = Uri.parse('${credentials.url}/api/template');
    
    // Jinja2 template to iterate through lights (and switches) and get their areas
    // HA Jinja requires `namespace` to modify variables inside a loop.
    const templateStr = '''
{% set ns = namespace(areas={}) %}
{% for state in states.light %}
  {% set a_id = area_id(state.entity_id) %}
  {% if a_id %}
    {% set ns.areas = dict(ns.areas, **{state.entity_id: area_name(a_id)}) %}
  {% endif %}
{% endfor %}
{% for state in states.switch %}
  {% set a_id = area_id(state.entity_id) %}
  {% if a_id %}
    {% set ns.areas = dict(ns.areas, **{state.entity_id: area_name(a_id)}) %}
  {% endif %}
{% endfor %}
{{ ns.areas | tojson }}
''';

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer ${credentials.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'template': templateStr}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Error fetching areas via template. HTTP ${response.statusCode}: ${response.body}',
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (e) {
      throw Exception('Error parsing areas JSON: $e');
    }
  }
}
