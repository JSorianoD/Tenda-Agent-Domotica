import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// ── Webhook URL (hardcoded for now) ──────────────────────────────────────
const _webhookUrl =
    'https://auto.lms-vos.training/webhook/73f93174-50da-4c98-93d0-70e879a84b65';

// ── Reply model ───────────────────────────────────────────────────────────

/// Holds the agent's response: always a text [reply], and optionally
/// pre-generated neural audio ([audioBytes]) from the n8n TTS step.
///
/// When [audioBytes] is non-null the app plays it directly via audioplayers.
/// When it is null (TTS node skipped or failed in n8n) the app falls back
/// to showing the text and returning to idle after a short timeout.
class AgentReply {
  const AgentReply({required this.text, this.audioBytes, this.audioFormat});

  final String text;
  final Uint8List? audioBytes;

  /// e.g. 'mp3', 'wav', 'aac' — matches [audioplayers] source type.
  final String? audioFormat;
}

// ── Exception ────────────────────────────────────────────────────────────

/// Thrown when the n8n webhook returns a non-200 status code.
class AgentException implements Exception {
  const AgentException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'AgentException($statusCode): $body';
}

// ── Service ──────────────────────────────────────────────────────────────

/// Riverpod provider for the agent service.
final agentServiceProvider = Provider<JarvisAgentService>((ref) {
  return JarvisAgentService();
});

/// Communicates with the n8n Jarvis agent webhook.
///
/// Both [sendAudio] and [sendText] use `multipart/form-data` requests.
/// The webhook returns JSON with:
///   - `reply`       (String, always present)
///   - `audio_base64` (String?, base64-encoded audio, present when n8n TTS ran)
///   - `audio_format` (String?, e.g. 'mp3' — matches the encoded audio)
class JarvisAgentService {
  JarvisAgentService() : _sessionId = const Uuid().v4();

  final String _sessionId;

  /// Send a recorded audio file to the agent.
  Future<AgentReply> sendAudio(File audioFile) async {
    final request = http.MultipartRequest('POST', Uri.parse(_webhookUrl));
    request.fields['session_id'] = _sessionId;
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );
    return _send(request);
  }

  /// Send a text command to the agent.
  Future<AgentReply> sendText(String text) async {
    final request = http.MultipartRequest('POST', Uri.parse(_webhookUrl));
    request.fields['session_id'] = _sessionId;
    request.fields['text'] = text;
    return _send(request);
  }

  // ── Internal ─────────────────────────────────────────────────────────

  Future<AgentReply> _send(http.MultipartRequest request) async {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw AgentException(
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final audioBase64 = body['audio_base64'] as String?;

    return AgentReply(
      text: body['reply'] as String,
      audioBytes: audioBase64 != null ? base64Decode(audioBase64) : null,
      audioFormat: body['audio_format'] as String?,
    );
  }
}
