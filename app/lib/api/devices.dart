import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'client.dart';

class DeviceDto {
  /// Server-assigned 1–999 display number per user; null for LAN-only rows.
  final int? displayCode;
  final String deviceId;
  final String name;
  final String? platform;
  final String? lanHttpUrl;
  final String? presenceStatus;
  final int? presenceUpdatedAt;

  /// Epoch millis; null if never seen. Used to show online (e.g. within last 2 min).
  final int? lastSeen;
  DeviceDto({
    this.displayCode,
    required this.deviceId,
    required this.name,
    this.platform,
    this.lanHttpUrl,
    this.presenceStatus,
    this.presenceUpdatedAt,
    this.lastSeen,
  });
  factory DeviceDto.fromJson(Map<String, dynamic> j) => DeviceDto(
    displayCode: _readOptionalInt(j['displayCode'] ?? j['display_code']),
    deviceId: j['deviceId'] as String,
    name: j['name'] as String,
    platform: j['platform'] as String?,
    lanHttpUrl: j['lanHttpUrl'] as String?,
    presenceStatus: j['presenceStatus'] as String?,
    presenceUpdatedAt: j['presenceUpdatedAt'] is int
        ? j['presenceUpdatedAt'] as int
        : null,
    lastSeen: j['lastSeen'] is int ? j['lastSeen'] as int : null,
  );

  static int? _readOptionalInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  bool get isWeb => platform == 'web';
}

Future<List<DeviceDto>> listDevices() async {
  logApi.info('listDevices');
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/devices'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取设备列表失败');
    final list = (jsonDecode(r.body) as List)
        .map((e) => DeviceDto.fromJson(e as Map<String, dynamic>))
        .toList();
    logApi.info('listDevices success count=${list.length}');
    return list;
  });
}

Future<DeviceDto> registerDevice(
  String deviceId,
  String name, {
  String? lanHttpUrl,
  String? platform,
  String? sessionId,
}) async {
  logApi.info('registerDevice deviceId=$deviceId');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/devices'),
      headers: apiHeaders,
      body: jsonEncode({
        'deviceId': deviceId,
        'name': name,
        if (lanHttpUrl != null) 'lanHttpUrl': lanHttpUrl,
        if (platform != null) 'platform': platform,
        if (sessionId != null) 'sessionId': sessionId,
      }),
    );
    checkAuthResponse(r, fallback: '设备注册失败');
    final dto = DeviceDto.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    logApi.info('registerDevice success deviceId=${dto.deviceId}');
    return dto;
  });
}

Future<DeviceDto> updateDevicePresence(
  String deviceId, {
  required String sessionId,
  required String status,
  String? platform,
}) async {
  logApi.info('updateDevicePresence deviceId=$deviceId status=$status');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}/presence'),
      headers: apiHeaders,
      body: jsonEncode({
        'sessionId': sessionId,
        'status': status,
        if (platform != null) 'platform': platform,
      }),
    );
    checkAuthResponse(r, fallback: '更新设备在线状态失败');
    return DeviceDto.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  });
}

Future<void> deleteDevice(String deviceId) async {
  logApi.info('deleteDevice deviceId=$deviceId');
  return withAuthRetry(() async {
    final r = await http.delete(
      Uri.parse('$apiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '删除设备失败');
    logApi.info('deleteDevice success deviceId=$deviceId');
  });
}

Future<DeviceDto> updateDevice(
  String deviceId, {
  String? name,
  String? lanHttpUrl,
}) async {
  logApi.info('updateDevice deviceId=$deviceId');
  return withAuthRetry(() async {
    final r = await http.patch(
      Uri.parse('$apiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}'),
      headers: apiHeaders,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (lanHttpUrl != null) 'lanHttpUrl': lanHttpUrl,
      }),
    );
    checkAuthResponse(r, fallback: '更新设备失败');
    return DeviceDto.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  });
}
