import 'package:flutter/material.dart';

/// Paleta y temas de la app.
///
/// El diseño se apoya en mucho blanco (o casi negro en oscuro), tipografía
/// pesada para los títulos y un único color de acento naranja que marca lo
/// activo: pestaña seleccionada, progreso, botón de reproducir.
class AppColors {
  const AppColors._();

  /// Acento de marca. Se usa para rellenos e indicadores, no para texto chico
  /// sobre fondo claro (ahí no llega a contraste suficiente).
  static const Color naranja = Color(0xFFFF6B2C);

  /// Variante oscurecida, para texto e iconos naranjas sobre fondo claro.
  static const Color naranjaTexto = Color(0xFFC94E0A);

  // Claro
  static const Color fondoClaro = Color(0xFFFFFFFF);
  static const Color superficieClara = Color(0xFFF4F5F7);
  static const Color textoClaro = Color(0xFF12131A);
  static const Color textoSuaveClaro = Color(0xFF7C808F);

  // Oscuro
  static const Color fondoOscuro = Color(0xFF0E0F13);
  static const Color superficieOscura = Color(0xFF1A1C22);
  static const Color textoOscuro = Color(0xFFF5F5F7);
  static const Color textoSuaveOscuro = Color(0xFF9296A3);
}

class AppTheme {
  const AppTheme._();

  static const String _fuente = 'Poppins';

  static ThemeData get claro => _construir(
    brillo: Brightness.light,
    fondo: AppColors.fondoClaro,
    superficie: AppColors.superficieClara,
    texto: AppColors.textoClaro,
    textoSuave: AppColors.textoSuaveClaro,
  );

  static ThemeData get oscuro => _construir(
    brillo: Brightness.dark,
    fondo: AppColors.fondoOscuro,
    superficie: AppColors.superficieOscura,
    texto: AppColors.textoOscuro,
    textoSuave: AppColors.textoSuaveOscuro,
  );

  static ThemeData _construir({
    required Brightness brillo,
    required Color fondo,
    required Color superficie,
    required Color texto,
    required Color textoSuave,
  }) {
    final esquema =
        ColorScheme.fromSeed(
          seedColor: AppColors.naranja,
          brightness: brillo,
        ).copyWith(
          primary: AppColors.naranja,
          onPrimary: Colors.white,
          surface: fondo,
          onSurface: texto,
          surfaceContainerHighest: superficie,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,
      fontFamily: _fuente,
      textTheme: _tipografia(texto, textoSuave),
      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        foregroundColor: texto,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _fuente,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: texto,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficie,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.naranja, width: 1.6),
        ),
        hintStyle: TextStyle(color: textoSuave, fontWeight: FontWeight.w400),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.naranja,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: _fuente,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: texto,
        unselectedLabelColor: textoSuave,
        indicatorColor: AppColors.naranja,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: _fuente,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: _fuente,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: fondo,
        indicatorColor: AppColors.naranja.withValues(alpha: 0.16),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: _fuente,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textoSuave,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: superficie,
        contentTextStyle: TextStyle(fontFamily: _fuente, color: texto),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static TextTheme _tipografia(Color texto, Color textoSuave) {
    return TextTheme(
      // Títulos grandes de pantalla: "Descubrir", "Tu biblioteca".
      displaySmall: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: texto,
      ),
      // Encabezados de sección: "Agregados recientemente".
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: texto,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: texto,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: texto),
      bodyMedium: TextStyle(fontSize: 14, color: texto),
      // Subtítulos: artista, cantidad de temas.
      bodySmall: TextStyle(fontSize: 13, color: textoSuave),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: texto,
      ),
    );
  }
}
