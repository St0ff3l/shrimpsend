-- 会员迁移功能：手机号验证码表和用户表字段修改

USE ultrasend;

-- 手机号验证码表
CREATE TABLE IF NOT EXISTS mobile_verification_codes (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    mobile     VARCHAR(11)  NOT NULL,
    code       VARCHAR(6)   NOT NULL,
    type       VARCHAR(20)  NOT NULL COMMENT 'MIGRATION',
    created_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    expires_at DATETIME(3)  NOT NULL,
    used       TINYINT(1)   NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_mvcode_mobile_type (mobile, type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 修改用户表，添加手机号验证相关字段
-- 注意：MySQL不支持 ALTER TABLE ADD COLUMN IF NOT EXISTS
-- 如果列已存在，执行会报错，可以忽略该错误或先手动检查
ALTER TABLE users 
    ADD COLUMN verified_mobile VARCHAR(11) DEFAULT NULL COMMENT '已验证的手机号（用于防重复）',
    ADD COLUMN mobile_migration_verified_at DATETIME(3) DEFAULT NULL COMMENT '手机号验证时间';

-- 添加索引（MySQL 5.7+支持IF NOT EXISTS）
CREATE INDEX idx_users_verified_mobile ON users(verified_mobile);
