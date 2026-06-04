-- 桌面 ZIP 文件大小（字节），供 flutter_desktop_updater 的 file_size 展示；可空表示未知
USE ultrasend;

ALTER TABLE app_version
  ADD COLUMN desktop_windows_zip_bytes BIGINT DEFAULT NULL COMMENT 'Windows ZIP 字节数' AFTER desktop_linux_zip_url,
  ADD COLUMN desktop_macos_zip_bytes BIGINT DEFAULT NULL COMMENT 'macOS ZIP 字节数' AFTER desktop_windows_zip_bytes,
  ADD COLUMN desktop_linux_zip_bytes BIGINT DEFAULT NULL COMMENT 'Linux ZIP 字节数' AFTER desktop_macos_zip_bytes;
