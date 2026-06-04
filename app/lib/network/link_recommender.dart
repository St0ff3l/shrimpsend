import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_resolution.dart';
import 'link_models.dart';

/// 与 [linkRecommendationProvider] 同步的流，便于非 Widget 侧订阅。
final linkRecommendationStreamProvider = StreamProvider<LinkRecommendation?>((
  ref,
) {
  final controller = StreamController<LinkRecommendation?>.broadcast();
  ref.listen<LinkRecommendation?>(linkRecommendationProvider, (_, next) {
    if (!controller.isClosed) controller.add(next);
  }, fireImmediately: true);
  ref.onDispose(controller.close);
  return controller.stream;
});

/// 根据当前会话与可达性生成 [LinkRecommendation]。
LinkRecommendation buildLinkRecommendation({
  required SelectedConnectionContext context,
}) {
  final chain = context.chain;
  final primary = chain.isNotEmpty ? chain.first : SmartLinkKind.internetRelay;
  final lanOk = httpDirectAvailable(context.reach);
  final webrtcOk = context.reach.webrtc == true;
  final online = context.reach.isConfirmedOnline;

  // 已能局域网 HTTP：最优（绿色）
  if (lanOk) {
    return LinkRecommendation(
      primary: SmartLinkKind.sameLan,
      fallbackChain: chain,
      uiTone: SmartLinkUiTone.optimal,
      title: '局域网直连可用',
      subtitle: 'HTTP 局域网传输已就绪，通常为最快方式',
      lanHttpAvailable: true,
      webrtcAvailable: webrtcOk,
    );
  }

  // 仅在线链路可用
  if (online && !lanOk) {
    final title = webrtcOk ? '当前为 WebRTC / 云路径' : '当前为云中转路径';
    final subtitle = webrtcOk
        ? '未检测到局域网直连，可使用 WebRTC 或云中转继续发送'
        : '未检测到局域网直连，将走在线信令与中继';
    return LinkRecommendation(
      primary: SmartLinkKind.internetRelay,
      fallbackChain: chain,
      uiTone: SmartLinkUiTone.neutral,
      title: title,
      subtitle: subtitle,
      lanHttpAvailable: false,
      webrtcAvailable: webrtcOk,
    );
  }

  // 离线
  return LinkRecommendation(
    primary: primary,
    fallbackChain: chain,
    uiTone: SmartLinkUiTone.neutral,
    title: '未检测到对端直连',
    subtitle: '请确认对方在线或处于同一网络',
    lanHttpAvailable: false,
    webrtcAvailable: false,
  );
}

/// 当前会话的智能链路推荐（无会话或非设备会话时为 null）。
final linkRecommendationProvider = Provider<LinkRecommendation?>((ref) {
  final context = watchSelectedConnectionContext(ref);
  if (context == null) return null;
  return buildLinkRecommendation(context: context);
});
