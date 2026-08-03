import 'package:flutter/material.dart';

/// Identité visuelle Estuaire Examen — dérivée du logo IUEs/INSAM.
/// Thème clair uniquement, pas de mode sombre.
class AppColors {
  // Couleurs du logo
  static const rouge = Color(0xFFD62027);
  static const rougeSombre = Color(0xFFA8171D);
  static const rougePale = Color(0xFFFDECEC);
  static const bleu = Color(0xFF2E75B6);
  static const bleuSombre = Color(0xFF1F5A8D);
  static const bleuPale = Color(0xFFEAF2FA);

  // Neutres
  static const ardoise = Color(0xFF1C2430);
  static const texte = Color(0xFF16202B);
  static const texteDoux = Color(0xFF5C6B7A);
  static const texteFaible = Color(0xFF8A97A5);
  static const bordure = Color(0xFFDCE3EA);
  static const bordureDouce = Color(0xFFEDF1F5);
  static const fond = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const survol = Color(0xFFF0F4F8);

  // Sémantiques
  static const succes = Color(0xFF1E8E5A);
  static const succesPale = Color(0xFFE7F5EE);
  static const alerte = Color(0xFFB7791F);
  static const alertePale = Color(0xFFFDF4E3);
  static const danger = Color(0xFFC0392B);
  static const dangerPale = Color(0xFFFBEBE9);
}

/// Espacement sur une échelle de 4px.
class Espace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

const double rayon = 8.0;
const double rayonPetit = 6.0;

ThemeData construireTheme() {
  const police = 'Inter';

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.fond,
    colorScheme: const ColorScheme.light(
      primary: AppColors.rouge,
      onPrimary: Colors.white,
      secondary: AppColors.bleu,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.texte,
      error: AppColors.danger,
      outline: AppColors.bordure,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          fontFamily: police,
          bodyColor: AppColors.texte,
          displayColor: AppColors.texte,
        )
        .copyWith(
          headlineSmall: const TextStyle(
            fontFamily: police,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.texte,
          ),
          titleLarge: const TextStyle(
            fontFamily: police,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: AppColors.texte,
          ),
          titleMedium: const TextStyle(
            fontFamily: police,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.texte,
          ),
          bodyMedium: const TextStyle(
            fontFamily: police,
            fontSize: 13.5,
            height: 1.45,
            color: AppColors.texte,
          ),
          bodySmall: const TextStyle(
            fontFamily: police,
            fontSize: 12.5,
            color: AppColors.texteDoux,
          ),
          labelSmall: const TextStyle(
            fontFamily: police,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.texteDoux,
          ),
        ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayon),
        side: const BorderSide(color: AppColors.bordure),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Espace.md,
        vertical: Espace.md,
      ),
      hintStyle: const TextStyle(
        fontFamily: police,
        fontSize: 13.5,
        color: AppColors.texteFaible,
      ),
      labelStyle: const TextStyle(
        fontFamily: police,
        fontSize: 13,
        color: AppColors.texteDoux,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayonPetit),
        borderSide: const BorderSide(color: AppColors.bordure),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayonPetit),
        borderSide: const BorderSide(color: AppColors.bordure),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayonPetit),
        borderSide: const BorderSide(color: AppColors.bleu, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rayonPetit),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.rouge,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: Espace.lg,
          vertical: Espace.md + 2,
        ),
        textStyle: const TextStyle(
          fontFamily: police,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonPetit),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.texte,
        side: const BorderSide(color: AppColors.bordure),
        padding: const EdgeInsets.symmetric(
          horizontal: Espace.lg,
          vertical: Espace.md + 2,
        ),
        textStyle: const TextStyle(
          fontFamily: police,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayonPetit),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.bleu,
        textStyle: const TextStyle(
          fontFamily: police,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.bordure,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayon + 2),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ardoise,
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
      textStyle: const TextStyle(
        fontFamily: police,
        fontSize: 12,
        color: Colors.white,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ardoise,
      contentTextStyle: const TextStyle(fontFamily: police, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayonPetit),
      ),
    ),
  );
}
