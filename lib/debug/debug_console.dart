import 'package:flutter/material.dart';
import 'log_service.dart';

class DebugConsole extends StatelessWidget {
  const DebugConsole({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LogService.instance,
      builder: (context, _) {
        final logs = LogService.instance.logs;
        return GestureDetector(
          onTap: () {},
          child: Container(
            height: 200,
            color: const Color(0xF0000000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: Colors.grey[900],
                  child: Row(
                    children: [
                      const Text('Debug Console',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      const Spacer(),
                      Text('${logs.length} entries',
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => LogService.instance.clear(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      return _buildLogEntry(entry);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogEntry(LogEntry entry) {
    Color color;
    switch (entry.level) {
      case LogLevel.error:
        color = Colors.redAccent;
        break;
      case LogLevel.warning:
        color = Colors.orangeAccent;
        break;
      case LogLevel.success:
        color = Colors.lightGreenAccent;
        break;
      default:
        color = Colors.white70;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Text(
        '[${entry.timestamp.toString().substring(11, 19)}] ${entry.message}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.2,
        ),
      ),
    );
  }
}
