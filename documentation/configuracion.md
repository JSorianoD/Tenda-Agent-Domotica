# Configuración de Home Assistant

## Requisitos

Para conectar la aplicación necesitas:

1. Una instancia de **Home Assistant** en funcionamiento, accesible desde la red del dispositivo donde corre la app.
2. Un **Long-Lived Access Token** generado en el perfil de usuario de HA.

---

## Cómo obtener la URL de tu instancia

La URL depende de cómo está instalado Home Assistant:

| Tipo de instalación | URL típica |
|--------------------|------------|
| Red local (HTTP) | `http://homeassistant.local:8123` |
| Red local (IP directa) | `http://192.168.x.x:8123` |
| Acceso remoto (HTTPS) | `https://tu-dominio.duckdns.org` |

> **Importante:** La URL no debe terminar con `/`. La app la normaliza automáticamente.

Para verificar que la URL es correcta, abre en un navegador:
`http://tu-url/api/`

Deberías ver:
```json
{"message": "API running."}
```

---

## Cómo generar un Long-Lived Access Token

1. Abre Home Assistant en tu navegador.
2. Ve a tu perfil de usuario (ícono de usuario en la esquina inferior izquierda).
3. Desplázate hasta la sección **Long-Lived Access Tokens**.
4. Haz clic en **Create Token**.
5. Asigna un nombre descriptivo (ej: `jarvis-app`).
6. Copia el token generado — **solo se muestra una vez**.

---

## Conectar la app

1. Abre la app. Si es la primera vez, aparecerá automáticamente la pantalla de configuración.
2. Ingresa la URL de tu instancia en el campo **URL de Home Assistant**.
3. Ingresa el token en el campo **Token de acceso (Long-Lived)**.
4. Toca **PROBAR CONEXIÓN**.
5. Si la conexión es exitosa, la app navegará a la pantalla principal.

Si quieres cambiar la configuración más tarde, toca el ícono de engranaje (⚙) en la esquina superior derecha de la pantalla principal.

---

## Entidades reconocidas por la app

La app lee todas las entidades de tu instancia HA y las clasifica automáticamente:

| Dominio HA | Aparece en |
|------------|-----------|
| `person` | Barra de estado (nombre y ubicación del usuario) |
| `light` | Pantalla de Luces, Pantalla de Iluminación |
| `switch` | Pantalla de Iluminación (tratados como luces) |
| `weather` | Pantalla de Clima |
| `sensor` (temperatura / humedad) | Pantalla de Clima |
| `sensor` (otros) | Internamente disponible |
| `camera` | Pantalla de Seguridad |
| `alarm_control_panel` | Pantalla de Seguridad |
| `binary_sensor` (door / window / motion) | Pantalla de Seguridad |
| `scene` | Internamente disponible |

---

## Áreas de luces (configuración en la app)

La pantalla de Luces permite organizar las luces en dos áreas personalizadas además de "TODAS":

- **TODAS** — todas las luces
- **CASA GIOVANNI** — área personalizable (nombre fijo en la versión actual)
- **TENDA OFICINA** — área personalizable (nombre fijo en la versión actual)

Para mover una luz a un área, toca el menú `⋮` (tres puntos) junto a la luz y selecciona el área destino.

> **Nota técnica:** Los nombres de las áreas están definidos en el código fuente (`lights_screen.dart`). En una versión futura podrían ser configurables por el usuario.

---

## Imágenes de cámara

La pantalla de Seguridad muestra imágenes de cámaras usando el `entity_picture` que provee HA. Las imágenes se cargan directamente desde la instancia de HA con el token de autenticación como header.

Si la imagen no carga, la app muestra un ícono de "señal no disponible".
