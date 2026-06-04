-- Stripe Web：Customer / Subscription id（Billing Portal、订阅升级、防重复 Checkout）
ALTER TABLE membership_entitlements
    ADD COLUMN stripe_customer_id VARCHAR(64) NULL COMMENT 'Stripe Customer id'
        AFTER subscription_cancel_at_period_end,
    ADD COLUMN stripe_subscription_id VARCHAR(64) NULL COMMENT 'Stripe Subscription id'
        AFTER stripe_customer_id;
