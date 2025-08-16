import 'package:flutter/material.dart';
import '../../models/pcb_models.dart';

class ComponentListPanel extends StatelessWidget {
  final List<Component> components;
  final Function(Component) onComponentSelected;

  ComponentListPanel({
    required this.components,
    required this.onComponentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey)),
      ),
      child: ListView.builder(
        itemCount: components.length,
        itemBuilder: (context, index) {
          final component = components[index];
          return ListTile(
            title: Text(component.id),
            subtitle: Text('${component.type} ${component.value ?? ""}'),
            onTap: () => onComponentSelected(component),
          );
        },
      ),
    );
  }
}

