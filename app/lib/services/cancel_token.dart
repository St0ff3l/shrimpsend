class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  final List<void Function()> _listeners = [];

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final cb in _listeners) {
      try {
        cb();
      } catch (_) {}
    }
    _listeners.clear();
  }

  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }
}
