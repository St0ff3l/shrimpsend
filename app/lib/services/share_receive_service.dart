import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_shared_link/fl_shared_link.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_sharing_intent/flutter_sharing_intent.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:logging/logging.dart';

import 'share/android_multi_uri_adapter.dart';
import 'share/fl_shared_link_ios_adapter.dart';
import 'share/ios_share_extension_adapter.dart';
import 'share/share_inbound_hub.dart';
import 'share/share_ingest_pipeline.dart';
import 'share/share_pending_coordinator.dart';

final Logger _logShare = Logger('虾传.share');

/// Handles files shared to the app from the system share sheet (Android Intent / iOS Share Extension).
class ShareReceiveService {
  ShareReceiveService._();
  static final ShareReceiveService instance = ShareReceiveService._();

  late final SharePendingCoordinator _pending = SharePendingCoordinator();
  late final ShareIngestPipeline _ingestPipeline = ShareIngestPipeline(
    (saved, {required source}) => _pending.mergeAndNotify(saved, source: source),
  );
  late final ShareInboundHub _hub = ShareInboundHub(_ingestPipeline);
  late final AndroidMultiUriAdapter _androidMulti =
      AndroidMultiUriAdapter(_hub);
  late final FlSharedLinkAndroidAdapter _androidSingle =
      FlSharedLinkAndroidAdapter(_hub);
  late final IosShareExtensionAdapter _iosExtension =
      IosShareExtensionAdapter(_hub);
  late final FlSharedLinkIosAdapter _iosFlSharedLink =
      FlSharedLinkIosAdapter(_hub);

  StreamSubscription<List<SharedFile>>? _mediaSubscription;
  String? _lastAndroidDedupeKey;
  Future<void> _androidIngestQueue = Future<void>.value();

  void Function(int count, List<PlatformFile> files)? get onFilesSavedFromShare =>
      _pending.onFilesSavedFromShare;
  set onFilesSavedFromShare(
    void Function(int count, List<PlatformFile> files)? value,
  ) {
    _pending.onFilesSavedFromShare = value;
  }

  VoidCallback? get onPendingShareReady => _pending.onPendingShareReady;
  set onPendingShareReady(VoidCallback? value) {
    _pending.onPendingShareReady = value;
  }

  List<PlatformFile>? takePendingFromShare() => _pending.takePendingFromShare();

  void init() {
    _logShare.info('init platform=${Platform.operatingSystem}');
    if (Platform.isAndroid) {
      FlSharedLink().receiveHandler(onIntent: _onAndroidFlIntent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_androidColdStartIntent());
      });
      return;
    }
    _iosFlSharedLink.registerHandler();
    _mediaSubscription =
        FlutterSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (Object err, StackTrace? st) {
        _logShare.warning('getMediaStream error: $err', err, st);
      },
    );
    unawaited(_bootstrapIosSharing());
  }

  Future<void> _bootstrapIosSharing() async {
    await _consumeIosExtensionInitial();
    await _iosFlSharedLink.consumeColdStart();
    for (final delayMs in [300, 800]) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      await _consumeIosExtensionInitial();
    }
  }

  void dispose() {
    _logShare.info('dispose');
    if (Platform.isAndroid) {
      FlSharedLink().receiveHandler();
      return;
    }
    _mediaSubscription?.cancel();
    _mediaSubscription = null;
  }

  Future<void> _androidColdStartIntent() async {
    try {
      final model = await FlSharedLink().intentWithAndroid;
      if (model == null) {
        _logShare.fine('cold-start intentWithAndroid -> null (no share)');
      } else {
        _logShare.info('cold-start intentWithAndroid -> ${_describeIntent(model)}');
      }
      await _enqueueAndroidIngest(model, source: 'cold-start');
    } catch (e, st) {
      _logShare.warning('intentWithAndroid error: $e', e, st);
    }
  }

  Future<void> _onAndroidFlIntent(AndroidIntentModel? data) async {
    if (data == null) {
      _logShare.fine('onIntent -> null');
      return;
    }
    _logShare.info('onIntent -> ${_describeIntent(data)}');
    await _enqueueAndroidIngest(data, source: 'onIntent');
  }

  Future<void> _enqueueAndroidIngest(
    AndroidIntentModel? model, {
    required String source,
  }) {
    _androidIngestQueue = _androidIngestQueue.then(
      (_) => _maybeIngestAndroidIntent(model, source: source),
    );
    return _androidIngestQueue;
  }

  String _describeIntent(AndroidIntentModel m) {
    return 'action=${m.action} type=${m.type} scheme=${m.scheme} '
        'authority=${m.authority} url=${m.url} id=${m.id} '
        'extras=${m.extras?.keys.toList()}';
  }

  Future<void> _maybeIngestAndroidIntent(
    AndroidIntentModel? model, {
    required String source,
  }) async {
    if (model == null) return;
    final action = model.action;
    if (action != AndroidAction.send &&
        action != AndroidAction.sendMultiple &&
        action != AndroidAction.view) {
      _logShare.fine('$source: ignore non-share action=$action');
      return;
    }

    final dedupeKey = await _androidMulti.intentDedupeKey(model);
    if (dedupeKey == null || dedupeKey.isEmpty) {
      _logShare.warning(
        '$source: could not build dedupe key; intent=${_describeIntent(model)}',
      );
      return;
    }
    if (_lastAndroidDedupeKey == dedupeKey) {
      _logShare.info('$source: skip duplicate android share key=$dedupeKey');
      return;
    }
    _lastAndroidDedupeKey = dedupeKey;

    try {
      if (action == AndroidAction.sendMultiple) {
        await _androidMulti.handleSendMultiple(source: source);
      } else {
        await _androidSingle.handleSingleIntent(model, source: source);
      }
      await _clearAndroidDedupeKeyLater(dedupeKey);
      await FlSharedLink().clearCache();
    } catch (e, st) {
      _logShare.warning('$source: android ingest failed: $e', e, st);
      if (_lastAndroidDedupeKey == dedupeKey) {
        _lastAndroidDedupeKey = null;
      }
    }
  }

  Future<void> _clearAndroidDedupeKeyLater(String dedupeKey) async {
    await Future<void>.delayed(const Duration(seconds: 2), () {
      if (_lastAndroidDedupeKey == dedupeKey) {
        _lastAndroidDedupeKey = null;
      }
    });
  }

  Future<void> _consumeIosExtensionInitial() async {
    try {
      final list = await FlutterSharingIntent.instance.getInitialSharing();
      _logShare.info('getInitialSharing -> ${list.length} file(s)');
      if (list.isNotEmpty) {
        await _iosExtension.handleSharedFiles(list, source: 'ios-initial');
        FlutterSharingIntent.instance.reset();
      }
    } catch (e, st) {
      _logShare.warning('getInitialSharing error: $e', e, st);
    }
  }

  Future<void> _handleSharedMedia(List<SharedFile> value) async {
    _logShare.info('getMediaStream event -> ${value.length} file(s)');
    if (value.isEmpty) return;
    await _iosExtension.handleSharedFiles(value, source: 'ios-stream');
    FlutterSharingIntent.instance.reset();
  }
}
