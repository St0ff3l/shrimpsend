import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_update_service.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService.instance;
});

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});
