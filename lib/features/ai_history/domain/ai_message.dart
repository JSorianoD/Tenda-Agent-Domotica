import 'package:hive_ce/hive.dart';

/// Un mensaje en el historial de conversación con la IA.
///
/// [text] — contenido del mensaje.
/// [isUser] — true si fue enviado por el usuario, false si es respuesta de Jarvis.
/// [timestamp] — momento en que se registró.
class AiMessage extends HiveObject {
  AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  late String text;
  late bool isUser;
  late DateTime timestamp;
}

/// TypeAdapter manual para AiMessage (sin build_runner).
class AiMessageAdapter extends TypeAdapter<AiMessage> {
  @override
  final int typeId = 0;

  @override
  AiMessage read(BinaryReader reader) {
    return AiMessage(
      text: reader.readString(),
      isUser: reader.readBool(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, AiMessage obj) {
    writer.writeString(obj.text);
    writer.writeBool(obj.isUser);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
  }
}
