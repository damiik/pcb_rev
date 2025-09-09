import 'core.dart';


final class Connectivity {
  final ConnectivityGraph graph;
  final List<Net> nets;

  Connectivity({
    required this.graph,
    required this.nets,
  });

  Connectivity copyWith({
    ConnectivityGraph? graph,
    List<Net>? nets,
  }) => Connectivity(
    graph: graph ?? this.graph,
    nets: nets ?? this.nets,
  );
}