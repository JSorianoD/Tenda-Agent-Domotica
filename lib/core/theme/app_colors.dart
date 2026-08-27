import 'package:flutter/material.dart';

/// Design tokens — color palette for the Jarvis Home Assistant UI.
///
/// Extracted from the validated reference screenshots.
/// All UI code should reference these constants instead of hard-coding colors.
/// Design tokens — color palette for the Jarvis Home Assistant UI.
///
/// All UI code MUST reference these constants.
/// Never write a Color(0x...) literal directly in a widget.
abstract final class AppColors {
  // ── Tenda Brand (source of truth) ────────────────────────────────────────
  /// Fondo principal — negro profundo de la marca.
  static const tendaDeepBlack = Color(0xFF0A0A0A);

  /// Acento primario — dorado Tenda, CTA, foco, íconos activos.
  static const tendaGold = Color(0xFFC9A227);

  /// Variante clara del dorado — hover states, gradientes.
  static const tendaGoldLight = Color(0xFFE0C463);

  /// Blanco Tenda — texto principal sobre fondos oscuros.
  static const tendaWhite = Color(0xFFFFFFFF);

  /// Texto secundario / placeholders.
  static const tendaGrayMuted = Color(0xFF8A8A8A);

  /// Fondo de inputs.
  static const tendaInputBackground = Color(0xFF1A1A1A);

  // ── Semantic aliases (use these in widgets — never the raw hex) ───────────
  /// Fondo del Scaffold principal.
  static const background = tendaDeepBlack;

  /// Superficie de cards / AppBar.
  static const surface = Color(0xFF111111);

  /// Superficie más clara — containers anidados.
  static const surfaceLight = Color(0xFF1A1A1A);

  /// Color de acento — CTA, íconos activos, highlights.
  static const accent = tendaGold;

  /// Variante dim del acento — track del switch activo.
  static const accentDim = Color(0xFF6B5100);

  /// Texto primario.
  static const textPrimary = tendaWhite;

  /// Texto secundario.
  static const textSecondary = Color(0xFF8A94A6);

  /// Texto muted / apagado.
  static const textMuted = Color(0xFF4A5568);

  /// Divisor entre secciones.
  static const divider = Color(0xFF222222);

  /// Error / destructivo.
  static const error = Color(0xFFFF5252);

  // ── DEPRECATED — mantener solo para la pantalla de orbe (animations) ─────
  // No usar en nuevas pantallas. Reemplazar por los alias de arriba.
  /// @deprecated Usar [accent]
  static const cyan = tendaGold;

  /// @deprecated Usar [accentDim]
  static const cyanDim = accentDim;

  /// @deprecated Usar [accentDim]
  static const cyanGlow = accentDim;
}
