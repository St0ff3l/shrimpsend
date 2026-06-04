import 'package:fl_shared_link/fl_shared_link.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../file_store.dart';
import 'share_inbound_hub.dart';
import 'share_inbound_payload.dart';

final Logger _logAndroidMulti = Logger('虾传.share.android_multi');

const _shareIntentChannel = MethodChannel('dev.ultrasend/share_intent');

class AndroidMultiUriAdapter {
  AndroidMultiUriAdapter(this._hub);

  final ShareInboundHub _hub;

  Future<void> handleSendMultiple({required String source}) async {
    final attachments = await resolveAttachments(source: source);
    if (attachments.isEmpty) return;
    await _hub.handlePayload(
      ShareInboundPayload(
        attachments: attachments,
        source: ShareInboundSource.androidMultiUri,
      ),
      source: '$source-multi',
    );
  }

  Future<List<ShareAttachment>> resolveAttachments({
    required String source,
  }) async {
    try {
      final cacheRoot = await FileStore.getCacheDir();
      final raw = await _shareIntentChannel.invokeMethod<List<dynamic>>(
        'resolveShareIntent',
        {'cacheRoot': cacheRoot},
      );
      final paths = raw
          ?.map((e) => e?.toString() ?? '')
          .where((path) => path.isNotEmpty)
          .toList();
      _logAndroidMulti.info(
        '$source: ShareIntentBridge -> ${paths?.length ?? 0} path(s)',
      );
      if (paths == null || paths.isEmpty) return const [];
      return paths
          .map(
            (path) => ShareAttachment(
              path: path,
              displayName: p.basename(path),
            ),
          )
          .toList(growable: false);
    } catch (e, st) {
      _logAndroidMulti.warning(
        '$source: ShareIntentBridge resolve failed: $e',
        e,
        st,
      );
      return const [];
    }
  }

  Future<String?> intentDedupeKey(AndroidIntentModel model) async {
    try {
      final key = await _shareIntentChannel.invokeMethod<String>(
        'getIntentDedupeKey',
      );
      if (key != null && key.isNotEmpty) return key;
    } catch (e, st) {
      _logAndroidMulti.fine('getIntentDedupeKey failed: $e', e, st);
    }
    final id = model.id;
    if (id == null || id.isEmpty) return null;
    return '${model.action}|$id';
  }
}

class FlSharedLinkAndroidAdapter {
  FlSharedLinkAndroidAdapter(this._hub);

  final ShareInboundHub _hub;

  Future<void> handleSingleIntent(
    AndroidIntentModel model, {
    required String source,
  }) async {
    final id = model.id;
    if (id == null || id.isEmpty) {
      _logAndroidMulti.warning(
        '$source: single-file intent missing id action=${model.action}',
      );
      return;
    }

    String? path;
    try {
      path = await FlSharedLink().getRealFilePathWithAndroid(id);
    } catch (e, st) {
      _logAndroidMulti.severe(
        '$source: getRealFilePathWithAndroid threw for id=$id: $e',
        e,
        st,
      );
    }
    _logAndroidMulti.info('$source: getRealFilePathWithAndroid(id=$id) -> $path');

    if (path == null || path.isEmpty) {
      _logAndroidMulti.warning(
        '$source: could not resolve single share path action=${model.action}',
      );
      return;
    }

    await _hub.handleAndroidSingleFile(path, source: source);
  }
}
