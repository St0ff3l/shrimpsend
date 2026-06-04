import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'client.dart';

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;
  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });
  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    userId: j['userId'] as String,
  );
}

Future<AuthResponse> login(
  String email,
  String password, {
  required String deviceId,
  String? platform,
}) async {
  logApi.info('login attempt email=${email.trim().toLowerCase()}');
  final r = await http.post(
    Uri.parse('$apiBaseUrl/api/auth/login'),
    headers: jsonHeadersOnly,
    body: jsonEncode({
      'email': email.trim().toLowerCase(),
      'password': password,
      'deviceId': deviceId,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
    }),
  );
  logApi.info('login response status=${r.statusCode} bodyLen=${r.body.length}');
  if (r.statusCode != 200) {
    String msg = '登录失败 (${r.statusCode})';
    if (r.body.isNotEmpty) {
      try {
        final err = jsonDecode(r.body) as Map?;
        if (err?['error'] != null) msg = err!['error'].toString();
      } catch (_) {}
    }
    logApi.warning('login failed: $msg');
    throw Exception(msg);
  }
  if (r.body.isEmpty) {
    logApi.warning('login failed: empty response body');
    throw Exception('服务器返回空响应，请检查后端服务');
  }
  final res = AuthResponse.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  logApi.info('login success userId=${res.userId}');
  return res;
}

Future<void> sendVerificationCode(
  String email, {
  String? type,
  String? deviceId,
  String? platform,
}) async {
  logApi.info('sendVerificationCode email=${email.trim().toLowerCase()} type=$type');
  final body = <String, dynamic>{'email': email.trim().toLowerCase()};
  if (type != null && type.isNotEmpty) body['type'] = type;
  if (deviceId != null && deviceId.isNotEmpty) body['deviceId'] = deviceId;
  if (platform != null && platform.isNotEmpty) body['platform'] = platform;
  final r = await http.post(
    Uri.parse('$apiBaseUrl/api/auth/send-code'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (r.statusCode != 200) {
    String msg = '发送验证码失败 (${r.statusCode})';
    if (r.body.isNotEmpty) {
      try {
        final err = jsonDecode(r.body) as Map?;
        if (err?['error'] != null) msg = err!['error'].toString();
      } catch (_) {}
    }
    logApi.warning('sendVerificationCode failed: $msg');
    throw Exception(msg);
  }
  logApi.info('sendVerificationCode success');
}

Future<AuthResponse> loginByCode(
  String email,
  String code, {
  required String deviceId,
  String? platform,
}) async {
  logApi.info('loginByCode attempt email=${email.trim().toLowerCase()}');
  final r = await http.post(
    Uri.parse('$apiBaseUrl/api/auth/login-by-code'),
    headers: jsonHeadersOnly,
    body: jsonEncode({
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'deviceId': deviceId,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
    }),
  );
  logApi.info('loginByCode response status=${r.statusCode} bodyLen=${r.body.length}');
  if (r.statusCode != 200) {
    String msg = '验证码登录失败 (${r.statusCode})';
    if (r.body.isNotEmpty) {
      try {
        final err = jsonDecode(r.body) as Map?;
        if (err?['error'] != null) msg = err!['error'].toString();
      } catch (_) {}
    }
    logApi.warning('loginByCode failed: $msg');
    throw Exception(msg);
  }
  if (r.body.isEmpty) {
    logApi.warning('loginByCode failed: empty response body');
    throw Exception('服务器返回空响应，请检查后端服务');
  }
  final res = AuthResponse.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  logApi.info('loginByCode success userId=${res.userId}');
  return res;
}

Future<AuthResponse> register(
  String email,
  String password,
  String code, {
  String? username,
  required String deviceId,
  String? platform,
}) async {
  logApi.info('register attempt email=${email.trim().toLowerCase()}');
  final body = <String, dynamic>{
    'email': email.trim().toLowerCase(),
    'password': password,
    'code': code,
    'deviceId': deviceId,
    if (platform != null && platform.isNotEmpty) 'platform': platform,
  };
  if (username != null && username.trim().isNotEmpty)
    body['username'] = username.trim();
  final r = await http.post(
    Uri.parse('$apiBaseUrl/api/auth/register'),
    headers: jsonHeadersOnly,
    body: jsonEncode(body),
  );
  logApi.info(
    'register response status=${r.statusCode} bodyLen=${r.body.length}',
  );
  if (r.statusCode != 200) {
    String msg = '注册失败 (${r.statusCode})';
    if (r.body.isNotEmpty) {
      try {
        final err = jsonDecode(r.body) as Map?;
        if (err?['error'] != null) msg = err!['error'].toString();
      } catch (_) {}
    }
    logApi.warning('register failed: $msg');
    throw Exception(msg);
  }
  if (r.body.isEmpty) {
    logApi.warning('register failed: empty response body');
    throw Exception('服务器返回空响应，请检查后端服务');
  }
  final res = AuthResponse.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  logApi.info('register success userId=${res.userId}');
  return res;
}

class QrStatusResponse {
  final String status;
  final String? accessToken;
  final String? refreshToken;
  final String? userId;
  QrStatusResponse({
    required this.status,
    this.accessToken,
    this.refreshToken,
    this.userId,
  });
  factory QrStatusResponse.fromJson(Map<String, dynamic> j) => QrStatusResponse(
    status: j['status'] as String,
    accessToken: j['accessToken'] as String?,
    refreshToken: j['refreshToken'] as String?,
    userId: j['userId'] as String?,
  );
}

Future<String> createQrSession() async {
  logApi.info('createQrSession');
  final r = await http.post(
    Uri.parse('$apiBaseUrl/api/auth/qr/create'),
    headers: {'Content-Type': 'application/json'},
  );
  if (r.statusCode != 200) {
    throw Exception('创建二维码失败 (${r.statusCode})');
  }
  final data = jsonDecode(r.body) as Map<String, dynamic>;
  logApi.info('createQrSession success sessionId=${data['sessionId']}');
  return data['sessionId'] as String;
}

Future<QrStatusResponse> getQrStatus(
  String sessionId, {
  required String deviceId,
  String? platform,
}) async {
  final qp = <String, String>{'deviceId': deviceId};
  if (platform != null && platform.isNotEmpty) {
    qp['platform'] = platform;
  }
  final uri = Uri.parse('$apiBaseUrl/api/auth/qr/status/$sessionId').replace(
    queryParameters: qp,
  );
  final r = await http.get(uri);
  if (r.statusCode != 200) {
    throw Exception(
      errorMessageFromResponse(r, '查询状态失败 (${r.statusCode})'),
    );
  }
  return QrStatusResponse.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
}

Future<void> scanQrSession(String sessionId) async {
  await withAuthRetry(() async {
    logApi.info('scanQrSession sessionId=$sessionId');
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/qr/scan'),
      headers: apiHeaders,
      body: jsonEncode({'sessionId': sessionId}),
    );
    checkAuthResponse(r, fallback: '扫码失败');
    logApi.info('scanQrSession success');
  });
}

Future<void> confirmQrLogin(String sessionId) async {
  await withAuthRetry(() async {
    logApi.info('confirmQrLogin sessionId=$sessionId');
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/qr/confirm'),
      headers: apiHeaders,
      body: jsonEncode({'sessionId': sessionId}),
    );
    checkAuthResponse(r, fallback: '确认登录失败');
    logApi.info('confirmQrLogin success');
  });
}

