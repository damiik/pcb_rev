typedef MeasurementState = ({
  Map<String, double> resistanceMap,
  Map<String, double> voltageMap,
  Map<String, bool> continuityMap,
});

// Initial state
MeasurementState createInitialMeasurementState() =>
    (resistanceMap: {}, voltageMap: {}, continuityMap: {});

// Pure functions to update the state
MeasurementState recordResistance(
  MeasurementState state,
  String point1,
  String point2,
  double ohms,
) {
  final key = _getKey(point1, point2);
  return (
    resistanceMap: (Map.of(state.resistanceMap)..[key] = ohms),
    voltageMap: state.voltageMap,
    continuityMap: state.continuityMap,
  );
}

MeasurementState recordVoltage(
  MeasurementState state,
  String point,
  double volts,
) {
  return (
    resistanceMap: state.resistanceMap,
    voltageMap: (Map.of(state.voltageMap)..[point] = volts),
    continuityMap: state.continuityMap,
  );
}

MeasurementState recordContinuity(
  MeasurementState state,
  String point1,
  String point2,
  bool connected,
) {
  final key = _getKey(point1, point2);
  return (
    resistanceMap: state.resistanceMap,
    voltageMap: state.voltageMap,
    continuityMap: (Map.of(state.continuityMap)..[key] = connected),
  );
}

String _getKey(String p1, String p2) {
  // Ensure consistent ordering
  return p1.compareTo(p2) < 0 ? '$p1-$p2' : '$p2-$p1';
}

// Function to generate a report from the state
Map<String, dynamic> generateMeasurementReport(MeasurementState state) {
  return {
    'resistance': state.resistanceMap,
    'voltage': state.voltageMap,
    'continuity': state.continuityMap,
    'timestamp': DateTime.now().toIso8601String(),
  };
}
