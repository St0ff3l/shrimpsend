-- 每用户 1–999 展示用短码；踢出后 NULL 释放号码。唯一约束 (user_id, display_code) 仅对非 NULL 生效（MySQL 允许多个 NULL）。
USE ultrasend;

ALTER TABLE devices
  ADD COLUMN display_code SMALLINT DEFAULT NULL COMMENT '同用户下 1–999 展示码，踢出置 NULL'
  AFTER session_version;

-- 为历史活跃设备按 user_id + id 回填 1,2,3…
UPDATE devices d
INNER JOIN (
  SELECT id,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY id) AS rn
  FROM devices
  WHERE active = 1
) t ON d.id = t.id
SET d.display_code = t.rn
WHERE t.rn <= 999;

ALTER TABLE devices
  ADD UNIQUE KEY uk_devices_user_display_code (user_id, display_code);
