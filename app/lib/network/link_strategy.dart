import 'link_capability.dart';
import 'link_models.dart';

/// 按本端与对端平台生成策略链（有序：优先 → 兜底）。
List<SmartLinkKind> resolveStrategyChain({
  required String localOs,
  required String? peerPlatform,
}) {
  final local = normalizeOs(localOs);
  final peer = normalizeOs(peerPlatform);

  bool ios(String o) => o == 'ios';
  bool android(String o) => o == 'android';
  bool pcWinLinux(String o) => o == 'windows' || o == 'linux';
  bool pcAny(String o) => o == 'windows' || o == 'linux' || o == 'macos';

  // iOS × iOS
  if (ios(local) && ios(peer)) {
    return [SmartLinkKind.sameLan, SmartLinkKind.internetRelay];
  }

  // Android × iOS
  if ((android(local) && ios(peer)) || (ios(local) && android(peer))) {
    return [SmartLinkKind.sameLan, SmartLinkKind.internetRelay];
  }

  // Android × Android
  if (android(local) && android(peer)) {
    return [SmartLinkKind.sameLan, SmartLinkKind.internetRelay];
  }

  // Android × PC
  if ((android(local) && pcAny(peer)) || (pcAny(local) && android(peer))) {
    return [
      SmartLinkKind.sameLan,
      SmartLinkKind.pcHotspot,
      SmartLinkKind.internetRelay,
    ];
  }

  // iOS × PC(Win/Linux)
  if ((ios(local) && pcWinLinux(peer)) || (pcWinLinux(local) && ios(peer))) {
    return [
      SmartLinkKind.sameLan,
      SmartLinkKind.pcHotspot,
      SmartLinkKind.internetRelay,
    ];
  }

  // iOS × macOS；此处处理遗漏的 unknown
  if (local == 'unknown' || peer == 'unknown') {
    return [SmartLinkKind.sameLan, SmartLinkKind.internetRelay];
  }

  // PC × PC（含 macOS 与 windows/linux 组合已在上面部分覆盖）
  if (pcAny(local) && pcAny(peer)) {
    return [
      SmartLinkKind.sameLan,
      SmartLinkKind.pcHotspot,
      SmartLinkKind.internetRelay,
    ];
  }

  return [SmartLinkKind.sameLan, SmartLinkKind.internetRelay];
}
