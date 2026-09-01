# Tenda Agent Domotica — Jarvis Home Assistant

Aplicación Flutter de control domótico inteligente desarrollada bajo la marca **Tenda**.

Integra **Home Assistant** para el control de dispositivos del hogar y un agente de IA basado en **n8n** para interacción por voz y texto.

---

## Funcionalidades principales

- Autenticación segura con Home Assistant mediante Long-Lived Access Token
- Control de luces y dispositivos con actualizaciones en tiempo real
- Visualización de clima y sensores ambientales
- Monitoreo de cámaras y sensores de seguridad
- Interacción con agente de IA por voz (grabación WAV) o texto
- Orbe animado con cuatro estados visuales (idle / listening / processing / responding)

---

## Documentación técnica

La documentación completa del proyecto está en la carpeta [`documentation/`](documentation/):

| Documento | Descripción |
|-----------|-------------|
| [Instalación](documentation/instalacion.md) | Requisitos y primer arranque |
| [Arquitectura](documentation/arquitectura.md) | Estructura del proyecto y capas |
| [Autenticación](documentation/autenticacion.md) | Flujo de login con Home Assistant |
| [Configuración](documentation/configuracion.md) | Cómo obtener URL y token de HA |
| [Home Assistant](documentation/home-assistant.md) | Endpoints y modelos de entidad |
| [Agente de voz](documentation/agente-voz.md) | Flujo de voz e integración con n8n |
| [Pantallas](documentation/pantallas.md) | Descripción de cada pantalla |
| [Persistencia](documentation/persistencia.md) | Datos locales y cómo se almacenan |
| [Diseño](documentation/diseno.md) | Sistema de diseño Tenda |
| [Decisiones técnicas](documentation/decisiones-tecnicas.md) | Justificaciones de arquitectura |
| [Troubleshooting](documentation/troubleshooting.md) | Problemas conocidos y soluciones |

---

## Inicio rápido

```bash
# Instalar dependencias
flutter pub get

# Ejecutar la aplicación
flutter run
```

Al primer arranque, la app solicitará la URL de tu instancia de Home Assistant y un Long-Lived Access Token. Consulta [documentation/configuracion.md](documentation/configuracion.md) para los pasos detallados.

---

## Stack

| Tecnología | Uso |
|------------|-----|
| Flutter / Dart (SDK `^3.12.0`) | Framework principal |
| flutter_riverpod | Gestión de estado |
| go_router | Navegación |
| flutter_secure_storage | Credenciales cifradas |
| shared_preferences | Preferencias locales |
| record + audioplayers | Grabación y reproducción de audio |
| http | Comunicación con HA y n8n |
