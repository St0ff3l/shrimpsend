import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'client.dart';

class MessageEnvelope {
  final String type;
  final dynamic payload;
  final String fromDeviceId;
  final int ts;
  final int? id;
  final String? localId;
  /// Optional: directed delivery / filtering for realtime.
  final String? toDeviceId;
  /// Canonical conversation key (see `chat/thread_key.dart`).
  final String? threadKey;

  MessageEnvelope({
    required this.type,
    required this.payload,
    required this.fromDeviceId,
    required this.ts,
    this.id,
    this.localId,
    this.toDeviceId,
    this.threadKey,
  });

  factory MessageEnvelope.fromJson(Map<String, dynamic> j) {
    final tsVal = j['ts'];
    final idVal = j['id'];
    final ts = tsVal is num
        ? tsVal.toInt()
        : int.tryParse(tsVal?.toString() ?? '') ?? 0;
    final id = idVal == null
        ? null
        : (idVal is num ? idVal.toInt() : int.tryParse(idVal.toString()));
    return MessageEnvelope(
      type: j['type']?.toString() ?? '',
      payload: j['payload'],
      fromDeviceId: j['fromDeviceId']?.toString() ?? '',
      ts: ts,
      id: id,
      toDeviceId: j['toDeviceId']?.toString(),
      threadKey: j['threadKey']?.toString(),
    );
  }
}

/// Fetches message history (newest first). [before] is message id for cursor.
Future<List<MessageEnvelope>> getMessageHistory({
  int limit = 50,
  int? before,
  String? threadKey,
}) async {
  logApi.info('getMessageHistory limit=$limit before=$before threadKey=$threadKey');
  return withAuthRetry(() async {
    final query = <String, String>{'limit': limit.toString()};
    if (before != null && before > 0) query['before'] = before.toString();
    if (threadKey != null && threadKey.isNotEmpty) {
      query['threadKey'] = threadKey;
    }
    final uri = Uri.parse(
      '$apiBaseUrl/api/messages/history',
    ).replace(queryParameters: query);
    final r = await http.get(uri, headers: apiHeaders);
    checkAuthResponse(r, fallback: '加载历史失败');
    final list = (jsonDecode(r.body) as List)
        .map((e) => MessageEnvelope.fromJson((e as Map<String, dynamic>)))
        .toList();
    logApi.info('getMessageHistory success count=${list.length}');
    return list;
  });
}

Future<void> deleteMessage(int messageId) async {
  logApi.info('deleteMessage id=$messageId');
  return withAuthRetry(() async {
    final r = await http.delete(
      Uri.parse('$apiBaseUrl/api/messages/$messageId'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '删除失败');
    logApi.fine('deleteMessage ok id=$messageId');
  });
}

Future<void> deleteThreadMessages(String threadKey) async {
  logApi.info('deleteThreadMessages threadKey=$threadKey');
  return withAuthRetry(() async {
    final uri = Uri.parse('$apiBaseUrl/api/messages/thread').replace(
      queryParameters: {'threadKey': threadKey},
    );
    final r = await http.delete(uri, headers: apiHeaders);
    checkAuthResponse(r, fallback: '清空消息失败');
    logApi.fine('deleteThreadMessages ok threadKey=$threadKey');
  });
}

Future<void> sendMessage(Map<String, dynamic> data) async {
  final type = data['type'];
  final fromDeviceId = data['fromDeviceId'];
  logApi.info('sendMessage type=$type fromDeviceId=$fromDeviceId');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/messages/send'),
      headers: apiHeaders,
      body: jsonEncode({'data': data}),
    );
    checkAuthResponse(r, fallback: '发送失败');
    if (r.statusCode != 204) {
      throw Exception(r.body.isNotEmpty ? r.body : '发送失败');
    }
    logApi.fine('sendMessage ok');
  });
}
