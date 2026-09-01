import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../domain/ai_message.dart';

const _kBoxName = 'ai_history';

/// CRUD service for the local AI conversation history.
///
/// Backed by a Hive box. Riverpod provider exposes a singleton instance.
class AiHistoryService {
  Box<AiMessage> get _box => Hive.box<AiMessage>(_kBoxName);

  /// Opens the Hive box. Call once during app init (before ProviderScope).
  static Future<void> init() async {
    Hive.registerAdapter(AiMessageAdapter());
    await Hive.openBox<AiMessage>(_kBoxName);
  }

  /// Adds a new message to the end of the history.
  Future<void> addMessage({
    required String text,
    required bool isUser,
  }) async {
    final msg = AiMessage(
      text: text,
      isUser: isUser,
      timestamp: DateTime.now(),
    );
    await _box.add(msg);
  }

  /// Returns all messages in chronological order (oldest first).
  List<AiMessage> getHistory() {
    return _box.values.toList();
  }

  /// Clears the entire history.
  Future<void> clear() async {
    await _box.clear();
  }
}

final aiHistoryServiceProvider = Provider<AiHistoryService>((ref) {
  return AiHistoryService();
});
