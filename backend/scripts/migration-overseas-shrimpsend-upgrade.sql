-- ShrimpSend 海外集群：从已有 schema 升级到「订阅 + 内置托管上传计量」
--
-- 若早期 ddl 曾生成列名 year_month 导致失败：可 DROP TABLE hosted_upload_usage; 后重建（仅空库/可丢数据时）。
-- 适用：已在跑的 MySQL 库（此前仅有 membership_entitlements 旧列，无 hosted_upload_usage）
--
-- 执行说明：
-- 1. 在目标库执行前请先备份。
-- 2. 若已通过 Hibernate ddl-auto=update 自动加列，对应 ALTER 会报 Duplicate column —— 跳过该条即可。
-- 3. JPA 实体已包含下列字段；本脚本用于生产可控变更与 Code Review。
--
-- USE your_database;

-- ── membership_entitlements：海外订阅到期与计费周期 ─────────────────────
ALTER TABLE membership_entitlements
    ADD COLUMN subscription_expires_at DATETIME(3) NULL COMMENT '海外 Stripe/RC 订阅到期' AFTER is_lifetime,
    ADD COLUMN billing_period VARCHAR(16) NULL COMMENT 'MONTHLY/YEARLY' AFTER subscription_expires_at;

-- ── hosted_upload_usage：内置 R2 按月上传字节（UTC yyyy-MM）──────────────
CREATE TABLE IF NOT EXISTS hosted_upload_usage (
    id           BIGINT      NOT NULL AUTO_INCREMENT,
    user_id      BIGINT      NOT NULL,
    usage_month  VARCHAR(7)  NOT NULL COMMENT 'UTC yyyy-MM (not year_month: YEAR reserved in MySQL)',
    upload_bytes BIGINT      NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_hosted_upload_user_month (user_id, usage_month),
    KEY idx_hosted_upload_user (user_id),
    CONSTRAINT fk_hosted_upload_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
