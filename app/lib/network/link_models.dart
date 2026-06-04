/// Smart Link shared models (L1 链路层).
library;

/// 推荐的物理链路策略（不含 L2 传输协议）。
enum SmartLinkKind {
  /// 双方已在同一局域网（mDNS / HTTP 可达）。
  sameLan,

  /// Windows / Linux / macOS 热点或共享网络。
  pcHotspot,

  /// 仅能通过云 / WebRTC / S3 中继。
  internetRelay,
}

/// SmartLinkBar 展示语义色。
enum SmartLinkUiTone {
  /// 绿色：已最优（局域网直连可用）。
  optimal,

  /// 黄色：建议优化（仍有更理想的直连路径可用）。
  suggest,

  /// 灰色：云中转为主。
  neutral,
}

/// 当前会话的链路推荐结果。
class LinkRecommendation {
  const LinkRecommendation({
    required this.primary,
    required this.fallbackChain,
    required this.uiTone,
    required this.title,
    required this.subtitle,
    this.lanHttpAvailable = false,
    this.webrtcAvailable = false,
  });

  final SmartLinkKind primary;
  final List<SmartLinkKind> fallbackChain;
  final SmartLinkUiTone uiTone;
  final String title;
  final String subtitle;

  /// 当前 HTTP 局域网探测是否可用。
  final bool lanHttpAvailable;

  /// WebRTC 探测是否在线。
  final bool webrtcAvailable;
}
