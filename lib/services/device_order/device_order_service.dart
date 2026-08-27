import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a custom device ordering as a map of entity_id → sortIndex.
///
/// All entries are stored together under a single SharedPreferences key to
/// minimize read/write operations. The full map is serialized as JSON.
///
/// TODO: When a multi-tenant backend is available, migrate this to server-side
/// storage so the order persists across devices and reinstallations.
abstract class DeviceOrderService {
  /// Returns the persisted order map: entity_id → sortIndex.
  /// Returns an empty map if no order has been saved yet.
  Future<Map<String, int>> getOrder();

  /// Overwrites the full persisted order map with [order].
  Future<void> saveOrder(Map<String, int> order);
}

// ── SharedPreferences implementation ──────────────────────────────────────

const _kOrderKey = 'device_order_v1';

class SharedPrefsDeviceOrderService implements DeviceOrderService {
  @override
  Future<Map<String, int>> getOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kOrderKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  @override
  Future<void> saveOrder(Map<String, int> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOrderKey, jsonEncode(order));
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

/// Provides the singleton [DeviceOrderService] implementation.
final deviceOrderServiceProvider = Provider<DeviceOrderService>(
  (_) => SharedPrefsDeviceOrderService(),
);
