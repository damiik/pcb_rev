import 'package:flutter/material.dart';
import '../data/measurement_service.dart';

class PropertiesPanel extends StatelessWidget {
  final MeasurementState measurementState;
  final Function(String, dynamic) onMeasurementAdded;

  PropertiesPanel({
    required this.measurementState,
    required this.onMeasurementAdded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey)),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Components & Measurements',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),

          // Component creation buttons
          ElevatedButton.icon(
            icon: Icon(Icons.add_circle_outline),
            label: Text('Add Component'),
            onPressed: () => _showComponentDialog(context),
          ),
          SizedBox(height: 16),

          // Measurement input forms
          ElevatedButton.icon(
            icon: Icon(Icons.flash_on),
            label: Text('Add Voltage'),
            onPressed: () => _showMeasurementDialog(context, 'voltage'),
          ),
          SizedBox(height: 8),
          ElevatedButton.icon(
            icon: Icon(Icons.link),
            label: Text('Test Continuity'),
            onPressed: () => _showMeasurementDialog(context, 'continuity'),
          ),

          Divider(height: 32),

          // Display recent measurements
          Expanded(
            child: ListView(
              children: [
                ...measurementState.resistanceMap.entries.map((e) {
                  return ListTile(
                    leading: Icon(Icons.electrical_services),
                    title: Text(e.key),
                    trailing: Text('${e.value} Ω'),
                  );
                }),
                ...measurementState.voltageMap.entries.map((e) {
                  return ListTile(
                    leading: Icon(Icons.flash_on),
                    title: Text(e.key),
                    trailing: Text('${e.value} V'),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMeasurementDialog(BuildContext context, String type) {
    // Dialog to input measurement
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $type measurement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Point 1')),
            if (type != 'voltage')
              TextField(decoration: InputDecoration(labelText: 'Point 2')),
            TextField(
              decoration: InputDecoration(labelText: 'Value'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Add'),
            onPressed: () {
              // This would now be handled in the main screen's state
              onMeasurementAdded(type, 0); // Pass actual values
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showComponentDialog(BuildContext context) {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    String selectedType = 'Resistor';
    String? selectedIcVariant;
    final componentTypes = {
      'Resistor': null,
      'Capacitor': null,
      'IC': [
        'IC 8pin',
        'IC 16pin',
        'IC 20pin',
        'IC 24pin',
        'IC 28pin',
        'IC 32pin',
        'IC 48pin Q',
      ],
      'Diode': null,
      'Transistor': null,
      'Inductor': null,
    };

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Component'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedType,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedType = newValue!;
                        if (componentTypes[selectedType] != null) {
                          selectedIcVariant = componentTypes[selectedType]![0];
                        } else {
                          selectedIcVariant = null;
                        }
                      });
                    },
                    items: componentTypes.keys.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  if (selectedType == 'IC' && selectedIcVariant != null)
                    DropdownButton<String>(
                      value: selectedIcVariant,
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedIcVariant = newValue!;
                        });
                      },
                      items: componentTypes['IC']!.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Name (e.g. R1)'),
                  ),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(labelText: 'Value (e.g. 10k)'),
                    keyboardType: TextInputType.text,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: Text('Add'),
                  onPressed: () {
                    final componentData = {
                      'type': selectedIcVariant ?? selectedType,
                      'name': nameController.text,
                      'value': valueController.text,
                    };
                    onMeasurementAdded(
                      (selectedIcVariant ?? selectedType).toLowerCase(),
                      componentData,
                    );
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
