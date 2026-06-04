import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// 与 chat 选图器一致的读权限请求选项（图 + 视频）。
const galleryReadPermissionOption = PermissionRequestOption(
  androidPermission: AndroidPermission(
    type: RequestType.common,
    mediaLocation: false,
  ),
);

/// 相册读权限是否已完整授权（非 limited / denied）。
bool isGalleryReadFullyAuthorized(PermissionState state) {
  return state == PermissionState.authorized;
}

/// 查询当前相册读权限状态（不弹系统授权框）。
Future<PermissionState> getGalleryReadPermissionState() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return PermissionState.authorized;
  }
  return PhotoManager.getPermissionState(
    requestOption: galleryReadPermissionOption,
  );
}

/// 请求相册读权限（弹系统授权框），返回最终状态。
///
/// Android 上若设置页已通过 [permission_handler] 仅授予图片读权限，
/// [PhotoManager.requestPermissionExtend] 会因已有部分权限而跳过系统弹窗；
/// 此时会额外请求 [Permission.videos] 以补全视频读权限。
Future<PermissionState> requestGalleryReadPermission() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return PermissionState.authorized;
  }

  var state = await PhotoManager.requestPermissionExtend(
    requestOption: galleryReadPermissionOption,
  );

  if (Platform.isAndroid && !isGalleryReadFullyAuthorized(state)) {
    state = await _upgradeAndroidGalleryReadPermission();
  }

  return state;
}

/// 修复 Android 上因设置页仅授予图片读权限而导致的 [PermissionState.limited]。
Future<PermissionState> repairGalleryReadPermissionIfNeeded(
  PermissionState state,
) async {
  if (!Platform.isAndroid ||
      isGalleryReadFullyAuthorized(state) ||
      state != PermissionState.limited) {
    return state;
  }
  return _upgradeAndroidGalleryReadPermission();
}

Future<PermissionState> _upgradeAndroidGalleryReadPermission() async {
  final state = await getGalleryReadPermissionState();
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  if (androidInfo.version.sdkInt < 33) {
    return state;
  }

  var photosStatus = await Permission.photos.status;
  var videosStatus = await Permission.videos.status;

  if (!videosStatus.isGranted && !videosStatus.isPermanentlyDenied) {
    videosStatus = await Permission.videos.request();
  }
  if (!photosStatus.isGranted &&
      !photosStatus.isLimited &&
      !photosStatus.isPermanentlyDenied) {
    photosStatus = await Permission.photos.request();
  }

  return getGalleryReadPermissionState();
}

/// 请求「保存到相册」所需的权限。
/// 仅移动端需要；桌面端直接返回 true。
/// 返回 true 表示已授权，false 表示未授权（用户拒绝或不可用）。
Future<bool> requestSaveToGalleryPermission() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return true;
  }
  if (Platform.isIOS) {
    final permission = Permission.photosAddOnly;
    var status = await permission.status;
    if (status.isGranted) return true;
    if (!status.isPermanentlyDenied && !status.isRestricted) {
      status = await permission.request();
      return status.isGranted;
    }
    return false;
  }
  // Android：API 29+ 通过 MediaStore 写入相册，无需读媒体权限。
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final sdkInt = androidInfo.version.sdkInt;
  if (sdkInt >= 29) {
    return true;
  }
  final permission = Permission.storage;
  var status = await permission.status;
  if (status.isGranted) return true;
  if (status.isDenied) {
    final requested = await permission.request();
    return requested.isGranted;
  }
  if (status.isPermanentlyDenied) {
    return false;
  }
  return false;
}

/// 相册保存权限是否已被永久拒绝或受限（需引导用户前往系统设置）。
Future<bool> isSaveToGalleryPermissionBlocked() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return false;
  }
  if (Platform.isIOS) {
    final status = await Permission.photosAddOnly.status;
    return status.isPermanentlyDenied || status.isRestricted;
  }
  final androidInfo = await DeviceInfoPlugin().androidInfo;
  if (androidInfo.version.sdkInt >= 29) {
    return false;
  }
  final permission = Permission.storage;
  final status = await permission.status;
  return status.isPermanentlyDenied || status.isRestricted;
}

/// 请求「选择文件夹 / 保存路径」所需的存储权限。
/// Android 通过 SAF（系统目录选择器）选目录，无需 broad storage 权限。
Future<bool> requestFolderAccessPermission() async {
  return true;
}
