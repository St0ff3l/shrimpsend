import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'client.dart';

class CentrifugoTokenResponse {
  final String connectionToken;
  final String subscriptionToken;
  final String channel;
  CentrifugoTokenResponse({
    required this.connectionToken,
    required this.subscriptionToken,
    required this.channel,
  });
  factory CentrifugoTokenResponse.fromJson(Map<String, dynamic> j) =>
      CentrifugoTokenResponse(
        connectionToken: j['connectionToken'] as String,
        subscriptionToken: j['subscriptionToken'] as String,
        channel: j['channel'] as String,
      );
}

Future<CentrifugoTokenResponse> getCentrifugoToken() async {
  logApi.info('getCentrifugoToken');
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/centrifugo/token'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取连接凭证失败');
    final res = CentrifugoTokenResponse.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
    logApi.info('getCentrifugoToken success channel=${res.channel}');
    return res;
  });
}
