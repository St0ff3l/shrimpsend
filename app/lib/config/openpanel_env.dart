import 'openpanel_env.secrets.dart';

/// OpenPanel 客户端配置。
/// client id / ingest URL / secret 默认值来自 gitignored [openpanel_env.secrets.dart]（ops 仓 sync）；
/// 亦可用 `--dart-define=OP_CN_*`、`OP_INTL_*` 覆盖。
class OpenpanelEnv {
  OpenpanelEnv._();

  /// 国内 App 项目 client id（`ServiceRegion.mainlandChina` 时使用）。
  static const cnAppClientId = String.fromEnvironment(
    'OP_CN_APP_CLIENT_ID',
    defaultValue: OpenpanelSecrets.cnAppClientId,
  );

  /// 国内 App client secret（与 `cnAppClientId` 同项目；自托管 ingest 校验需要）。
  static const cnAppClientSecret = String.fromEnvironment(
    'OP_CN_APP_CLIENT_SECRET',
    defaultValue: OpenpanelSecrets.cnAppClientSecret,
  );

  /// OpenPanel ingest API 根路径（Dio `baseUrl`，须含 `/api` 后缀）。
  static const cnApiBase = String.fromEnvironment(
    'OP_CN_API_BASE',
    defaultValue: OpenpanelSecrets.cnApiBase,
  );

  /// 海外（出海包）ingest API 根路径（`ServiceRegion.international` 时使用）。
  static const intlApiBase = String.fromEnvironment(
    'OP_INTL_API_BASE',
    defaultValue: OpenpanelSecrets.intlApiBase,
  );

  /// 海外 App 项目 client id（`ServiceRegion.international` 时使用）。
  static const intlAppClientId = String.fromEnvironment(
    'OP_INTL_APP_CLIENT_ID',
    defaultValue: OpenpanelSecrets.intlAppClientId,
  );

  /// 海外 App client secret（与 `intlAppClientId` 同项目）。
  static const intlAppClientSecret = String.fromEnvironment(
    'OP_INTL_APP_CLIENT_SECRET',
    defaultValue: OpenpanelSecrets.intlAppClientSecret,
  );
}
