-- 消息历史表（与 schema.sql 中 messages 表一致，供已有库单独执行）
USE ultrasend;

CREATE TABLE IF NOT EXISTS messages (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    user_id    BIGINT       NOT NULL,
    data       TEXT         NOT NULL COMMENT 'JSON envelope: type, payload, fromDeviceId, ts',
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_messages_user_created (user_id, created_at),
    CONSTRAINT fk_messages_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
