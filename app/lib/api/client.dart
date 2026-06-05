import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../logger.dart';

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

/// 根据 refresh 失败原因区分临时网络问题与永久会话失效。
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
    if (httpStatus >= 500) return RefreshSessionFailureKind.transient;
    if (httpStatus == 401 || httpStatus == 403) {
      return RefreshSessionFailureKind.permanent;
    }
    if (httpStatus >= 400 && httpStatus < 500) {
      return RefreshSessionFailureKind.permanent;
    }
  }

  final message = error.toString().toLowerCase();
  if (message.contains('登录已失效') ||
      message.contains('用户不存在') ||
      message.contains('invalid') && message.contains('token') ||
      message.contains('expired')) {
    return RefreshSessionFailureKind.permanent;
  }

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

Future<RefreshSessionOutcome> Function()? _on401Refresh;

void setOn401Refresh(Future<RefreshSessionOutcome> Function()? callback) {
  _on401Refresh = callback;
}

/// 刷新 token 仍失败时调用（如设备被踢）：用于清本地登录态并跳转登录页。
Future<void> Function()? _onSessionInvalidated;

void setOnSessionInvalidated(Future<void> Function()? callback) {
  _onSessionInvalidated = callback;
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

/// 带 401 自动刷新并重试的请求封装：先执行 [fn]；若抛出 [AuthException] 则调用 _on401Refresh，成功则重试一次。
/// 若重试仍 401，与刷新失败同等处理（清会话后 rethrow），避免静默二次 401。
Future<T> withAuthRetry<T>(Future<T> Function() fn) async {
  try {
    return await fn();
  } on AuthException catch (_) {
    logApi.info('withAuthRetry: auth failed, attempting refresh');
    if (_on401Refresh != null) {
      final outcome = await _on401Refresh!();
      if (outcome == RefreshSessionOutcome.success) {
        logApi.info('withAuthRetry: refresh ok, retrying');
        try {
          return await fn();
        } on AuthException catch (_) {
          logApi.warning('withAuthRetry: still 401 after refresh, invalidating session');
          await _runOnSessionInvalidated();
          rethrow;
        }
      }
      if (outcome == RefreshSessionOutcome.transientFailure) {
        logApi.warning(
          'withAuthRetry: transient refresh failure, keeping session',
        );
        rethrow;
      }
    }
    await _runOnSessionInvalidated();
    logApi.warning('withAuthRetry: rethrowing');
    rethrow;
  }
}

Future<void> _runOnSessionInvalidated() async {
  if (_onSessionInvalidated != null) {
    try {
      await _onSessionInvalidated!();
    } catch (e, st) {
      logApi.warning('onSessionInvalidated failed: $e\n$st');
    }
  }
}
