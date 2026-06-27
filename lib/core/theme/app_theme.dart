import 'package:flutter/material.dart';

/// Define o tema global do aplicativo Liahona Quiz.
/// Utiliza tons sóbrios de azul escuro como primária e dourado suave como secundária.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // Configurando a paleta de cores personalizada do aplicativo
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F2942), // Azul Escuro SUD Principal
        primary: const Color(0xFF0F2942),
        primaryContainer: const Color(0xFF1B3C5F),
        secondary: const Color(0xFFD4AF37), // Dourado Suave Metálico
        secondaryContainer: const Color(0xFFF9E7B9),
        surface: const Color(0xFFF4F6F9), // Fundo azul-acinzentado muito suave
        onPrimary: Colors.white,
        onSecondary: const Color(0xFF2C2405),
        onSurface: const Color(0xFF0F2942),
      ),
      // Tipografia moderna e limpa
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F2942),
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
      ),
    );
  }
}
