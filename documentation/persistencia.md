# Persistencia de datos locales

## Resumen

La app utiliza dos mecanismos de almacenamiento local:

| Mecanismo | Uso | Cifrado |
|-----------|-----|---------|
| `FlutterSecureStorage` | Credenciales de Home Assistant | Sí (DPAPI / Keychain) |
| `SharedPreferences` | Orden y áreas de luces, orden de dispositivos | No |

---

## FlutterSecureStorage — Credenciales

**Librería:** `flutter_secure_storage ^9.2.2`  
**Archivo:** `lib/features/auth/services/ha_connection_service.dart`

### Claves almacenadas

| Clave | Tipo | Descripción |
|-------|------|-------------|
| `ha_url` | String | URL base de la instancia de Home Assistant (sin barra final) |
| `ha_token` | String | Long-Lived Access Token |

### Configuración por plataforma

| Plataforma | Configuración | Mecanismo |
|------------|--------------|-----------|
| Windows | `WindowsOptions(useBackwardCompatibility: false)` | DPAPI |
| Android | Por defecto | EncryptedSharedPreferences |
| iOS | Por defecto | Keychain |

### Operaciones

| Método | Operación |
|--------|-----------|
| `login(url, token)` | Escribe ambas claves tras validar contra HA |
| `logout()` | Elimina ambas claves |
| `isLoggedIn()` | Verifica que ambas claves existan y no estén vacías |
| `getCredentials()` | Lee ambas claves y devuelve `HaCredentials?` |

---

## SharedPreferences — Preferencias de luces y dispositivos

**Librería:** `shared_preferences ^2.5.5`

### ⚠️ Importante: Dos sistemas de persistencia paralelos

Existen dos sistemas de persistencia de orden **independientes** que no comparten datos:

| Sistema | Pantalla | Claves |
|---------|----------|--------|
| **HaStatesController** | `LightsScreen` | `lights_order`, `lights_area` |
| **DeviceOrderService** | `DevicesScreen` | `device_order_v1` |

---

### Sistema 1 — HaStatesController (LightsScreen)

**Archivo:** `lib/features/home_assistant/state/ha_states_controller.dart`

#### `lights_order` — Orden de luces

| Clave | `lights_order` |
|-------|-----------------|
| Tipo | `List<String>` |
| Contenido | Lista de `entity_id` en el orden personalizado |
| Cuándo se guarda | Al reordenar luces con drag & drop en `LightsScreen` |
| Cuándo se lee | Al cargar `haStatesProvider` (inicio o refresh) |

**Lógica de ordenamiento:**
- Las luces con `entity_id` en la lista se ordenan por su posición en la lista.
- Las luces nuevas (no en la lista) se colocan al final.

#### `lights_area` — Área de cada luz

| Clave | `lights_area` |
|-------|----------------|
| Tipo | `String` (JSON serializado) |
| Formato | `{ "entity_id_1": "CASA GIOVANNI", "entity_id_2": "TENDA OFICINA" }` |
| Cuándo se guarda | Al asignar una luz a un área con el menú ⋮ |
| Cuándo se lee | Al cargar `haStatesProvider` (inicio o refresh) |

**Áreas disponibles:** `"TODAS"`, `"CASA GIOVANNI"`, `"TENDA OFICINA"`  
**Valor por defecto:** `"TODAS"` (si el `entity_id` no está en el mapa)

---

### Sistema 2 — DeviceOrderService (DevicesScreen)

**Archivo:** `lib/services/device_order/device_order_service.dart`  
**Clase de implementación:** `SharedPrefsDeviceOrderService`

#### `device_order_v1` — Orden de dispositivos por habitación

| Clave | `device_order_v1` |
|-------|---------------------|
| Tipo | `String` (JSON serializado) |
| Formato | `{ "entity_id_1": 0, "entity_id_2": 1, "entity_id_3": 2 }` |
| Cuándo se guarda | Al reordenar dispositivos con drag & drop en `DevicesScreen` |
| Cuándo se lee | Al cargar `devicesProvider` (inicio o refresh) |

El mapa es global (no separado por habitación). Los índices son posiciones relativas dentro de cada habitación.

**Lógica de ordenamiento:**
- Dispositivos con entrada en el mapa → ordenados por `sortIndex` ascendente.
- Dispositivos sin entrada → al final, en el orden original de HA.

> **TODO en el código:** Se planea migrar este almacenamiento a un backend cuando exista soporte multi-tenant.

---

## Datos que NO se persisten

| Dato | Motivo |
|------|--------|
| Historial de conversaciones con el agente | No implementado aún |
| Estado `on/off` de dispositivos | Siempre proviene de HA en tiempo real |
| Nombre del usuario | Proviene de la entidad `person` de HA en tiempo real |
| Sesión del agente n8n (`session_id`) | Se genera nuevo en cada arranque de la app |
