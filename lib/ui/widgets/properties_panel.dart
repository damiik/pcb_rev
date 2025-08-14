import 'package:flutter/material.dart';
import '../../services/measurement_service.dart';

class PropertiesPanel extends StatelessWidget {
  final MeasurementService measurementService;
  final Function(String, dynamic) onMeasurementAdded;

  PropertiesPanel({
    required this.measurementService,
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
          Text('Measurements', style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          
          // Measurement input forms
          ElevatedButton.icon(
            icon: Icon(Icons.electrical_services),
            label: Text('Add Resistance'),
            onPressed: () => _showMeasurementDialog(context, 'resistance'),
          ),
          
          SizedBox(height: 8),
          
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
                ...measurementService.resistanceMap.entries.map((e) {
                  return ListTile(
                    leading: Icon(Icons.electrical_services),
                    title: Text(e.key),
                    trailing: Text('${e.value} Ω'),
                  );
                }),
                ...measurementService.voltageMap.entries.map((e) {
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
    // Show dialog to input measurement
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $type measurement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Point 1'),
            ),
            if (type != 'voltage')
              TextField(
                decoration: InputDecoration(labelText: 'Point 2'),
              ),
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
              // Add measurement
              onMeasurementAdded(type, 0); // Pass actual values
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
