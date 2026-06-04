import 'dart:async';

import 'package:fl_shared_link/fl_shared_link.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'share_inbound_hub.dart';
import 'share_inbound_payload.dart';

final Logger _logFlIos = Logger('虾传.share.fl_ios');

class FlSharedLinkIosAdapter {
  FlSharedLinkIosAdapter(this._hub);

  final ShareInboundHub _hub;
  bool _handlerRegistered = false;

  void registerHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    FlSharedLink().receiveHandler(
      onOpenUrl: (data) {
        unawaited(_handleOpenUrl(data, source: 'onOpenUrl'));
      },
      onUniversalLink: (data) {
        unawaited(_handleUniversalLink(data, source: 'onUniversalLink'));
      },
    );
  }

  Future<void> consumeColdStart() async {
    registerHandler();
    await _handleOpenUrl(await FlSharedLink().openUrlWithIOS, source: 'openUrl-cold');
    await _handleUniversalLink(
      await FlSharedLink().universalLinkWithIOS,
      source: 'universalLink-cold',
    );
  }

  Future<void> _handleOpenUrl(IOSOpenUrlModel? data, {required String source}) async {
    if (data == null) return;
    if (_isShareExtensionHandoff(data.scheme, data.url)) {
      _logFlIos.fine('$source: skip SharingMedia handoff (Share Extension)');
      return;
    }
    await _ingestIosModel(data, source: source);
  }

  Future<void> _handleUniversalLink(
    IOSUniversalLinkModel? data, {
    required String source,
  }) async {
    if (data == null) return;
    await _ingestIosModel(data, source: source);
  }

  bool _isShareExtensionHandoff(String? scheme, String? url) {
    if (scheme != null && scheme.startsWith('SharingMedia-')) return true;
    if (url != null && url.contains('SharingMedia-')) return true;
    return false;
  }

  Future<void> _ingestIosModel(BaseReceiveData data, {required String source}) async {
    final id = data.id;
    if (id == null || id.isEmpty) {
      _logFlIos.fine('$source: no id in fl_shared_link iOS payload');
      return;
    }

    String? path;
    try {
      path = await FlSharedLink().externalFileCopyWithIOS(id);
    } catch (e, st) {
      _logFlIos.warning('$source: externalFileCopyWithIOS failed: $e', e, st);
    }
    path ??= await FlSharedLink().getAbsolutePathWithIOS(data.url ?? id);

    if (path == null || path.isEmpty) {
      _logFlIos.warning('$source: could not resolve iOS shared path id=$id');
      return;
    }

    final displayName = p.basename(path);
    await _hub.handlePayload(
      ShareInboundPayload(
        attachments: [
          ShareAttachment(
            path: path,
            uri: data.url,
            displayName: displayName.isNotEmpty ? displayName : 'shared_file',
          ),
        ],
        source: ShareInboundSource.flSharedLink,
      ),
      source: source,
    );

    try {
      await FlSharedLink().clearCache();
    } catch (e, st) {
      _logFlIos.warning('clearCache: $e', e, st);
    }
  }
}
