/// 复制为 openpanel_env.secrets.dart（该文件已 gitignore）。
/// 官方打包机从 ops 仓 sync；自托管可留空以禁用 OpenPanel ingest。
class OpenpanelSecrets {
  OpenpanelSecrets._();

  static const cnAppClientId = '';
  static const cnAppClientSecret = '';
  static const cnApiBase = '';

  static const intlAppClientId = '';
  static const intlAppClientSecret = '';
  static const intlApiBase = '';
}
