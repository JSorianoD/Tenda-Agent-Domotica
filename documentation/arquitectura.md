# Arquitectura del Proyecto

## Visión general

El proyecto sigue un patrón **feature-first** con separación por capas dentro de cada feature. El estado global se gestiona con **Riverpod** (`ProviderScope` envuelve toda la app desde `main.dart`). La navegación usa **GoRouter**.

---

## Estructura de carpetas

```
lib/
├── main.dart                         # Punto de entrada, ProviderScope, MaterialApp.router
│
├── core/                             # Infraestructura compartida (no contiene lógica de negocio)
│   ├── router/
│   │   └── app_router.dart           # Definición de rutas y guard de autenticación
│   ├── theme/
│   │   ├── app_colors.dart           # Tokens de color del sistema de diseño Tenda
│   │   └── app_theme.dart            # ThemeData global (buildTendaTheme)
│   └── utils/
│       └── greeting.dart             # Saludo basado en hora del día (español)
│
├── features/                         # Módulos de funcionalidad
│   ├── auth/                         # Autenticación con Home Assistant
│   │   ├── domain/
│   │   │   └── ha_credentials.dart   # Modelo de credenciales (url + token)
│   │   ├── presentation/
│   │   │   └── ha_connection_screen.dart   # Pantalla de login
│   │   ├── services/
│   │   │   └── ha_connection_service.dart  # Login, logout, SecureStorage
│   │   └── state/
│   │       └── ha_credentials_provider.dart # FutureProvider con credenciales actuales
│   │
│   ├── devices/                      # Control de dispositivos agrupados por habitación
│   │   ├── domain/
│   │   │   ├── device.dart           # Modelo Device (id, name, type, isOn, sortIndex)
│   │   │   └── room.dart             # Modelo Room (id, name, devices[])
│   │   ├── presentation/
│   │   │   └── devices_screen.dart   # Pantalla "Iluminación" (ruta /devices)
│   │   └── state/
│   │       └── devices_controller.dart  # StateNotifier con optimistic updates
│   │
│   ├── home_assistant/               # Integración directa con la API de HA
│   │   ├── domain/
│   │   │   └── ha_entity.dart        # Modelo HaEntity (mapeado desde /api/states)
│   │   ├── services/
│   │   │   └── ha_api_service.dart   # ping(), getStates(), callService()
│   │   └── state/
│   │       └── ha_states_controller.dart  # AsyncNotifier con entidades clasificadas
│   │
│   └── jarvis_core/                  # Orbe animado y pantallas secundarias del dashboard
│       ├── presentation/
│       │   ├── painters/             # CustomPainters por estado del orbe
│       │   │   ├── idle_painter.dart
│       │   │   ├── listening_painter.dart
│       │   │   ├── processing_painter.dart
│       │   │   └── responding_painter.dart
│       │   ├── home_screen.dart      # Pantalla principal (ruta /)
│       │   ├── jarvis_core_widget.dart  # Orbe interactivo con grabación de audio
│       │   ├── lights_screen.dart    # Vista de luces con tabs y drag & drop
│       │   ├── security_screen.dart  # Vista de seguridad (cámaras y sensores)
│       │   └── weather_screen.dart   # Vista de clima y sensores ambientales
│       └── state/
│           └── jarvis_core_controller.dart  # Orquesta el flujo de voz con n8n
│
└── services/                         # Servicios transversales (no pertenecen a un feature)
    ├── agent/
    │   └── n8n_agent_service.dart    # Comunicación con el webhook n8n (voz/texto)
    ├── device_order/
    │   └── device_order_service.dart # Persistencia del orden de dispositivos
    └── home_connector/
        ├── home_connector.dart        # Interfaz abstracta HomeConnector
        ├── ha_home_connector.dart     # Implementación real (activa) con HaApiService
        └── mock_home_connector.dart   # Implementación mock con datos en memoria
```

---

## Capas por feature

Cada feature sigue esta estructura de capas (no todas son obligatorias):

| Capa | Carpeta | Responsabilidad |
|------|---------|-----------------|
| **Domain** | `domain/` | Modelos de datos puros (sin dependencias de Flutter) |
| **Services** | `services/` | Lógica de acceso a datos y APIs externas |
| **State** | `state/` | Providers Riverpod y controladores de estado |
| **Presentation** | `presentation/` | Widgets, pantallas y painters |

---

## Patrón de estado: Riverpod

El proyecto usa tres tipos de providers de Riverpod:

| Tipo | Usado en | Propósito |
|------|----------|-----------|
| `Provider<T>` | Servicios singleton | Proveer una instancia única (ej: `HaApiService`) |
| `StateNotifierProvider` | Controllers con estado complejo | `DevicesController`, `JarvisCoreController` |
| `AsyncNotifierProvider` | Estado que se carga de forma asíncrona | `HaStatesController` |
| `FutureProvider` | Datos async de una sola lectura | `haCredentialsProvider` |

---

## Interfaz HomeConnector

El acceso al backend de domótica se abstrae mediante la interfaz `HomeConnector`:

```dart
abstract class HomeConnector {
  Future<List<Room>> getRooms();
  Future<List<dynamic>> toggleDevice(String deviceId);
  Future<void> turnOffAllDevices();
  Future<void> sendVoiceCommand(String text);
  Stream<JarvisState> get coreStateChanges;
  void dispose();
}
```

**Implementaciones disponibles:**

| Clase | Estado | Cuándo usar |
|-------|--------|-------------|
| `HaHomeConnector` | **Activa** | Producción, conectado a HA real |
| `MockHomeConnector` | Disponible | Desarrollo sin instancia de HA |

El provider activo es `homeConnectorProvider` definido en `ha_home_connector.dart`.

---

## Navegación

La app usa **GoRouter** con un guard de autenticación:

| Ruta | Pantalla | Requisito |
|------|----------|-----------|
| `/login` | `HaConnectionScreen` | Acceso libre (sin credenciales) |
| `/` | `HomeScreen` | Requiere credenciales en SecureStorage |
| `/devices` | `DevicesScreen` | Requiere credenciales en SecureStorage |

Las pantallas `LightsScreen`, `WeatherScreen` y `SecurityScreen` se navegan mediante `Navigator.push` desde `HomeScreen` (no tienen rutas GoRouter propias).

---

## Punto de entrada

```
main() → ProviderScope → JarvisApp → MaterialApp.router
                                       ├── theme: buildTendaTheme()
                                       ├── themeMode: ThemeMode.dark (forzado)
                                       └── routerConfig: appRouterProvider
```

El modo oscuro es permanente por decisión de diseño de marca (ver [decisiones-tecnicas.md](decisiones-tecnicas.md)).
