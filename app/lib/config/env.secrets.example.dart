/// 复制为 env.secrets.dart（该文件已 gitignore）。
/// 官方打包机从 ops 仓 sync；自托管请填入 RC 公钥与生产 API/WS URL。
class EnvSecrets {
  EnvSecrets._();

  /// RevenueCat Test Store 公钥（debug/profile）。
  static const rcTestStoreApiKey = '';

  /// ShrimpSend intl iOS — RevenueCat 海外 Project 公钥（`appl_` 前缀）。
  static const rcAppleApiKeyProdIntl = '';

  /// 虾传 cn iOS — RevenueCat 国内 Project 公钥（`appl_` 前缀）。
  static const rcAppleApiKeyProdCn = '';

  /// RevenueCat Google Play 公钥（`goog_` 前缀）。
  static const rcGoogleApiKeyProd = '';

  /// 生产 API / WebSocket（国内 xiachuan 集群）。
  static const prodApiCn = '';
  static const prodWsCn = '';

  /// 生产 API / WebSocket（海外 ShrimpSend 集群）。
  static const prodApiIntl = '';
  static const prodWsIntl = '';
}
