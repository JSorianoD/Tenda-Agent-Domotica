import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_message.dart';
import '../services/ai_history_service.dart';

/// Provider that refreshes the UI when messages are added.
/// It's a simple [StateNotifierProvider] that holds the list in memory
/// and reads from Hive for initial data + after each write.
class _HistoryNotifier extends StateNotifier<List<AiMessage>> {
  _HistoryNotifier(this._service) : super(_service.getHistory());

  final AiHistoryService _service;

  void reload() => state = _service.getHistory();

  Future<void> clear() async {
    await _service.clear();
    state = [];
  }
}

final historyNotifierProvider =
    StateNotifierProvider<_HistoryNotifier, List<AiMessage>>((ref) {
  final service = ref.watch(aiHistoryServiceProvider);
  return _HistoryNotifier(service);
});

/// DraggableScrollableSheet that shows AI conversation history.
///
/// Open by calling `showHistoryPanel(context)`.
void showHistoryPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HistorySheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(historyNotifierProvider);
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.5, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle pill
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.history, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Historial de conversación',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    if (messages.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref.read(historyNotifierProvider.notifier).clear();
                        },
                        child: Text(
                          'Borrar',
                          style: TextStyle(
                            color: cs.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(color: cs.onSurface.withValues(alpha: 0.1), height: 1),
              // Messages list
              Expanded(
                child: messages.isEmpty
                    ? _EmptyHistory(cs: cs)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          // reverse: true → index 0 = newest
                          final msg =
                              messages[messages.length - 1 - index];
                          return _MessageBubble(message: msg, cs: cs);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no hay conversaciones',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Toca el orbe y habla con Jarvis.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.cs});

  final AiMessage message;
  final ColorScheme cs;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender label + time
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Text(
              '${isUser ? 'Tú' : 'Jarvis'}  ·  ${_relativeTime(message.timestamp)}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.45),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? cs.primary.withValues(alpha: 0.15)
                  : cs.onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isUser
                  ? Border.all(
                      color: cs.primary.withValues(alpha: 0.35),
                      width: 1,
                    )
                  : null,
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
