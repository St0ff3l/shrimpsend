import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日志目录中的单个文件条目（供 UI 列表展示）。
class AppLogFileEntry {
  final String name;
  final String path;
  final int size;
  final DateTime modified;

  const AppLogFileEntry({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
  });
}

/// 将应用日志写入「应用支持目录/logs/」，与业务下载目录分离，便于排障与清理。
///
/// - `ultrasend.log`：当前主日志
/// - `ultrasend.1.log` / `ultrasend.2.log`：轮转保留
class AppLogFile {
  AppLogFile._();

  static final AppLogFile instance = AppLogFile._();

  static const _maxLogBytes = 1500000; // ~1.5MB 触发轮转

  bool _initialized = false;
  bool _available = false;
  String? _logsDir;
  String? _currentLogPath;

  bool get isAvailable => _available;

  String? get logsDirectoryPath => _logsDir;

  String? get currentLogFilePath => _currentLogPath;

  static const _logFileNames = [
    'ultrasend.log',
    'ultrasend.1.log',
    'ultrasend.2.log',
  ];

  /// 列出 logs 目录下存在的轮转日志文件（当前 → 历史）。
  Future<List<AppLogFileEntry>> listLogFiles() async {
    if (!_available || _logsDir == null) return const [];
    final out = <AppLogFileEntry>[];
    for (final name in _logFileNames) {
      final path = p.join(_logsDir!, name);
      try {
        final f = File(path);
        if (!await f.exists()) continue;
        final stat = await f.stat();
        out.add(
          AppLogFileEntry(
            name: name,
            path: path,
            size: stat.size,
            modified: stat.modified,
          ),
        );
      } catch (_) {}
    }
    return out;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final base = await getApplicationSupportDirectory();
      _logsDir = p.join(base.path, 'logs');
      await Directory(_logsDir!).create(recursive: true);
      _currentLogPath = p.join(_logsDir!, 'ultrasend.log');
      _available = true;
    } catch (_) {
      _available = false;
    }
  }

  void writeLine(String line) {
    if (!_available || _currentLogPath == null) return;
    try {
      final f = File(_currentLogPath!);
      if (f.existsSync() && f.lengthSync() > _maxLogBytes) {
        _rotateSync();
      }
      f.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  void _rotateSync() {
    final dir = _logsDir;
    final current = _currentLogPath;
    if (dir == null || current == null) return;
    final old1 = p.join(dir, 'ultrasend.1.log');
    final old2 = p.join(dir, 'ultrasend.2.log');
    try {
      if (File(old2).existsSync()) File(old2).deleteSync();
      if (File(old1).existsSync()) File(old1).renameSync(old2);
      if (File(current).existsSync()) File(current).renameSync(old1);
    } catch (_) {}
  }
}
