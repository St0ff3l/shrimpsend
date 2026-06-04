import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'share_inbound_hub.dart';
import 'share_inbound_payload.dart';

final Logger _logIosExt = Logger('虾传.share.ios_extension');

class IosShareExtensionAdapter {
  IosShareExtensionAdapter(this._hub);

  final ShareInboundHub _hub;

  Future<void> handleSharedFiles(
    List<SharedFile> files, {
    required String source,
  }) async {
    if (files.isEmpty) return;

    final attachments = <ShareAttachment>[];
    for (final file in files) {
      final value = file.value;
      if (value == null || value.isEmpty) continue;
      attachments.add(
        ShareAttachment(
          path: value,
          displayName: _displayNameForSharedFile(file, value),
        ),
      );
    }

    _logIosExt.info('$source: mapped ${attachments.length} attachment(s)');
    if (attachments.isEmpty) return;

    await _hub.handlePayload(
      ShareInboundPayload(
        attachments: attachments,
        source: ShareInboundSource.shareExtension,
      ),
      source: source,
    );
  }

  String _displayNameForSharedFile(SharedFile file, String path) {
    final fromPath = p.basename(path);
    if (fromPath.isNotEmpty) return fromPath;
    return 'shared_file';
  }
}
