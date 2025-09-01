import 'package:flutter/material.dart';
import '../../../schematic/data/logical_models.dart';
import '../../../symbol_library/data/kicad_schematic_models.dart';
import '../../../symbol_library/data/kicad_symbol_models.dart' as kicad_models;

class GlobalListPanel extends StatefulWidget {
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
  _GlobalListPanelState createState() => _GlobalListPanelState();
}

class _GlobalListPanelState extends State<GlobalListPanel> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _getPropertyValue(
    List<kicad_models.Property> properties,
    String propertyName,
  ) {
    final property = properties.where((p) => p.name == propertyName).firstOrNull;
    return property?.value;
  }

  @override
  Widget build(BuildContext context) {
    final filteredComponents = _filterComponents(_query);
    final filteredNets = _filterNets(_query);
    final filteredLibrarySymbols = _filterLibrarySymbols(_query);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Components (${filteredComponents.length})'),
              Tab(text: 'Nets (${filteredNets.length})'),
              Tab(text: 'Library (${filteredLibrarySymbols.length})'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4.0),
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildComponentList(filteredComponents),
                _buildNetList(filteredNets),
                _buildLibrarySymbolList(filteredLibrarySymbols),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<LogicalComponent> _filterComponents(String query) {
    if (widget.schematic != null && widget.schematic!.symbols.isNotEmpty) {
      return widget.schematic!.symbols
          .map((symbol) {
            final reference =
                _getPropertyValue(symbol.properties, 'Reference') ?? '';
            final value = _getPropertyValue(symbol.properties, 'Value') ?? '';
            final partNumber =
                _getPropertyValue(symbol.properties, 'Footprint') ?? '';

            return (
              id: reference,
              type: symbol.libId,
              variant: null,
              value: value,
              partNumber: partNumber,
              pins: <String, Pin>{},
            );
          })
          .where((component) =>
              component.id.toLowerCase().contains(query) ||
              component.type.toLowerCase().contains(query) ||
              (component.value?.toLowerCase().contains(query) ?? false))
          .toList();
    } else {
      return widget.components
          .where((component) =>
              component.id.toLowerCase().contains(query) ||
              (component.type.toLowerCase().contains(query)) ||
              (component.value?.toLowerCase().contains(query) ?? false))
          .toList();
    }
  }

  List<LogicalNet> _filterNets(String query) {
    return widget.nets
        .where((net) => net.name.toLowerCase().contains(query))
        .toList();
  }

  List<kicad_models.Symbol> _filterLibrarySymbols(String query) {
    if (widget.schematic?.library?.symbols != null) {
      return widget.schematic!.library!.symbols
          .where((symbol) => symbol.name.toLowerCase().contains(query))
          .toList();
    }
    return [];
  }

  Widget _buildComponentList(List<LogicalComponent> components) {
    return ListView.builder(
      itemCount: components.length,
      itemBuilder: (context, index) {
        final component = components[index];
        return ListTile(
          title: Text(component.id),
          subtitle: Text('${component.type} ${component.value ?? ""}'),
          onTap: () => widget.onComponentSelected(component),
        );
      },
    );
  }

  Widget _buildNetList(List<LogicalNet> nets) {
    return ListView.builder(
      itemCount: nets.length,
      itemBuilder: (context, index) {
        final net = nets[index];
        return ListTile(
          title: Text(net.name),
          subtitle: Text('${net.connections.length} connections'),
          onTap: () => widget.onNetSelected(net),
        );
      },
    );
  }

  Widget _buildLibrarySymbolList(List<kicad_models.Symbol> symbols) {
    return ListView.builder(
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        return ListTile(
          title: Text(symbol.name),
          onTap: () {
            // TODO: Implement selection handling for library symbols
          },
        );
      },
    );
  }
}