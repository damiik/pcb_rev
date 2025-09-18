import 'dart:async';
import 'dart:typed_data';

class ViewCaptureService {
  static final ViewCaptureService _instance = ViewCaptureService._internal();
  factory ViewCaptureService() => _instance;
  ViewCaptureService._internal();

  Completer<Uint8List>? _completer;
  void Function()? _trigger;

  void registerTrigger(void Function() trigger) {
    _trigger = trigger;
  }

  void unregisterTrigger() {
    _trigger = null;
  }

  Future<Uint8List> capture() {
    if (_trigger == null) {
      return Future.error('No capture trigger registered from the UI.');
    }
    _completer = Completer<Uint8List>();
    _trigger!();
    return _completer!.future;
  }

  void complete(Uint8List data) {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(data);
    }
    _completer = null;
  }

  void cancel() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError('Capture cancelled.');
    }
    _completer = null;
  }
}
