-- 设备在线状态：设备表保存聚合 presence，session 表保存每个连接/标签页心跳
ALTER TABLE devices
    ADD COLUMN presence_status VARCHAR(16) NOT NULL DEFAULT 'offline' COMMENT '聚合在线状态：online/offline' AFTER last_seen,
    ADD COLUMN presence_updated_at DATETIME(3) DEFAULT NULL COMMENT 'presence 状态最后变化时间' AFTER presence_status;

UPDATE devices
   SET presence_status = 'offline'
 WHERE presence_status IS NULL OR presence_status = '';

CREATE TABLE IF NOT EXISTS device_presence_sessions (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NOT NULL,
    device_id VARCHAR(128) NOT NULL,
    session_id VARCHAR(128) NOT NULL,
    platform VARCHAR(16) DEFAULT NULL,
    created_at DATETIME(3) NOT NULL,
    last_seen DATETIME(3) NOT NULL,
    closed_at DATETIME(3) DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_device_presence_session (user_id, device_id, session_id),
    KEY idx_device_presence_active (user_id, device_id, closed_at, last_seen)
);
