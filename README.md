# PCBRev

A Flutter application to help with reverse engineering of electronic devices.

## Purpose

This application helps in the process of reverse engineering electronic devices by:

1.  Measuring component values and tracing connections between them.
2.  Analyzing PCB images (both component and trace sides) to infer connections.
3.  Using AI to interpret connections, components, and the overall architecture of the device.

## Project Structure

```
pcb_rev/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── pcb_board.dart
│   │   └── pcb_models.dart
│   ├── services/
│   │   ├── image_processor.dart
│   │   ├── mcp_server.dart
│   │   └── measurement_service.dart
│   └── ui/
│       └── main_screen.dart
├── pubspec.yaml
... (other Flutter project files)
```

## How to Run

To run the application, execute the following commands:

```bash
cd pcb_rev
flutter run
```