-- 设备表增加 platform 字段，用于区分设备类型（如 android, ios, macos, windows, linux, web）
USE ultrasend;

ALTER TABLE devices
  ADD COLUMN platform VARCHAR(16) DEFAULT NULL COMMENT '设备平台类型'
  AFTER name;
