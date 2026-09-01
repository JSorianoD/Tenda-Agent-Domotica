# Pantallas

## Mapa de navegación

```
AppRouter (GoRouter)
├── /login  ──────────── HaConnectionScreen
│
└── /        ──────────── HomeScreen
      │
      ├── Navigator.push ──► LightsScreen
      ├── Navigator.push ──► WeatherScreen
      ├── Navigator.push ──► SecurityScreen
      └── context.push('/login') ──► HaConnectionScreen (reconfiguración)

/devices ────────────── DevicesScreen
```

> Las pantallas `LightsScreen`, `WeatherScreen` y `SecurityScreen` se abren con `Navigator.push` (sin ruta GoRouter). `DevicesScreen` tiene ruta propia en `/devices` pero no tiene un punto de entrada visible desde `HomeScreen` en la versión actual.

---

## HaConnectionScreen — Configuración de Home Assistant

**Ruta:** `/login`  
**Archivo:** `lib/features/auth/presentation/ha_connection_screen.dart`  
**Acceso:** Sin autenticación (pantalla inicial si no hay credenciales)

### Descripción

Pantalla de configuración donde el usuario ingresa la URL de su instancia de Home Assistant y su Long-Lived Access Token.

### Elementos de la UI

| Elemento | Descripción |
|----------|-------------|
| Logo Tenda | `assets/images/tenda_logo_full.png` |
| Título | "Configuración Home Assistant" |
| Campo URL | Texto libre, tipo URL, hint: `http://homeassistant.local:8123` |
| Campo Token | Campo oscuro (`obscureText`), con botón de visibilidad |
| Botón | "PROBAR CONEXIÓN" — ejecuta validación contra HA |
| Loading | `CircularProgressIndicator` mientras valida |
| Error | `SnackBar` rojo con mensaje del error |

### Comportamiento especial

- Al abrir la pantalla, carga automáticamente las credenciales guardadas en los campos (si existen), para facilitar la edición.
- Animación de entrada: fade-in de 900ms.
- Layout adaptativo: usa `LayoutBuilder` + `ConstrainedBox` para centrarse correctamente en pantallas de distintos tamaños.

---

## HomeScreen — Pantalla principal

**Ruta:** `/`  
**Archivo:** `lib/features/jarvis_core/presentation/home_screen.dart`  
**Acceso:** Requiere credenciales

### Descripción

Pantalla central de la aplicación. Muestra el orbe animado de Jarvis, información del usuario y el estado de conexión, y el dock de navegación inferior.

### Elementos de la UI

| Elemento | Descripción |
|----------|-------------|
| Barra de estado | Saludo + nombre de `person` de HA + indicador de ubicación |
| Reloj | Hora actual, actualizado cada 30 segundos |
| Botón settings | Navega a `/login` para reconfigurar credenciales |
| Etiqueta de estado | EN ESPERA / ESCUCHANDO / PROCESANDO / RESPONDIENDO |
| Línea divisora | Decorativa, dorado al 30% |
| Orbe Jarvis | Widget animado interactivo (`JarvisCoreWidget`) |
| Subtitle | Texto dinámico: mensaje del agente, estado actual, o error |
| Hint historial | "desliza para historial" (funcionalidad pendiente de implementar) |
| Dock inferior | 4 botones: LUCES, CLIMA, SEGURIDAD, APAGAR TODO |

### Carga inicial

La pantalla carga `haStatesProvider` (`AsyncNotifierProvider`). Mientras carga muestra un `CircularProgressIndicator` dorado. Si falla muestra un panel de error con botón "REINTENTAR".

### Dock inferior

| Botón | Acción |
|-------|--------|
| LUCES | `Navigator.push` → `LightsScreen` |
| CLIMA | `Navigator.push` → `WeatherScreen` |
| SEGURIDAD | `Navigator.push` → `SecurityScreen` |
| APAGAR TODO | `devicesProvider.notifier.turnOffAll()` + SnackBar confirmación |

---

## LightsScreen — Luces

**Acceso:** Navigator.push desde HomeScreen (botón LUCES)  
**Archivo:** `lib/features/jarvis_core/presentation/lights_screen.dart`

