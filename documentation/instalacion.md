# Instalación y Configuración del Entorno

## Requisitos previos

### Flutter y Dart

| Requisito | Versión mínima |
|-----------|----------------|
| Dart SDK | `^3.12.0` |
| Flutter SDK | Compatible con Dart 3.12 (canal stable) |

Verifica tu instalación actual:

```bash
flutter --version
dart --version
```

Si necesitas instalar o actualizar Flutter, sigue la guía oficial:
https://docs.flutter.dev/get-started/install

### Plataformas soportadas

El proyecto incluye scaffolding para las siguientes plataformas:

- Android
- iOS
- Web
- Windows
- macOS
- Linux

> **Nota:** Consulta con el equipo cuál es la plataforma objetivo principal antes de configurar el entorno.

---

## Obtener el proyecto

```bash
git clone https://github.com/JSorianoD/Tenda-Agent-Domotica.git
cd Tenda-Agent-Domotica
```

---

## Instalar dependencias

```bash
flutter pub get
```

Este comando descarga todos los paquetes declarados en `pubspec.yaml`.

---

## Verificar el entorno

```bash
flutter doctor
```

Resuelve cualquier error que reporte `flutter doctor` antes de continuar.

---

## Ejecutar la aplicación

```bash
# Android (con dispositivo o emulador conectado)
flutter run

# Windows (desde Windows)
flutter run -d windows

# Web
flutter run -d chrome

# Con un dispositivo específico
flutter devices        # listar dispositivos disponibles
flutter run -d <id>    # ejecutar en el dispositivo elegido
```

---

## Primer uso

Al abrir la aplicación por primera vez aparecerá la **pantalla de configuración de Home Assistant**. Deberás ingresar:

1. La URL de tu instancia de Home Assistant (ej: `http://homeassistant.local:8123`)
2. Un Long-Lived Access Token generado en tu perfil de usuario de Home Assistant

Consulta [configuracion.md](configuracion.md) para los pasos detallados.

---

## Notas sobre dependencias nativas

Algunas dependencias requieren configuración adicional por plataforma:

| Dependencia | Plataforma | Requisito |
|-------------|------------|-----------|
| `record` | Android | Permiso `RECORD_AUDIO` en AndroidManifest.xml |
| `record` | iOS | `NSMicrophoneUsageDescription` en Info.plist |
| `flutter_secure_storage` | Windows | Sin configuración extra (DPAPI) |
| `audioplayers` | Windows | Visual C++ Redistributable |

Para configuración específica por plataforma, consulta la documentación oficial de cada paquete en pub.dev.
