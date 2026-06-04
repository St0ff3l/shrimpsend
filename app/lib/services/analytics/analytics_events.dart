/// OpenPanel 自定义事件名（与 Web [analyticsEvents] 对齐，snake_case）。
class AnalyticsEvents {
  AnalyticsEvents._();

  static const localeGateCompleted = 'locale_gate_completed';
  static const loginSubmit = 'login_submit';
  static const registerSubmit = 'register_submit';
  static const loginCodeSubmit = 'login_code_submit';
  static const verificationCodeSend = 'verification_code_send';
  static const qrLoginOutcome = 'qr_login_outcome';
  static const logout = 'logout';

  static const deviceRemove = 'device_remove';
  static const sendModeChanged = 'send_mode_changed';

  /// 用户选中一条会话线程（含 S3 云线程）；不含对端设备明文 id。
  static const chatSessionOpen = 'chat_session_open';

  static const chatTextSend = 'chat_text_send';
  static const chatTextRetry = 'chat_text_retry';
  static const attachmentPick = 'attachment_pick';
  static const fileSendIntent = 'file_send_intent';
  static const fileSendOutcome = 'file_send_outcome';
  static const fileSendRetry = 'file_send_retry';
  static const fileSendCancel = 'file_send_cancel';

  static const messageSearch = 'message_search';

  static const filePreviewOpen = 'file_preview_open';
  static const fileSaveToGallery = 'file_save_to_gallery';

  static const membershipScreenView = 'membership_screen_view';
  static const membershipPurchaseStart = 'membership_purchase_start';
  static const membershipPurchaseOutcome = 'membership_purchase_outcome';

  static const settingChanged = 'setting_changed';
  static const s3SettingsSave = 's3_settings_save';
  static const appUpdateInstallClicked = 'app_update_install_clicked';
  static const shareIntoAppReceived = 'share_into_app_received';

  static const offlineModeEnter = 'offline_mode_enter';
}
