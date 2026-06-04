import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'services/app_log_file.dart';

/// Root logger name for app.
const String _rootName = '虾传';

final Logger logApi = Logger('$_rootName.api');
final Logger logAuth = Logger('$_rootName.auth');
final Logger logChat = Logger('$_rootName.chat');
final Logger logDevices = Logger('$_rootName.devices');
final Logger logSettings = Logger('$_rootName.settings');
final Logger logUpdate = Logger('$_rootName.update');
final Logger logBoot = Logger('$_rootName.boot');

/// Call from main() after [AppLogFile.instance.init] to wire Logger output to debugPrint and log file.
void initLogging() {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((LogRecord r) {
    final line = '[虾传][${r.loggerName}] ${r.level.name}: ${r.message}';
    if (r.error != null) {
      debugPrint('$line\n${r.error}');
    } else {
      debugPrint(line);
    }
    final ts = r.time.toIso8601String();
    var fileLine = '[$ts][虾传][${r.loggerName}] ${r.level.name}: ${r.message}';
    if (r.error != null) {
      fileLine = '$fileLine\n${r.error}';
    }
    if (r.stackTrace != null) {
      fileLine = '$fileLine\n${r.stackTrace}';
    }
    AppLogFile.instance.writeLine(fileLine);
  });
}
