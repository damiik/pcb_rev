import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error, success }

class LogEntry {
  final LogLevel level;
  final DateTime timestamp;
  final String message;
  LogEntry(this.level, this.timestamp, this.message);
}

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._();
  static LogService get instance => _instance;
  LogService._();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(LogLevel level, String message) {
    _logs.add(LogEntry(level, DateTime.now(), message));
    notifyListeners();
    debugPrint('[${level.name}] $message');
  }

  void info(String message) => log(LogLevel.info, message);
  void warning(String message) => log(LogLevel.warning, message);
  void error(String message) => log(LogLevel.error, message);
  void success(String message) => log(LogLevel.success, message);

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
