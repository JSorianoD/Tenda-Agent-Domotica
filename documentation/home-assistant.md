# Integración con Home Assistant

## Servicio principal: `HaApiService`

Clase ubicada en `lib/features/home_assistant/services/ha_api_service.dart`.

Provista mediante `haApiServiceProvider` (`Provider<HaApiService>`).

Las credenciales (URL y token) se leen de `HaConnectionService` en cada llamada, lo que garantiza que siempre se usen las credenciales más recientes del storage.

---

## Endpoints utilizados

### GET `/api/` — Verificación de conectividad

```
GET {baseUrl}/api/
Headers:
  Authorization: Bearer {token}
  Content-Type: application/json
Timeout: 8 segundos (10 en el proceso de login)
```

**Respuesta esperada (HTTP 200):**
```json
{"message": "API running."}
```

**Cuándo se llama:**
- Durante el proceso de login (`HaConnectionService.login()`)
- Al abrir `DevicesScreen` como verificación previa a listar dispositivos (`HaApiService.ping()`)

---

### GET `/api/states` — Obtener todas las entidades

```
GET {baseUrl}/api/states
Headers:
  Authorization: Bearer {token}
  Content-Type: application/json
Timeout: 15 segundos
```

**Respuesta:** Array JSON de entidades HA.

**Cuándo se llama:**
- Al inicializar `HaStatesController` (`haStatesProvider`)
- Al hacer pull-to-refresh en pantallas que lo soportan
- Al abrir `LightsScreen` (dispara un refresh automático)

---

### POST `/api/services/{domain}/{service}` — Ejecutar servicios

```
POST {baseUrl}/api/services/{domain}/{service}
Headers:
  Authorization: Bearer {token}
  Content-Type: application/json
Body: { "entity_id": "..." }
Timeout: 10 segundos
```

**Servicios ejecutados por la app:**

| Llamada | Cuándo |
|---------|--------|
| `light/toggle` | Toggle de una luz individual |
| `switch/toggle` | Toggle de un interruptor individual |
| `light/turn_on` | Encender una luz (desde LightsScreen) |
| `light/turn_off` | Apagar una luz (desde LightsScreen) |
| `light/turn_off` con `entity_id: all` | Apagar todas las luces |
| `switch/turn_off` con `entity_id: all` | Apagar todos los switches |

**Respuesta:** Array de estados cambiados (`changed_states`). La app verifica el estado real devuelto por HA para confirmar el resultado del toggle.

---

## Modelo de entidad: `HaEntity`

Representa una entidad del `/api/states` de Home Assistant:

```dart
class HaEntity {
  final String entityId;      // ej: "light.sala_principal"
  final String state;         // ej: "on", "off", "sunny", "home"
  final Map<String, dynamic> attributes; // datos adicionales según el dominio
  final String lastChanged;   // timestamp ISO 8601
  final String lastUpdated;   // timestamp ISO 8601
  final String area;          // valor LOCAL (no viene de HA), default: "TODAS"
}
```

**Campos de `attributes` más utilizados:**

| Atributo | Tipo | Uso |
|----------|------|-----|
| `friendly_name` | String | Nombre legible del dispositivo |
| `temperature` | num | Temperatura (WeatherScreen) |
| `temperature_unit` | String | Unidad (ej: `°C`) |
| `humidity` | num | Humedad (WeatherScreen) |
| `device_class` | String | Tipo de sensor (`door`, `motion`, etc.) |
| `unit_of_measurement` | String | Unidad del sensor |
| `entity_picture` | String | Ruta relativa de imagen de cámara |

---

## Clasificación automática de entidades

`HaStatesController` clasifica todas las entidades de `/api/states` en grupos:

```
entities (Array desde /api/states)
    │
    ├─ domain == "person"           → personEntities
    ├─ domain == "light"            → lightEntities
    ├─ domain == "scene"            → sceneEntities
    ├─ domain == "weather"          → weatherEntities
    ├─ domain == "camera"           → securityEntities
    ├─ domain == "alarm_control_panel" → securityEntities
    ├─ domain == "sensor"
    │       ├─ device_class == temperature | humidity → weatherEntities
    │       └─ otros → sensorEntities
    └─ domain == "binary_sensor"
            ├─ device_class == door | window | motion → securityEntities
            └─ otros → sensorEntities
```

---

## HaHomeConnector: integración para DevicesScreen

`HaHomeConnector` implementa la interfaz `HomeConnector` usando `HaApiService`.

Al obtener habitaciones (`getRooms()`), extrae entidades de dominio `light` y `switch` de `/api/states` y las agrupa en **una sola habitación** llamada `TODAS LAS LUCES`:

> La API `/api/states` no expone información de área por habitación directamente. Para consultar áreas reales, sería necesario consultar el registro de dispositivos de HA (`/api/entity_registry` o similar). Actualmente no está implementado.

---

## Manejo de errores de red

Ambos controladores (`DevicesController` y `HaStatesController`) implementan el mismo patrón:

1. **Optimistic update:** el cambio se refleja inmediatamente en la UI.
2. **Llamada real a HA:** se ejecuta en background.
3. **Si HA confirma:** la UI queda con el estado real devuelto por HA.
4. **Si HA falla:** se revierte el cambio optimista y se muestra un `SnackBar` con el error.

Los errores se propagan a la UI mediante el campo `connectionError` del estado del controller.
