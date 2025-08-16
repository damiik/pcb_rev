import 'package:flutter/material.dart';
import '../../../schematic/data/logical_models.dart';

class GlobalListPanel extends StatelessWidget {
  final List<LogicalComponent> components;
  final List<LogicalNet> nets;
  final Function(LogicalComponent) onComponentSelected;
  final Function(LogicalNet) onNetSelected;

  GlobalListPanel({
    required this.components,
    required this.nets,
    required this.onComponentSelected,
    required this.onNetSelected,
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
