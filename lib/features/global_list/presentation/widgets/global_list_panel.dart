import 'package:flutter/material.dart';
import '../../../schematic/data/logical_models.dart';
import '../../../symbol_library/data/kicad_schematic_models.dart';
import '../../../symbol_library/data/kicad_symbol_models.dart' as kicad_models;

class GlobalListPanel extends StatelessWidget {
  final List<LogicalComponent> components;
  final List<LogicalNet> nets;
  final Function(LogicalComponent) onComponentSelected;
  final Function(LogicalNet) onNetSelected;
  final KiCadSchematic? schematic;

  GlobalListPanel({
    required this.components,
    required this.nets,
    required this.onComponentSelected,
    required this.onNetSelected,
    this.schematic,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Components'),
              Tab(text: 'Nets'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildComponentList(), _buildNetList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentList() {
    // If schematic is available, show schematic components
    if (schematic != null && schematic!.symbols.isNotEmpty) {
      return ListView.builder(
        itemCount: schematic!.symbols.length,
        itemBuilder: (context, index) {
          final symbolInstance = schematic!.symbols[index];

          // Extract reference and value from properties
          final reference =
              _getPropertyValue(symbolInstance.properties, 'Reference') ??
              'Unknown';
          final value =
              _getPropertyValue(symbolInstance.properties, 'Value') ?? '';

          return ListTile(
            title: Text(reference),
            subtitle: Text(
              '${symbolInstance.libId} ${value.isNotEmpty ? '- $value' : ''}',
            ),
            trailing: Icon(Icons.schema, size: 16),
            onTap: () {
              // For now, we'll create a dummy LogicalComponent for compatibility
              // This could be enhanced to pass the SymbolInstance directly
              final dummyComponent = (
                id: reference,
                type: symbolInstance.libId,
                variant: null,
                value: value,
                partNumber:
                    _getPropertyValue(symbolInstance.properties, 'Footprint') ??
                    '',
                pins: <String, Pin>{},
              );
              onComponentSelected(dummyComponent);
            },
          );
        },
      );
    }

    // Otherwise, show logical components as before
    return ListView.builder(
      itemCount: components.length,
      itemBuilder: (context, index) {
        final component = components[index];
        return ListTile(
          title: Text(component.id),
          subtitle: Text('${component.type} ${component.value ?? ""}'),
          onTap: () => onComponentSelected(component),
        );
      },
    );
  }

  String? _getPropertyValue(
    List<kicad_models.Property> properties,
    String propertyName,
  ) {
    final property = properties
        .where((p) => p?.name == propertyName)
        .firstOrNull;
    return property?.value;
  }

  Widget _buildNetList() {
    return ListView.builder(
      itemCount: nets.length,
      itemBuilder: (context, index) {
        final net = nets[index];
        return ListTile(
          title: Text(net.name),
          subtitle: Text('${net.connections.length} connections'),
          onTap: () => onNetSelected(net),
        );
      },
    );
  }
}