Future<void> cancelQrLogin(String sessionId) async {
  await withAuthRetry(() async {
    logApi.info('cancelQrLogin sessionId=$sessionId');
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/qr/cancel'),
      headers: apiHeaders,
      body: jsonEncode({'sessionId': sessionId}),
    );
    checkAuthResponse(r, fallback: '取消失败');
    logApi.info('cancelQrLogin success');
  });
}

Future<void> apiLogout({String? deviceId}) async {
  logApi.info('apiLogout deviceId=$deviceId');
  try {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/logout'),
      headers: apiHeaders,
      body: jsonEncode({'deviceId': deviceId}),
    );
    logApi.info('apiLogout response status=${r.statusCode}');
  } catch (e) {
    logApi.warning('apiLogout failed: $e');
  }
}

Future<AuthResponse> refreshTokens(String refreshToken) async {
  logApi.info('refreshTokens');
  final r = await http.post(
    Uri.parse('$apiBaseUrl/api/auth/refresh'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'refreshToken': refreshToken}),
  );
  if (r.statusCode != 200) {
    try {
      final data = jsonDecode(r.body);
      if (data is Map && data['error'] != null) {
        logApi.warning('refreshTokens failed: ${data['error']}');
        throw Exception(data['error'].toString());
      }
    } catch (e) {
      if (e is Exception) rethrow;
    }
    logApi.warning('refreshTokens failed');
    throw Exception('刷新失败');
  }
  final res = AuthResponse.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  logApi.info('refreshTokens success userId=${res.userId}');
  return res;
}
