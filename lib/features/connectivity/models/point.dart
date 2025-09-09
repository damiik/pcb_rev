import 'dart:math';
import 'package:flutter/material.dart';

/// Prosta klasa do reprezentacji punktów w przestrzeni 2D.
/// KiCad używa integerowych współrzędnych dla schematów,
/// co eliminuje problemy z precyzją obliczeń.
class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  /// Porównanie punktów (==)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  /// Dodawanie punktów
  Point operator +(Point other) => Point(x + other.x, y + other.y);

  /// Odejmowanie punktów
  Point operator -(Point other) => Point(x - other.x, y - other.y);

  /// Odległość euklidesowa (przydatna do debugowania)
  double distanceTo(Point other) {
    final dx = (x - other.x).toDouble();
    final dy = (y - other.y).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => "Point($x, $y)";
}

extension PointToOffset on Point {
  Offset toOffset() => Offset(x.toDouble(), y.toDouble());
}