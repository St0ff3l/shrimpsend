/// Tracks transfer speed using exponential smoothing.
///
/// Call [update] whenever new bytes-received data is available.
/// Read [bytesPerSecond] or [formatted] for the current speed.
class SpeedTracker {
  int _lastBytes = 0;
  DateTime _lastTime = DateTime.now();
  double _bytesPerSecond = 0;

  /// Updates the tracker with the current total bytes received/sent.
  /// Returns the smoothed speed in bytes/second.
  double update(int currentBytes) {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastTime).inMilliseconds;
    if (elapsedMs < 200) return _bytesPerSecond;

    final delta = currentBytes - _lastBytes;
    if (delta > 0) {
      final instantaneous = delta / (elapsedMs / 1000.0);
      _bytesPerSecond = _bytesPerSecond == 0
          ? instantaneous
          : _bytesPerSecond * 0.3 + instantaneous * 0.7;
    }
    _lastBytes = currentBytes;
    _lastTime = now;
    return _bytesPerSecond;
  }

  double get bytesPerSecond => _bytesPerSecond;

  String get formatted => formatSpeed(_bytesPerSecond);

  void reset() {
    _lastBytes = 0;
    _lastTime = DateTime.now();
    _bytesPerSecond = 0;
  }

  /// Formats bytes/second into a human-readable string.
  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    if (bytesPerSec < 1024) return '${bytesPerSec.round()} B/s';
    if (bytesPerSec < 1024 * 1024)
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSec < 1024 * 1024 * 1024)
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSec / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }
}
