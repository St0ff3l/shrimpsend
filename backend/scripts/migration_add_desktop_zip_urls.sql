-- 桌面端 flutter_desktop_updater 使用的 ZIP 包地址（每平台可选）
USE ultrasend;

ALTER TABLE app_version
  ADD COLUMN desktop_windows_zip_url VARCHAR(1024) DEFAULT NULL COMMENT 'Windows 更新 ZIP（见 flutter_desktop_updater 文档）' AFTER ios_store_url,
  ADD COLUMN desktop_macos_zip_url VARCHAR(1024) DEFAULT NULL COMMENT 'macOS 更新 ZIP' AFTER desktop_windows_zip_url,
  ADD COLUMN desktop_linux_zip_url VARCHAR(1024) DEFAULT NULL COMMENT 'Linux 更新 ZIP' AFTER desktop_macos_zip_url;
