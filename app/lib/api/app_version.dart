import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/app_update_service.dart';
import 'client.dart';

/// Fetches enabled version history (newest first). Empty list on error or 404.
Future<List<UpdateInfo>> fetchVersionHistory() async {
  try {
    final uri = Uri.parse('$apiBaseUrl/api/app/versions');
    final response = await http.get(uri).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('请求超时'),
    );
    if (response.statusCode != 200) return [];
    if (response.body.isEmpty || !response.body.trim().startsWith('[')) return [];
    final list = jsonDecode(response.body) as List<dynamic>?;
    if (list == null) return [];
    final result = <UpdateInfo>[];
    for (final e in list) {
      final info = UpdateInfo.fromJson(Map<String, dynamic>.from(e as Map));
      if (info != null) result.add(info);
    }
    return result;
  } catch (_) {
    return [];
  }
}
