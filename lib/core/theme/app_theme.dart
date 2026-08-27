import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tenda-branded [ThemeData] — single source of truth for the app theme.
///
/// Design System brief (negro/dorado, 60-30-10):
///   - Background: [AppColors.tendaDeepBlack]
///   - Primary accent: [AppColors.tendaGold] (CTA, focus ring, íconos)
///   - Text: [AppColors.tendaWhite]
///
/// Al definir [switchTheme], [iconTheme] y [dividerTheme] aquí, cualquier
/// widget nuevo que NO especifique color inline toma automáticamente el
/// dorado Tenda — no es necesario acordarse de agregar AppColors en cada
/// pantalla nueva.
ThemeData buildTendaTheme() {
  final base = ThemeData.dark();

  final textTheme = GoogleFonts.rajdhaniTextTheme(
    base.textTheme,
  ).apply(bodyColor: AppColors.tendaWhite, displayColor: AppColors.tendaWhite);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.tendaDeepBlack,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.tendaGold,
      onPrimary: AppColors.tendaDeepBlack,
      secondary: AppColors.tendaGoldLight,
      onSecondary: AppColors.tendaDeepBlack,
      surface: AppColors.surface,
      onSurface: AppColors.tendaWhite,
      error: AppColors.error,
    ),

    textTheme: textTheme,

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: AppColors.tendaWhite,
        fontWeight: FontWeight.w300,
        letterSpacing: 4,
      ),
      iconTheme: const IconThemeData(color: AppColors.tendaWhite),
    ),

    // Causa raiz del cian: sin este bloque cualquier Switch() usa el color
    // primary del esquema (que antes era cyan). Ahora se hereda el dorado
    // automáticamente sin que ninguna pantalla tenga que especificarlo.
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

    // Todo ícono sin color explícito usa blanco Tenda.
    iconTheme: const IconThemeData(color: AppColors.tendaWhite),

    // Divisores sutiles — blanco al 15%.
    dividerTheme: DividerThemeData(
      color: AppColors.tendaWhite.withValues(alpha: 0.15),
    ),
    dividerColor: AppColors.tendaWhite.withValues(alpha: 0.10),

    // Inputs: línea inferior, foco en dorado.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.tendaInputBackground,
      labelStyle: GoogleFonts.rajdhani(
        color: AppColors.tendaGrayMuted,
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
      hintStyle: GoogleFonts.rajdhani(
        color: AppColors.tendaGrayMuted,
        fontWeight: FontWeight.w300,
        fontSize: 14,
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.tendaWhite.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.tendaWhite.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.tendaGold, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
    ),

    // CTA: plano, dorado, texto en negro.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.tendaGold,
        foregroundColor: AppColors.tendaDeepBlack,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 3,
        ),
      ),
    ),

    cardColor: AppColors.surface,
  );
}

// Alias de compatibilidad — eliminar en la siguiente limpieza.
// ignore: non_constant_identifier_names
ThemeData buildAppTheme() => buildTendaTheme();
