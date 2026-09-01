# Agente de Voz e Integración con n8n

## Visión general

La app se comunica con un agente de inteligencia artificial alojado en **n8n** mediante un webhook HTTP. El usuario puede interactuar con el agente de dos formas:

1. **Por voz:** grabando audio con el micrófono del dispositivo.
2. **Por texto:** enviando un comando de texto (disponible via `JarvisCoreController.sendTextCommand()`).

El agente procesa la solicitud, genera una respuesta textual y opcionalmente devuelve audio TTS (Text-to-Speech) que la app reproduce automáticamente.

---

## Servicio de agente: `JarvisAgentService`

Clase ubicada en `lib/services/agent/n8n_agent_service.dart`.

Provista mediante `agentServiceProvider` (`Provider<JarvisAgentService>`).

### Sesión

Cada instancia de `JarvisAgentService` genera un `session_id` único (UUID v4) al crearse. Este identificador se envía en cada petición al webhook para que n8n pueda mantener contexto conversacional.

> El `session_id` es nuevo cada vez que la app se reinicia (el objeto se recrea). Si n8n usa el `session_id` para memoria conversacional, el historial se pierde al reiniciar la app.

---

## Comunicación con el webhook

### Endpoint

> **Advertencia:** La URL del webhook está actualmente **hardcodeada** en el código fuente (`n8n_agent_service.dart`). Esto es un riesgo de seguridad si el repositorio es público.

### Envío de audio

```
POST {webhookUrl}
Content-Type: multipart/form-data

Campos:
  session_id  (String) — UUID de sesión
  audio       (File)   — archivo WAV grabado en el dispositivo
```

### Envío de texto

```
POST {webhookUrl}
Content-Type: multipart/form-data

Campos:
  session_id  (String) — UUID de sesión
  text        (String) — comando de texto
```

### Respuesta esperada (JSON)

```json
{
  "reply": "Texto de respuesta del agente",
  "audio_base64": "base64-encoded-audio-string",
  "audio_format": "mp3"
}
```

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `reply` | String | Sí | Texto de la respuesta del agente |
| `audio_base64` | String | No | Audio TTS codificado en base64 |
| `audio_format` | String | No | Formato del audio (ej: `mp3`, `wav`) |

Si `audio_base64` no está presente (nodo TTS omitido o fallido en n8n), la app muestra solo el texto y vuelve al estado `idle` tras 3 segundos.

---

## Estados del orbe Jarvis

El orbe central de la app tiene cuatro estados visuales, cada uno con su propia animación:

| Estado | Enum | Descripción | Animación |
|--------|------|-------------|-----------|
| En espera | `JarvisState.idle` | Sin actividad | Ciclo continuo, 3000ms, reverse |
| Escuchando | `JarvisState.listening` | Grabando audio | Ciclo continuo, 1800ms |
| Procesando | `JarvisState.processing` | Enviando a n8n, esperando respuesta | Ciclo continuo, 2500ms |
| Respondiendo | `JarvisState.responding` | Reproduciendo respuesta | 3 ondas escalonadas, 2880ms |

Cada estado tiene su propio `AnimationController` y `CustomPainter`. Solo el controller del estado activo corre (optimización de CPU/batería).

---

## Flujo completo de interacción por voz

```
[Orbe en estado IDLE]
Usuario toca el orbe
        │
        ▼
JarvisCoreWidget._startRecording()
  ├─ Verifica permiso de micrófono
  │     └─ Sin permiso → SnackBar "Permiso de micrófono denegado" → Abort
  │
  ├─ Crea ruta temporal: {tmpDir}/jarvis_{timestamp}.wav
  ├─ Inicia grabación WAV con AudioRecorder
  └─ Estado → LISTENING ("Escuchando… toca de nuevo para enviar")

[Orbe en estado LISTENING]
Usuario toca el orbe de nuevo
        │
        ▼
JarvisCoreWidget._stopAndSend()
  ├─ Detiene grabación → obtiene ruta del archivo
  │     └─ path == null → abortToIdle("No se grabó audio")
  │
  └─ Llama a JarvisCoreController.sendAudioCommand(File)

JarvisCoreController.sendAudioCommand()
  ├─ Estado → PROCESSING ("Procesando audio…")
  │
  ├─ JarvisAgentService.sendAudio(audioFile)
  │     └─ POST multipart al webhook n8n
  │
  ├─ En caso de error → Estado → IDLE ("Error: {mensaje}")
  │
  └─ Respuesta OK → _respondAndPlay(AgentReply)
        ├─ Estado → RESPONDING (muestra reply.text en subtitle)
        │
        ├─ Si reply.audioBytes != null:
        │     └─ AudioPlayer.play(BytesSource(bytes))
        │           └─ Espera PlayerState.completed
        │
        └─ Si reply.audioBytes == null:
              └─ Future.delayed(3 segundos)

[Al terminar audio o timeout]
        │
        ▼
Estado → IDLE ("Conectado · En espera")
```

---

## Grabación de audio

- **Librería:** `record` (`AudioRecorder`)
- **Formato:** WAV (`AudioEncoder.wav`)
- **Destino:** directorio temporal del sistema (`getTemporaryDirectory()`)
- **Nombre del archivo:** `jarvis_{millisecondsSinceEpoch}.wav`

---

## Reproducción de audio

- **Librería:** `audioplayers` (`AudioPlayer`)
- **Fuente:** `BytesSource(Uint8List)` — audio en memoria, no se guarda en disco
- **Evento de fin:** `onPlayerComplete` — dispara la transición a `idle`
- **Fallback:** si no hay audio, timer de 3 segundos

---

## JarvisCoreController: API pública

| Método | Descripción |
|--------|-------------|
| `startListening()` | Cambia al estado listening (lo llama el widget) |
| `abortToIdle([reason])` | Vuelve a idle con mensaje opcional |
| `sendTextCommand(String text)` | Flujo completo listening → processing → responding → idle |
| `sendAudioCommand(File audioFile)` | Flujo processing → responding → idle |
| `cycleState()` | Cicla entre estados (solo para testing visual — ver TODO en código) |

---

## Excepciones

| Excepción | Cuándo |
|-----------|--------|
| `AgentException` | El webhook devuelve código HTTP ≠ 200 |

En caso de error, el estado vuelve a `idle` y el subtitle muestra `"Error: {mensaje}"`.