### Descripción

Lista todas las entidades de dominio `light` de HA con un toggle individual por luz. Permite organizarlas en áreas mediante tabs y reordenarlas con drag & drop.

### Elementos de la UI

| Elemento | Descripción |
|----------|-------------|
| AppBar | "LUCES" con botón de retroceso |
| Tabs | TODAS / CASA GIOVANNI / TENDA OFICINA |
| Lista | `ReorderableListView` con `SwitchListTile` por luz |
| Toggle | Switch dorado/gris según estado |
| Menú ⋮ | Permite mover la luz a otra área |
| Handle drag | Ícono `drag_handle` para reordenar |
| Loading | `CircularProgressIndicator` mientras carga |
| Error snackbar | Aparece si el toggle falla |

### Comportamiento

- Al abrir la pantalla, dispara un refresh automático de `haStatesProvider`.
- El scroll horizontal del `TabBarView` está desactivado (`NeverScrollableScrollPhysics`) para evitar conflictos con el gesto de drag.
- Los cambios de área y orden se persisten en `SharedPreferences`.

---

## WeatherScreen — Clima

**Acceso:** Navigator.push desde HomeScreen (botón CLIMA)  
**Archivo:** `lib/features/jarvis_core/presentation/weather_screen.dart`

### Descripción

Muestra el estado del clima y sensores ambientales (temperatura, humedad) de Home Assistant.

### Elementos de la UI

| Elemento | Descripción |
|----------|-------------|
| Card principal | Estado del tiempo (ícono, descripción, temperatura, humedad) |
| Sección "SENSORES DE AMBIENTE" | Lista de sensores de temperatura y humedad |
| Sensor tile | Ícono + nombre + valor con unidad |

### Estados del clima reconocidos

`sunny`, `clear`, `clear-night`, `cloudy`, `partlycloudy`, `rainy`, `pouring`, `windy`, `fog`

---

## SecurityScreen — Seguridad

**Acceso:** Navigator.push desde HomeScreen (botón SEGURIDAD)  
**Archivo:** `lib/features/jarvis_core/presentation/security_screen.dart`

### Descripción

Muestra cámaras y sensores de seguridad de Home Assistant.

### Elementos de la UI

| Elemento | Descripción |
|----------|-------------|
| Camera card | Header con nombre + indicador rojo + imagen en 16:9 |
| Imagen de cámara | Cargada desde HA con el token de auth como header HTTP |
| Fallback de cámara | Ícono + "Señal no disponible" si la imagen falla |
| Sensor tile | Ícono según tipo + nombre + estado en mayúsculas |

### Tipos de sensor reconocidos

| `device_class` | Ícono |
|-----------------|-------|
| `door` | `meeting_room` / `door_front_door` |
| `window` | `window` |
| `motion` | `directions_run` |
| `alarm_control_panel` | `shield` / `shield_outlined` |
| Otros | `sensors` |

---

## DevicesScreen — Iluminación (ruta /devices)

**Ruta:** `/devices`  
**Archivo:** `lib/features/devices/presentation/devices_screen.dart`

### Descripción

Vista alternativa de control de dispositivos, organizada por habitaciones colapsables con drag & drop por habitación. Muestra todas las entidades `light` y `switch` de HA agrupadas en la habitación "TODAS LAS LUCES".

### Elementos de la UI

| Elemento | Descripción |
|----------|-------------|
| Header | Título "Iluminación" + contador de luces activas + "APAGAR TODO" |
| Room header | Nombre de habitación + contador activos/total + botón "APAGAR" |
| Toggle room | Tap en el header colapsa/expande los dispositivos |
| Device row | Handle drag + ícono + nombre + switch |
| Empty state | Si no hay luces/switches configurados |
| Connection error | Si HA no responde al abrir la pantalla |

### Arquitectura especial

Usa un único `CustomScrollView` con `SliverReorderableList` por habitación (en lugar de listas anidadas) para evitar conflictos de gestos entre scroll y drag. Ver [troubleshooting.md](troubleshooting.md).
