import 'dart:io';

import 'package:logging/logging.dart';

import 'share_inbound_payload.dart';
import 'share_ingest_pipeline.dart';

final Logger _logHub = Logger('虾传.share.hub');

/// Lightningvine-style routing: iOS always accepts attachments; Android multi only.
class ShareInboundHub {
  ShareInboundHub(this._ingestPipeline);

  final ShareIngestPipeline _ingestPipeline;

  Future<void> handlePayload(
    ShareInboundPayload payload, {
    required String source,
  }) async {
    final message = payload.content?.trim();
    if (message != null &&
        message.isNotEmpty &&
        !message.startsWith('content://')) {
      _logHub.info('$source: share text content (not ingested as file): $message');
    }

    final attachments =
        payload.attachments.where((a) => a.hasLocation).toList(growable: false);
    if (attachments.isEmpty) {
      _logHub.fine('$source: payload has no attachments');
      return;
    }

    final hasMultiFiles = attachments.length > 1;
    final accept = Platform.isIOS || hasMultiFiles;
    if (!accept) {
      _logHub.info(
        '$source: skip payload ingest on Android single attachment '
        '(count=${attachments.length}); use fl_shared_link single path',
      );
      return;
    }

    _logHub.info(
      '$source: accept payload source=${payload.source.name} '
      'attachments=${attachments.length}',
    );
    await _ingestPipeline.addAttachments(attachments, source: source);
  }

  Future<void> handleAndroidSingleFile(
    String path, {
    required String source,
  }) async {
    if (path.isEmpty) return;
    _logHub.info('$source: Android single file via fl_shared_link');
    await _ingestPipeline.addPaths([path], source: source);
  }
}
