# Sistema de Diseño Tenda

## Principios de diseño

El sistema de diseño sigue la regla **60-30-10**:

| Proporción | Color | Rol |
|------------|-------|-----|
| 60% | Negro profundo (#0A0A0A) | Fondo principal |
| 30% | Superficies (#111111 / #1A1A1A) | Cards, inputs, contenedores |
| 10% | Dorado (#C9A227) | Acento, CTA, iconos activos |

El modo oscuro es **permanente** — no hay opción de modo claro. Decisión de marca: la identidad Tenda pierde fuerza sobre fondos claros.

---

## Paleta de colores

Todos los colores están definidos en `lib/core/theme/app_colors.dart` como constantes de la clase `AppColors`.

### Colores de marca (fuente de verdad)

| Constante | Valor hex | Uso |
|-----------|-----------|-----|
| `tendaDeepBlack` | `#0A0A0A` | Fondo del Scaffold principal |
| `tendaGold` | `#C9A227` | Acento primario: CTA, foco, iconos activos |
| `tendaGoldLight` | `#E0C463` | Hover states, gradientes |
| `tendaWhite` | `#FFFFFF` | Texto principal sobre fondos oscuros |
| `tendaGrayMuted` | `#8A8A8A` | Texto secundario, placeholders |
| `tendaInputBackground` | `#1A1A1A` | Fondo de campos de texto |

### Alias semánticos (usar en widgets)

| Constante | Valor | Uso semántico |
|-----------|-------|---------------|
| `background` | `tendaDeepBlack` | Fondo del Scaffold |
| `surface` | `#111111` | Cards, AppBar |
| `surfaceLight` | `#1A1A1A` | Contenedores anidados |
| `accent` | `tendaGold` | CTA, iconos activos, highlights |
| `accentDim` | `#6B5100` | Track del switch activo |
| `textPrimary` | `tendaWhite` | Texto principal |
| `textSecondary` | `#8A94A6` | Texto secundario |
| `textMuted` | `#4A5568` | Texto apagado / desactivado |
| `divider` | `#222222` | Líneas divisoras |
| `error` | `#FF5252` | Errores, estados destructivos |

### Tokens deprecated (no usar en código nuevo)

| Constante | Alias de | Motivo |
|-----------|----------|--------|
| `cyan` | `tendaGold` | El acento original era cian; migrado a dorado |
| `cyanDim` | `accentDim` | Ídem |
| `cyanGlow` | `accentDim` | Ídem |

> Estos tokens siguen en el código por compatibilidad con los painters del orbe. No deben usarse en nuevas pantallas.

---

## Tipografía

**Fuente principal:** Rajdhani (Google Fonts)

Cargada mediante `GoogleFonts.rajdhaniTextTheme()` aplicado globalmente en el `ThemeData`.

### Estilos del tema base

El tema extiende `ThemeData.dark()` y aplica Rajdhani a todo el `textTheme`. Los colores de cuerpo y display quedan en `tendaWhite`.

| Estilo | Uso típico |
|--------|-----------|
| `titleLarge` | Títulos de pantalla, logo |
| `titleMedium` | Saludos, nombres de usuario, reloj |
| `headlineSmall` | Título de DevicesScreen |
| `bodyMedium` | Texto general, subtítulos del orbe |
| `bodySmall` | Labels del dock, hints, metadatos |

---

## Tema global: `buildTendaTheme()`

Función en `lib/core/theme/app_theme.dart`.

> `buildAppTheme()` es un alias de compatibilidad que apunta a `buildTendaTheme()`. Usar `buildTendaTheme()` en código nuevo.

### Componentes configurados en el tema

| Componente | Configuración |
|------------|--------------|
| `scaffoldBackgroundColor` | `tendaDeepBlack` |
| `ColorScheme.dark` | Primary: `tendaGold`, Surface: `#111111`, Error: `#FF5252` |
| `switchTheme` | Thumb dorado activo, gris inactivo; sin outline |
| `iconTheme` | `tendaWhite` por defecto |
| `dividerTheme` | Blanco al 15% |
| `inputDecorationTheme` | Fondo `#1A1A1A`, línea inferior, foco en dorado |
| `elevatedButtonTheme` | Fondo dorado, texto negro, border radius 12px, Rajdhani Bold 700 |
| `appBarTheme` | Transparente, sin elevación, Rajdhani, letterSpacing 4 |
| `cardColor` | `#111111` |

### Por qué se define `switchTheme` explícitamente

Sin el bloque `switchTheme`, cualquier `Switch()` hereda el color `primary` del `ColorScheme`. Esto causó el problema histórico donde los switches aparecían en el color del acento anterior (cian). Definirlo explícitamente garantiza que todos los switches nuevos hereden automáticamente el dorado Tenda sin necesidad de especificarlo en cada widget.

---

## Reglas de uso

1. **Nunca usar literales de color** (`Color(0xFF...)` o `Colors.red`) directamente en widgets. Siempre usar `AppColors.*`.
2. **Usar los alias semánticos**, no los colores de marca directamente (ej: usar `AppColors.background`, no `AppColors.tendaDeepBlack`).
3. **No usar tokens deprecated** (`cyan`, `cyanDim`, `cyanGlow`) en código nuevo.
4. **No agregar `colorScheme.primary`** directamente en widgets — confiar en el tema global.

---

## Assets de marca

| Archivo | Ruta | Uso |
|---------|------|-----|
| Logo completo | `assets/images/tenda_logo_full.png` | Pantalla de login |
| Isotipo / marca | `assets/images/tenda_logo_mark.png` | Disponible para uso futuro |
