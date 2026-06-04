-- 跨平台订阅渠道亲和：membership_entitlements 增加 payment_channel；新增 subscription_conflicts 表
-- payment_channel 取值：FREE / APPLE_RC / GOOGLE_RC / STRIPE
-- 与海外双轨（Stripe + RevenueCat）配套使用；国内集群仅 FREE / ALIPAY_LIFETIME（已购终身）

USE ultrasend;

-- 1. 添加 payment_channel
ALTER TABLE membership_entitlements
    ADD COLUMN payment_channel VARCHAR(16) NULL
        COMMENT 'FREE/APPLE_RC/GOOGLE_RC/STRIPE/ALIPAY_LIFETIME，当前活跃订阅渠道'
        AFTER stripe_subscription_id;

-- 2. 回填：Stripe 优先（订阅 id 非空）→ STRIPE
UPDATE membership_entitlements
SET payment_channel = 'STRIPE'
WHERE payment_channel IS NULL
  AND stripe_subscription_id IS NOT NULL
  AND stripe_subscription_id <> '';

-- 3. 回填：RC 海外订阅（tier 非 FREE 且无 stripe id，且最近一笔订单 channel = APPLE_RC）
--    无法精确区分 iOS / Android，统一标 APPLE_RC（保守做法：iOS 占多数；后续 webhook 会精确细化）
UPDATE membership_entitlements e
    LEFT JOIN (
        SELECT user_id, MAX(created_at) AS last_created
        FROM membership_orders
        WHERE channel = 'APPLE_RC'
        GROUP BY user_id
    ) o ON o.user_id = e.user_id
SET e.payment_channel = 'APPLE_RC'
WHERE e.payment_channel IS NULL
  AND e.tier_code <> 'FREE'
  AND o.user_id IS NOT NULL;

-- 4. 回填：国内集群终身（is_lifetime = 1 且 tier 非 FREE 且无 RC/Stripe 关联）→ ALIPAY_LIFETIME
UPDATE membership_entitlements
SET payment_channel = 'ALIPAY_LIFETIME'
WHERE payment_channel IS NULL
  AND tier_code <> 'FREE'
  AND is_lifetime = 1;

-- 5. 剩余 FREE 用户
UPDATE membership_entitlements
SET payment_channel = 'FREE'
WHERE payment_channel IS NULL;

-- 6. 索引（用于 conflicts 查询、统计）
ALTER TABLE membership_entitlements
    ADD KEY idx_membership_entitlements_payment_channel (payment_channel);

-- 7. 订阅渠道冲突表：当 webhook 检测到同一用户两个渠道都活跃时记录，便于运营/客服处理
CREATE TABLE IF NOT EXISTS subscription_conflicts (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    user_id         BIGINT       NOT NULL,
    detected_at     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    active_channels VARCHAR(128) NOT NULL COMMENT '冲突渠道，逗号分隔 e.g. STRIPE,APPLE_RC',
    incoming_channel VARCHAR(16) NOT NULL COMMENT '本次 webhook 试图写入的渠道',
    existing_channel VARCHAR(16) NOT NULL COMMENT '原有 payment_channel',
    incoming_tier   VARCHAR(16)  DEFAULT NULL,
    existing_tier   VARCHAR(16)  DEFAULT NULL,
    incoming_expires_at DATETIME(3) DEFAULT NULL,
    existing_expires_at DATETIME(3) DEFAULT NULL,
    resolved_at     DATETIME(3)  DEFAULT NULL,
    note            VARCHAR(512) DEFAULT NULL,
    payload_excerpt VARCHAR(1024) DEFAULT NULL COMMENT 'webhook 原文截断片段',
    PRIMARY KEY (id),
    KEY idx_subscription_conflicts_user (user_id),
    KEY idx_subscription_conflicts_unresolved (resolved_at),
    CONSTRAINT fk_subscription_conflicts_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
