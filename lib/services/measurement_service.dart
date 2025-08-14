class MeasurementService {
  final Map<String, double> resistanceMap = {};
  final Map<String, double> voltageMap = {};
  final Map<String, bool> continuityMap = {};
  
  // Record resistance measurement between two points
  void recordResistance(String point1, String point2, double ohms) {
    final key = _getKey(point1, point2);
    resistanceMap[key] = ohms;
  }
  
  // Record voltage at a point
  void recordVoltage(String point, double volts) {
    voltageMap[point] = volts;
  }
  
  // Record continuity test
  void recordContinuity(String point1, String point2, bool connected) {
    final key = _getKey(point1, point2);
    continuityMap[key] = connected;
  }
  
  String _getKey(String p1, String p2) {
    // Ensure consistent ordering
    return p1.compareTo(p2) < 0 ? '$p1-$p2' : '$p2-$p1';
  }
  
  // Generate measurement report
  Map<String, dynamic> generateReport() {
    return {
      'resistance': resistanceMap,
      'voltage': voltageMap,
      'continuity': continuityMap,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
