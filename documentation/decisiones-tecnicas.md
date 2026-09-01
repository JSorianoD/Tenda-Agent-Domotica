# Decisiones Técnicas

Este documento registra las decisiones de arquitectura relevantes del proyecto, con su contexto, justificación y estado actual.

---

## DT-01 — Modo oscuro forzado

**¿Qué se decidió?**  
La app siempre usa `ThemeMode.dark`. No hay opción de modo claro ni toggle de tema.

**Contexto:**  
La identidad de marca Tenda (negro/dorado 60-30-10) pierde impacto visual sobre fondos claros. La app está diseñada para verse en entornos de uso domótico donde el fondo oscuro es preferible.

**Decisión adoptada:**  
`themeMode: ThemeMode.dark` permanente en `MaterialApp.router`.

**Evidencia en el código:**  
`main.dart`: `themeMode: ThemeMode.dark, // Forzado: la marca pierde fuerza sobre fondo claro`

**Estado:** ✅ ACTUAL

---

## DT-02 — Autenticación mediante Long-Lived Access Token

**¿Qué se decidió?**  
Se usa un Long-Lived Access Token en lugar del flujo OAuth2 de Home Assistant.

**Contexto:**  
Home Assistant soporta OAuth2 Authorization Code Flow, pero requiere registrar un cliente y manejar el flujo de redirección. Para el alcance actual (PoC), el token de larga duración es más simple.

**Decisión adoptada:**  
Long-Lived Access Token almacenado en `FlutterSecureStorage`.

**Alternativas:**  
OAuth2 Authorization Code Flow con PKCE.

**Justificación:**  
Docstring en `ha_connection_service.dart`: "Uses a Long-Lived Access Token (PoC approach)."

**Limitación conocida:**  
La app no revalida el token al arrancar. Si el token expira o es revocado, la app muestra la pantalla principal pero todas las llamadas a HA fallan.

**Estado:** ✅ ACTUAL (apropiado para PoC, revisar para producción)

---

## DT-03 — Interfaz HomeConnector para desacoplar el backend de domótica

**¿Qué se decidió?**  
Crear la interfaz abstracta `HomeConnector` para separar la lógica de UI y state de la implementación concreta del backend de domótica.

**Contexto:**  
Durante el desarrollo inicial se necesitaba construir la UI y los controllers sin depender de una instancia real de Home Assistant.

**Decisión adoptada:**  
`HomeConnector` como interfaz; `MockHomeConnector` para desarrollo y `HaHomeConnector` para producción. El proveedor activo es configurable simplemente cambiando `homeConnectorProvider`.

**Implementación activa:**  
`HaHomeConnector` (`lib/services/home_connector/ha_home_connector.dart`)

**Estado:** ✅ ACTUAL

> **Nota:** El comentario en `home_connector.dart` dice "Today this is implemented by [MockHomeConnector]" — este comentario está **desactualizado**. `HaHomeConnector` ya es la implementación activa.

---

## DT-04 — Actualizaciones optimistas (optimistic updates)

**¿Qué se decidió?**  
Los toggles de dispositivos y luces se reflejan inmediatamente en la UI antes de que Home Assistant confirme el cambio.

**Contexto:**  
Las llamadas a la API REST de HA tienen latencia de red variable. Esperar la respuesta bloquea la UI y la hace sentir lenta, especialmente en redes locales lentas o WiFi con congestión.

**Decisión adoptada:**  
Optimistic update inmediato + rollback si la llamada a HA falla.

**Patrón:**
```
1. Flip inmediato en estado local (optimistic)
2. Marcar dispositivo como "loading" (prevenir double-tap)
3. Llamada async a HA
   ├─ Éxito → confirmar con el estado real devuelto por HA
   └─ Error  → revertir el flip + mostrar SnackBar de error
```

**Implementaciones:**  
`DevicesController.toggleDevice()` y `HaStatesController.toggleLight()`

