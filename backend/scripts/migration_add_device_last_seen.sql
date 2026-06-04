-- 设备表增加 last_seen 字段
USE ultrasend;

ALTER TABLE devices
  ADD COLUMN last_seen DATETIME(3) DEFAULT NULL COMMENT '最后活跃时间，用于在线状态'
  AFTER lan_http_url;
