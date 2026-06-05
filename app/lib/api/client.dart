import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../logger.dart';

enum SessionUnavailableKind { transient, expired }

/// API 在 401 且 refresh 未能恢复会话时抛出；区分网络暂不可用与会话失效。
class SessionUnavailableException implements Exception {
  final SessionUnavailableKind kind;
  final String message;

  const SessionUnavailableException(
    this.kind, [
    this.message = '会话不可用',
  ]);

  bool get isTransient => kind == SessionUnavailableKind.transient;
  bool get isExpired => kind == SessionUnavailableKind.expired;

  @override
  String toString() => message;
}

/// 启动/运行时 refresh 会话的结果。
enum RefreshSessionOutcome {
  success,
  transientFailure,
  permanentFailure,
  noRefreshToken,
}

extension RefreshSessionOutcomeX on RefreshSessionOutcome {
  bool get shouldClearAuth =>
      this == RefreshSessionOutcome.permanentFailure ||
      this == RefreshSessionOutcome.noRefreshToken;

  bool get shouldKeepSession =>
      this == RefreshSessionOutcome.success ||
      this == RefreshSessionOutcome.transientFailure;
}

enum RefreshSessionFailureKind { transient, permanent }

class RefreshTokenException implements Exception {
  final String message;
  final int? httpStatus;

  const RefreshTokenException(this.message, {this.httpStatus});

  @override
  String toString() => message;
}

/// 根据错误文案判断是否为会话/凭证失效（优先于 HTTP 5xx 的 transient 默认规则）。
bool isAuthSessionFailureMessage(String rawMessage) {
  final message = rawMessage.toLowerCase();
  if (message.contains('登录已失效') ||
      message.contains('登录已过期') ||
      message.contains('用户不存在') ||
      message.contains('jwt') ||
      message.contains('signature does not match') ||
      message.contains('cannot be asserted') ||
      message.contains('should not be trusted') ||
      message.contains('malformed') && message.contains('token') ||
      message.contains('invalid') && message.contains('token') ||
      message.contains('invalid') && message.contains('refresh') ||
      message.contains('expired') ||
      message.contains('refresh token') ||
      (message.contains('session') && message.contains('invalid'))) {
    return true;
  }
  return false;
}

/// 根据 refresh 失败原因区分临时网络问题与永久会话失效。
/// 优先看 HTTP 状态码；仅对旧服务端 5xx+JWT 文案保留 [isAuthSessionFailureMessage] 兜底。
RefreshSessionFailureKind classifyRefreshFailure(
  Object error, {
  int? httpStatus,
}) {
  if (error is TimeoutException) {
    return RefreshSessionFailureKind.transient;
  }
  if (error is SocketException || error is HttpException) {
    return RefreshSessionFailureKind.transient;
  }
  if (error is http.ClientException) {
    return RefreshSessionFailureKind.transient;
  }
  if (error is HandshakeException || error is TlsException) {
    return RefreshSessionFailureKind.transient;
  }

  if (httpStatus != null) {
    if (httpStatus == 401 || httpStatus == 403) {
      return RefreshSessionFailureKind.permanent;
    }
    if (httpStatus >= 400 && httpStatus < 500) {
      return RefreshSessionFailureKind.permanent;
    }
    if (httpStatus >= 500) {
      if (isAuthSessionFailureMessage(error.toString())) {
        return RefreshSessionFailureKind.permanent;
      }
      return RefreshSessionFailureKind.transient;
    }
  }

  if (isAuthSessionFailureMessage(error.toString())) {
    return RefreshSessionFailureKind.permanent;
  }

  final message = error.toString().toLowerCase();
  if (message.contains('failed host lookup') ||
      message.contains('connection timed out') ||
      message.contains('connection refused') ||
      message.contains('network is unreachable') ||
      message.contains('connection closed') ||
      message.contains('software caused connection abort') ||
      message.contains('operation timed out') ||
      message.contains('no route to host')) {
    return RefreshSessionFailureKind.transient;
  }

  return RefreshSessionFailureKind.transient;
}

RefreshSessionOutcome outcomeFromRefreshFailure(RefreshSessionFailureKind kind) {
  switch (kind) {
    case RefreshSessionFailureKind.transient:
      return RefreshSessionOutcome.transientFailure;
    case RefreshSessionFailureKind.permanent:
      return RefreshSessionOutcome.permanentFailure;
  }
}

String get apiBaseUrl => Env.apiUrl;

String? _accessToken;

Future<R> Function<R>(Future<R> Function())? _authRetryHandler;

void setAuthRetryHandler(
  Future<R> Function<R>(Future<R> Function() fn)? handler,
) {
  _authRetryHandler = handler;
}

void setAccessToken(String? token) {
  _accessToken = token;
}

class AuthException implements Exception {
  final String message;
  AuthException([this.message = '登录已过期，请重新登录']);
  @override
  String toString() => message;
}

Map<String, String> get apiHeaders => {
  'Content-Type': 'application/json',
  if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
};

/// 仅 Content-Type，**不要**带 [apiHeaders] 里的 Bearer。
/// 登录/注册等换票接口若仍附带已失效的旧 JWT，会先被 JwtAuthFilter 判 401，无法到达 AuthController。
const Map<String, String> jsonHeadersOnly = {
  'Content-Type': 'application/json',
};

bool get hasAccessToken => _accessToken != null;

/// 从失败响应体解析 Spring 返回的 `{"error":"..."}`，供未走 [checkAuthResponse] 的接口使用（如扫码轮询 GET）。
String errorMessageFromResponse(http.Response r, String fallback) {
  if (r.body.isEmpty) return fallback;
  try {
    final data = jsonDecode(r.body);
    if (data is Map && data['error'] != null) return data['error'].toString();
  } catch (_) {}
  return fallback;
}

/// 将 API 调用抛出的异常转为适合展示的短文案（含 [AuthException] 与 [Exception]）。
String formatApiError(Object e) {
  if (e is AuthException) return e.message;
  if (e is SessionUnavailableException) return e.message;
  return e.toString().replaceFirst('Exception: ', '');
}

void checkAuthResponse(http.Response r, {String fallback = '请求失败'}) {
  // 仅 401 视为会话失效。403 常见于业务/网关/对象存储「禁止访问」等，若当作登录失效会误触发清票与回首页。
  if (r.statusCode == 401) {
    logApi.warning('401 AuthException');
    String? bodyMsg;
    if (r.body.isNotEmpty) {
      try {
        final data = jsonDecode(r.body);
        if (data is Map && data['error'] != null) {
          final s = data['error'].toString();
          if (s.isNotEmpty && s != 'Unauthorized') {
            bodyMsg = s;
          }
        }
      } catch (_) {}
    }
    throw bodyMsg != null ? AuthException(bodyMsg) : AuthException();
  }
  if (r.statusCode < 200 || r.statusCode >= 300) {
    String msg = fallback;
    try {
      final data = jsonDecode(r.body);
      if (data is Map && data['error'] != null) msg = data['error'].toString();
    } catch (_) {}
    throw Exception(msg);
  }
}

/// 带 401 自动刷新并重试的请求封装，委托 [AuthSessionController.handle401WithRetry]。
Future<T> withAuthRetry<T>(Future<T> Function() fn) async {
  if (_authRetryHandler != null) {
    return _authRetryHandler!<T>(fn);
  }
  return fn();
}