**Estado:** ✅ ACTUAL

---

## DT-05 — SliverReorderableList para evitar conflictos de gestos

**¿Qué se decidió?**  
`DevicesScreen` usa un único `CustomScrollView` con `SliverReorderableList` por habitación, en lugar de un `ListView` con `ReorderableListView` anidados.

**Contexto:**  
Al anidar un `ReorderableListView` dentro de un `ListView`, el scroll externo intercepta los gestos verticales antes de que la lista interna pueda detectar el inicio del drag. Esto hace que sea imposible reordenar elementos.

**Decisión adoptada:**  
Toda la pantalla es un único `CustomScrollView` con Slivers. Cada habitación es un `SliverReorderableList` separado.

**Referencia en el código:**  
Comentario en `devices_screen.dart` líneas 13-16.

**Estado:** ✅ ACTUAL

---

## DT-06 — NeverScrollableScrollPhysics en TabBarView (LightsScreen)

**¿Qué se decidió?**  
El `TabBarView` de `LightsScreen` tiene `physics: NeverScrollableScrollPhysics()`.

**Contexto:**  
El `ReorderableListView` dentro de cada tab requiere gestos verticales para reordenar. El gesto de deslizamiento horizontal del `TabBarView` puede activarse accidentalmente durante un drag vertical, cambiando de tab en lugar de reordenar.

**Decisión adoptada:**  
Desactivar el scroll horizontal del `TabBarView`. El cambio de tab solo es posible tocando el tab directamente.

**Referencia en el código:**  
Comentario en `lights_screen.dart` líneas 120-122.

**Estado:** ✅ ACTUAL

---

## DT-07 — GoRouter + ChangeNotifier para guard de autenticación async

**¿Qué se decidió?**  
Usar `_AuthNotifier extends ChangeNotifier` como `refreshListenable` de GoRouter para el guard de autenticación.

**Contexto:**  
`GoRouter.redirect` espera una función síncrona que devuelva `String?`. La lectura de `FlutterSecureStorage` es asíncrona y no puede llamarse directamente dentro de `redirect`.

**Decisión adoptada:**  
`_AuthNotifier` lee las credenciales de forma asíncrona en su constructor (`_init()`), actualiza el estado `_loggedIn` sincrónicamente y llama a `notifyListeners()`. GoRouter escucha estas notificaciones via `refreshListenable` y re-evalúa las redirecciones.

**Referencia en el código:**  
Comentarios en `app_router.dart` líneas 13-15.

**Estado:** ✅ ACTUAL

---

## DT-08 — Cuatro AnimationControllers independientes en el orbe

**¿Qué se decidió?**  
`JarvisCoreWidget` usa cuatro `AnimationController` independientes, uno por cada estado del orbe (`idle`, `listening`, `processing`, `responding`).

**Contexto:**  
El orbe tiene cuatro animaciones distintas con duraciones y comportamientos diferentes. Reutilizar un solo controller requeriría reinicializarlo en cada cambio de estado, provocando saltos visuales. Además, correr todos los controllers simultáneamente desperdiciaría CPU/batería.

**Decisión adoptada:**  
Cuatro controllers independientes. Al cambiar de estado, todos se detienen y solo el del estado activo se activa.

**Estado:** ✅ ACTUAL

---

## Decisiones pendientes / TODOs identificados

| Referencia | Descripción | Estado |
|------------|-------------|--------|
| `jarvis_core_controller.dart:70` | `cycleState()` es solo para testing visual, debe reemplazarse con eventos reales | PENDIENTE |
| `device_order_service.dart:11` | Migrar orden de dispositivos a backend cuando exista soporte multi-tenant | PENDIENTE |
| `n8n_agent_service.dart:10` | URL del webhook hardcodeada — mover a configuración externa | PENDIENTE |
| `ha_connection_service.dart` | Revalidar token al arrancar la app (no solo al login) | PENDIENTE |
