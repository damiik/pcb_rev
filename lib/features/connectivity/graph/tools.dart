import '../models/point.dart';



/// Sprawdza, czy punkt p leży na odcinku a-b (włącznie z końcami).
bool pointOnSegment(Point p, Point a, Point b) {
  // Najpierw sprawdź, czy punkty są kolinearne
  final orient = _orientation(a, b, p);
  if (orient != 0) return false;

  // Następnie sprawdź czy p leży w prostokącie ograniczającym a i b
  final minX = (a.x < b.x) ? a.x : b.x;
  final maxX = (a.x > b.x) ? a.x : b.x;
  final minY = (a.y < b.y) ? a.y : b.y;
  final maxY = (a.y > b.y) ? a.y : b.y;

  return (p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY);
}

/// Zwraca 0 jeśli kolinearne, 1 jeśli clockwise, 2 jeśli counterclockwise.
/// Wykorzystuje integerową arytmetykę (bez zaokrągleń).
int _orientation(Point a, Point b, Point c) {
  final val = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
  if (val == 0) return 0;
  return (val > 0) ? 1 : 2;
}

/// Sprawdza przecięcie odcinków (a1,a2) i (b1,b2).
bool segmentsIntersect(Point a1, Point a2, Point b1, Point b2) {
  final o1 = _orientation(a1, a2, b1);
  final o2 = _orientation(a1, a2, b2);
  final o3 = _orientation(b1, b2, a1);
  final o4 = _orientation(b1, b2, a2);

  if (o1 != o2 && o3 != o4) return true;

  // Obsługa przypadków kolinearnych (punkt leży na odcinku)
  if (o1 == 0 && pointOnSegment(b1, a1, a2)) return true;
  if (o2 == 0 && pointOnSegment(b2, a1, a2)) return true;
  if (o3 == 0 && pointOnSegment(a1, b1, b2)) return true;
  if (o4 == 0 && pointOnSegment(a2, b1, b2)) return true;

  return false;
}
