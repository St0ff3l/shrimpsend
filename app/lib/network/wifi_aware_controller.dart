/// 预留：Wi‑Fi Aware (NAN) 跨平台 P2P，待 iOS / Android API 成熟后实现。
///
/// 当前所有方法均为 no-op 或返回 false。
class WifiAwareController {
  bool get isSupported =>
      false; // 将来: Platform.isIOS (26+) || Platform.isAndroid

  Future<bool> initialize() async => false;

  Future<bool> publishService({required String serviceName}) async => false;

  Future<bool> requestConnection(String peerId) async => false;

  Future<void> dispose() async {}
}
