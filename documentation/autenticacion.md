# Autenticación

## Mecanismo

La app se autentica con Home Assistant mediante un **Long-Lived Access Token**. Este es un token de larga duración generado en el perfil de usuario de Home Assistant.

> **Nota:** Este es un enfoque de PoC (Proof of Concept). No implementa el flujo OAuth2 completo que Home Assistant también soporta.

---

## Almacenamiento de credenciales

Las credenciales se almacenan usando `flutter_secure_storage`:

| Plataforma | Mecanismo de cifrado |
|------------|---------------------|
| Windows | DPAPI (Data Protection API) |
| Android | EncryptedSharedPreferences |
| iOS | Keychain |

**Claves de storage:**

| Clave | Valor almacenado |
|-------|-----------------|
| `ha_url` | URL base de la instancia HA (sin barra final) |
| `ha_token` | Long-Lived Access Token |

---

## Flujo de autenticación

### Login (primera vez o reconfiguración)

```
Usuario abre la app
        │
        ▼
_AuthNotifier._init() lee SecureStorage de forma asíncrona
        │
        ├─ Credenciales ausentes ──► Redirige a /login
        │
        └─ Credenciales presentes ──► Redirige a /
```

### Proceso de validación en /login

```
Usuario ingresa URL + Token → toca "PROBAR CONEXIÓN"
        │
        ▼
HaConnectionService.login(url, token)
        │
        ├─ Normaliza URL (elimina barra final)
        │
        ▼
GET {url}/api/
Headers: { Authorization: Bearer {token}, Content-Type: application/json }
Timeout: 10 segundos
        │
        ├─ TimeoutException      ──► ConnectionException("Tiempo de espera agotado.")
        ├─ SocketException       ──► ConnectionException("Error de red...")
        ├─ HTTP 401 / 403        ──► InvalidCredentialsException("Credenciales inválidas")
        ├─ HTTP ≠ 200            ──► ConnectionException("Respuesta inesperada (XXX)")
        ├─ body["message"] ≠ "API running." ──► InvalidCredentialsException
        │
        └─ HTTP 200 + body correcto
                │
                ▼
        Guarda url y token en FlutterSecureStorage
                │
                ▼
        context.go('/') ──► _AuthNotifier.refresh() ──► GoRouter redirige a HomeScreen
```

### Guard de autenticación (GoRouter)

El componente `_AuthNotifier` actúa como `refreshListenable` del router:

```dart
redirect: (context, state) {
  if (!authNotifier.initialized) return null;  // Espera hasta leer SecureStorage

  final loggedIn = authNotifier.loggedIn;
  final isLoginRoute = state.uri.toString() == '/login';

  if (!loggedIn && !isLoginRoute) return '/login';
  if (loggedIn && isLoginRoute) return '/';
  return null;
}
```

> **Limitación conocida:** `isLoggedIn()` verifica que las claves existan en storage, pero **no revalida el token contra Home Assistant** al arrancar la app. Si el token fue revocado, la app mostrará la pantalla principal pero todas las llamadas a la API fallarán con errores de red/auth.

---

## Logout

```dart
HaConnectionService.logout()
// Elimina ha_url y ha_token de SecureStorage
```

> **Nota:** El botón de settings (ícono de engranaje en HomeScreen) navega a `/login` usando `context.push('/login')`, lo que permite reconfigurar las credenciales.

---

## Excepciones

| Excepción | Cuándo se lanza |
|-----------|----------------|
| `ConnectionException` | Error de red (timeout, host inalcanzable, respuesta inesperada) |
| `InvalidCredentialsException` | Token rechazado (HTTP 401/403) o URL inválida |

Ambas extienden `Exception` y tienen un campo `message` con texto en español para mostrar al usuario.

---

## Modelo de dominio

```dart
class HaCredentials {
  final String url;    // URL base, ej: "http://homeassistant.local:8123"
  final String token;  // Long-Lived Access Token
}
```

Disponible reactivamente via `haCredentialsProvider` (`FutureProvider<HaCredentials?>`).
