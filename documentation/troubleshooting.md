# Troubleshooting

Esta sección documenta los problemas conocidos, sus causas raíz y las soluciones que se han aplicado. Tiene valor especial para mantenimiento y para entender por qué ciertas partes del código están escritas de una forma aparentemente inusual.

---

## Problema 1 — Los switches aparecen en cian en lugar de dorado

**Síntoma:**  
Los widgets `Switch()` muestran un color cian (azulado) en lugar del dorado Tenda.

**Causa raíz:**  
Sin el bloque `switchTheme` configurado en el `ThemeData`, Flutter usa el color `primary` del `ColorScheme` para el thumb del switch activo. En versiones anteriores del proyecto, el acento era cian. Aunque el acento fue migrado a dorado, widgets que dependen implícitamente del tema pueden seguir mostrando el color incorrecto si no se configura explícitamente.

**Solución aplicada:**  
Se agrega `switchTheme` explícito en `buildTendaTheme()`:

```dart
switchTheme: SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? AppColors.tendaGold
        : AppColors.tendaGrayMuted,
  ),
  trackColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.selected)
        ? AppColors.tendaGold.withValues(alpha: 0.4)
        : AppColors.tendaInputBackground,
  ),
  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
),
```

**Archivo:** `lib/core/theme/app_theme.dart`

**Prevención:**  
Si aparece cualquier widget con un color inesperado que parece ser el color primario del tema, revisar si el widget hereda implícitamente del `ColorScheme`. Agregar el tema específico del widget en `buildTendaTheme()` en lugar de sobrescribir el color en cada instancia del widget.

---

## Problema 2 — Imposible reordenar dispositivos (drag capturado por scroll)

**Síntoma:**  
En la pantalla de Iluminación (`DevicesScreen`), al intentar arrastrar un dispositivo para reordenarlo, el gesto es interceptado por el scroll de la lista contenedora y el item no se arrastra.

**Causa raíz:**  
Al usar `ListView` con `ReorderableListView` anidados, el scroll externo intercepta los gestos verticales antes de que la lista interna pueda reconocer el inicio del drag. Es una limitación del árbol de gestos de Flutter.

**Solución aplicada:**  
Se reescribe `DevicesScreen` para usar un único `CustomScrollView` con `SliverReorderableList` por habitación (en lugar de listas anidadas). Al estar todo en el mismo `CustomScrollView`, no hay conflicto de jurisdicción de gestos.

**Archivo:** `lib/features/devices/presentation/devices_screen.dart`

**Referencia:** Comentario en `devices_screen.dart` líneas 13-16.

---

## Problema 3 — Cambio de tab al intentar reordenar luces (LightsScreen)

**Síntoma:**  
En la pantalla de Luces (`LightsScreen`), al intentar arrastrar una luz para reordenarla, la app cambia de tab (TODAS / CASA GIOVANNI / TENDA OFICINA) en lugar de reordenar.

**Causa raíz:**  
El `TabBarView` tiene scroll horizontal habilitado por defecto. Un drag que comienza verticalmente pero con una componente horizontal mínima puede ser interpretado como un deslizamiento de tab.

**Solución aplicada:**  
Se desactiva el scroll horizontal del `TabBarView`:

```dart
TabBarView(
  physics: const NeverScrollableScrollPhysics(),
  ...
)
```

**Archivo:** `lib/features/jarvis_core/presentation/lights_screen.dart`

**Impacto:** El cambio de tab solo puede hacerse tocando directamente el tab en el `AppBar`, no deslizando.

---

## Problema 4 — GoRouter redirect no acepta funciones asíncronas

**Síntoma:**  
Necesidad de leer credenciales de `FlutterSecureStorage` (operación async) para decidir si redirigir al login. `GoRouter.redirect` no acepta `async` directamente porque espera `String?` (no `Future<String?>`).

**Causa raíz:**  
Limitación de la API de GoRouter: la función `redirect` debe ser síncrona.

**Solución aplicada:**  
Se introduce `_AuthNotifier extends ChangeNotifier`:
1. En su constructor, llama a `_init()` async que lee `FlutterSecureStorage` y actualiza `_loggedIn`.
2. Al terminar la lectura, llama a `notifyListeners()`.
3. GoRouter escucha estas notificaciones via `refreshListenable: authNotifier`.
4. Mientras `_initialized == false`, el redirect devuelve `null` (no redirige).

**Archivo:** `lib/core/router/app_router.dart`

---

## Problema 5 — El token de HA expira pero la app no redirige al login

**Síntoma:**  
Si el Long-Lived Access Token de Home Assistant es revocado o expira, la app muestra la pantalla principal (`HomeScreen`) pero todas las llamadas a la API fallan con errores.

**Causa raíz:**  
`isLoggedIn()` solo verifica que las claves `ha_url` y `ha_token` existan en `FlutterSecureStorage`. No revalida el token contra la API de HA.

**Estado:** ⚠️ PENDIENTE DE SOLUCIÓN

**Solución temporal:**  
Los errores de llamadas a HA se muestran como `SnackBar` o en el estado de la UI (`connectionError`). El usuario puede tocar el ícono de configuración para volver a la pantalla de login y reconfigurar el token.

**Solución definitiva sugerida:**  
Agregar una llamada a `HaApiService.ping()` en `_AuthNotifier._init()` y tratar el token como inválido si `ping()` falla con 401/403.

---

## Problema 6 — LightsScreen y DevicesScreen con sistemas de persistencia desconectados

**Síntoma:**  
El orden personalizado de luces en `LightsScreen` y el de `DevicesScreen` son independientes. Cambiar el orden en una pantalla no afecta a la otra.

**Causa raíz:**  
Existen dos sistemas de persistencia paralelos:
- `HaStatesController` usa `lights_order` / `lights_area` en `SharedPreferences`
- `DevicesController` usa `DeviceOrderService` con la clave `device_order_v1`

**Estado:** ⚠️ DOCUMENTADO — por definir si ambas pantallas deben coexistir

**Solución sugerida:**  
Definir con el equipo si `LightsScreen` y `DevicesScreen` son complementarias o si una reemplaza a la otra, y unificar la persistencia.

---

## Diagnóstico rápido

| Síntoma | Área a revisar |
|---------|---------------|
| Pantalla en blanco al abrir la app | `_AuthNotifier._init()` — posible error leyendo `FlutterSecureStorage` |
| No redirige a `/login` con credenciales inválidas | `isLoggedIn()` — no revalida contra HA |
| Switch con color inesperado | `buildTendaTheme()` — revisar `switchTheme` |
| Drag no funciona en listas | Revisar arquitectura de `CustomScrollView` vs. listas anidadas |
| Error "No se encontraron credenciales" en cualquier pantalla | El token o URL fue eliminado de `FlutterSecureStorage` — cerrar y abrir la app |
| El agente no responde | Verificar conectividad con el webhook de n8n y que la URL hardcodeada sea correcta |
| Luces no aparecen en LightsScreen | Verificar que la instancia de HA tenga entidades de dominio `light` |
| Luces no aparecen en DevicesScreen | Verificar que la instancia de HA tenga entidades `light` o `switch` |
