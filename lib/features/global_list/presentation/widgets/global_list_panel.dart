import 'package:flutter/material.dart';
import 'package:pcb_rev/features/connectivity/models/core.dart' as connectivity_core;
import '../../../schematic/data/logical_models.dart';
import '../../../symbol_library/data/kicad_schematic_models.dart';
import '../../../symbol_library/data/kicad_symbol_models.dart' as kicad_models;

class GlobalListPanel extends StatefulWidget {
  final List<LogicalComponent> components;
  final List<connectivity_core.Net> nets;
  final Function(LogicalComponent) onComponentSelected;
  final Function(connectivity_core.Net) onNetSelected;
  final Function(kicad_models.LibrarySymbol) onLibrarySymbolSelected;
  final KiCadSchematic? schematic;

  GlobalListPanel({
    required this.components,
    required this.nets,
    required this.onComponentSelected,
    required this.onNetSelected,
    required this.onLibrarySymbolSelected,
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
    if (widget.schematic != null && widget.schematic!.symbolInstances.isNotEmpty) {
      return widget.schematic!.symbolInstances
          .map((symbolInstance) {
            final reference =
                _getPropertyValue(symbolInstance.properties, 'Reference') ?? '';
            final value = _getPropertyValue(symbolInstance.properties, 'Value') ?? '';
            final partNumber =
                _getPropertyValue(symbolInstance.properties, 'Footprint') ?? '';

            return (
              id: reference,
              type: symbolInstance.libId,
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

  List<connectivity_core.Net> _filterNets(String query) {
    return widget.nets
        .where((net) => net.name.toLowerCase().contains(query))
        .toList();
  }

  List<kicad_models.LibrarySymbol> _filterLibrarySymbols(String query) {
    if (widget.schematic?.library?.librarySymbols != null) {
      return widget.schematic!.library!.librarySymbols
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

  Widget _buildNetList(List<connectivity_core.Net> nets) {
    return ListView.builder(
      itemCount: nets.length,
      itemBuilder: (context, index) {
        final net = nets[index];
        return ListTile(
          title: Text(net.name),
          subtitle: Text('${net.pins.length} pins'),
          onTap: () => widget.onNetSelected(net),
        );
      },
    );
  }

  Widget _buildLibrarySymbolList(List<kicad_models.LibrarySymbol> librarySymbols) {
    return ListView.builder(
      itemCount: librarySymbols.length,
      itemBuilder: (context, index) {
        final symbol = librarySymbols[index];
        return ListTile(
          title: Text(symbol.name),
          onTap: () => widget.onLibrarySymbolSelected(symbol),
        );
      },
    );
  }
}
