import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'client.dart';

class UserProfile {
  final String userId;
  final String email;
  final String username;

  UserProfile({
    required this.userId,
    required this.email,
    required this.username,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    userId: j['userId'] as String,
    email: j['email'] as String,
    username: (j['username'] as String?) ?? '',
  );
}

Future<UserProfile> fetchUserProfile() async {
  return withAuthRetry(() async {
    logApi.info('fetchUserProfile');
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/user/profile'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取用户信息失败');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    logApi.info('fetchUserProfile success userId=${data['userId']}');
    return UserProfile.fromJson(data);
  });
}

Future<void> sendChangePasswordCode() async {
  return withAuthRetry(() async {
    logApi.info('sendChangePasswordCode');
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/user/send-change-password-code'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '发送验证码失败');
    logApi.info('sendChangePasswordCode success');
  });
}

Future<void> changePassword({
  required String code,
  required String newPassword,
}) async {
  return withAuthRetry(() async {
    logApi.info('changePassword');
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/user/change-password'),
      headers: apiHeaders,
      body: jsonEncode({
        'code': code,
        'newPassword': newPassword,
      }),
    );
    checkAuthResponse(r, fallback: '修改密码失败');
    logApi.info('changePassword success');
  });
}

Future<void> sendDeleteAccountCode() async {
  return withAuthRetry(() async {
    logApi.info('sendDeleteAccountCode');
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/user/send-delete-code'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '发送验证码失败');
    logApi.info('sendDeleteAccountCode success');
  });
}

Future<void> confirmDeleteAccount(String code) async {
  return withAuthRetry(() async {
    logApi.info('confirmDeleteAccount');
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/user/confirm-delete-account'),
      headers: apiHeaders,
      body: jsonEncode({'code': code}),
    );
    checkAuthResponse(r, fallback: '删除账户失败');
    logApi.info('confirmDeleteAccount success');
  });
}
