import 'package:flutter/material.dart';

/// Utilidades para adaptar la UI a distintos tamaños de pantalla.
class AppSizes {
  AppSizes._();

  /// Escala un tamaño de fuente según el ancho disponible:
  /// tablets (≥600dp) lo aumentan, pantallas pequeñas (≤320dp) lo reducen.
  static double font(BuildContext context, double size) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) return size * 1.15;
    if (width <= 320) return size * 0.85;
    return size;
  }

  /// Ancho recomendado para tarjetas en una grilla responsiva.
  static double cardWidth(double maxWidth) {
    if (maxWidth >= 720) return (maxWidth - 24) / 3;
    if (maxWidth >= 480) return (maxWidth - 12) / 2;
    return maxWidth;
  }

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;
}
