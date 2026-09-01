# Documentación — Tenda Agent Domotica · Jarvis Home Assistant

Bienvenido a la documentación técnica oficial del proyecto. Está dirigida a:

- **Nuevos desarrolladores** que necesiten comprender y contribuir al proyecto.
- **Desarrolladores actuales** que necesiten consultar detalles técnicos.
- **Líderes técnicos** que necesiten evaluar la arquitectura.
- **Personas no técnicas** que necesiten entender el funcionamiento general.

---

## Índice de documentos

| Documento | Descripción |
|-----------|-------------|
| [instalacion.md](instalacion.md) | Requisitos, entorno de desarrollo y primer arranque |
| [arquitectura.md](arquitectura.md) | Estructura del proyecto, capas y patrón de features |
| [autenticacion.md](autenticacion.md) | Flujo de autenticación con Home Assistant |
| [configuracion.md](configuracion.md) | Cómo configurar la instancia de Home Assistant |
| [home-assistant.md](home-assistant.md) | Integración con la API REST de Home Assistant |
| [agente-voz.md](agente-voz.md) | Agente de IA, flujo de voz e integración con n8n |
| [pantallas.md](pantallas.md) | Descripción de cada pantalla y cómo navegar entre ellas |
| [persistencia.md](persistencia.md) | Datos que se guardan localmente y cómo se almacenan |
| [diseno.md](diseno.md) | Sistema de diseño Tenda: paleta, tipografía y tema |
| [decisiones-tecnicas.md](decisiones-tecnicas.md) | Decisiones de arquitectura y sus justificaciones |
| [troubleshooting.md](troubleshooting.md) | Problemas conocidos y sus soluciones |

---

## Resumen del sistema

**Jarvis Home Assistant** es una aplicación Flutter desarrollada bajo la marca **Tenda** que funciona como interfaz de control domótico inteligente. El sistema integra dos componentes externos:

1. **Home Assistant** — plataforma open-source de automatización del hogar que expone una API REST para controlar dispositivos (luces, sensores, cámaras, clima).
2. **n8n** — plataforma de automatización que aloja el agente de inteligencia artificial. La app envía comandos de voz o texto al agente y reproduce la respuesta en audio y texto.

La app permite al usuario:

- Conectar y autenticarse con su instancia de Home Assistant.
- Visualizar y controlar luces y dispositivos del hogar.
- Consultar el estado del clima y sensores ambientales.
- Monitorear cámaras y sensores de seguridad.
- Interactuar con el agente de IA por voz o texto.

---

## Stack tecnológico

| Componente | Tecnología | Versión mínima |
|------------|------------|----------------|
| Framework | Flutter / Dart | SDK `^3.12.0` |
| Estado global | flutter_riverpod | `^2.6.1` |
| Navegación | go_router | `^14.8.1` |
| Tipografía | google_fonts (Rajdhani) | `^6.2.1` |
| HTTP | http | `^1.6.0` |
| Almacenamiento seguro | flutter_secure_storage | `^9.2.2` |
| Preferencias locales | shared_preferences | `^2.5.5` |
| Grabación de audio | record | `^6.0.0` |
| Reproducción de audio | audioplayers | `^6.1.0` |
| Rutas temporales | path_provider | `^2.1.4` |
| Identificadores únicos | uuid | `^4.5.1` |
