import '../data/core.dart';
import 'default_tools.dart';
import 'project_mcp_tools.dart';
import 'schematic_edit_tools.dart';

/// All available MCP tools for PCB reverse engineering
final List<ToolDefinition> availableTools = [
  ...defaultTools,
  ...schematicEditTools,
  ...projectMcpTools,
];

/// Default MCP tools for basic PCB reverse engineering operations
/// These tools provide core functionality for image processing and schematic analysis
List<ToolDefinition> get defaultMcpTools => defaultTools;

/// Schematic editing MCP tools for manipulating KiCad schematics
/// These tools provide advanced functionality for modifying schematic elements
List<ToolDefinition> get schematicEditMcpTools => schematicEditTools;

/// Get tools by category
List<ToolDefinition> getToolsByCategory(String category) {
  switch (category) {
    case 'default':
      return defaultTools;
    case 'schematic_edit':
      return schematicEditTools;
    case 'project_management':
      return projectMcpTools;
    default:

      return [];
  }
}

/// Get tool definition by name across all categories
ToolDefinition? getToolByName(String name) {
  return availableTools.firstWhere((tool) => tool.name == name);
}
