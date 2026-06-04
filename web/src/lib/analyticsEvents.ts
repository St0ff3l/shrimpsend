/** 与 Flutter [AnalyticsEvents] 对齐的 snake_case 事件名 */
export const AnalyticsEvents = {
  /** 选中会话线程（含 S3）；不含对端设备明文 id */
  chatSessionOpen: 'chat_session_open',
  chatTextSend: 'chat_text_send',
  chatTextRetry: 'chat_text_retry',

  loginSubmit: 'login_submit',
  registerSubmit: 'register_submit',
  logout: 'logout',
  qrLoginOutcome: 'qr_login_outcome',
  deviceRemove: 'device_remove',
  messageSearch: 'message_search',
  membershipScreenView: 'membership_screen_view',
  membershipPurchaseStart: 'membership_purchase_start',
  membershipPurchaseOutcome: 'membership_purchase_outcome',
  settingChanged: 'setting_changed',
  s3SettingsSave: 's3_settings_save',
} as const;
