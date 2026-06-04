-- Stripe：是否在周期末取消自动续费（用于前端提示「下次扣款」vs「权益结束」）
ALTER TABLE membership_entitlements
    ADD COLUMN subscription_cancel_at_period_end TINYINT(1) NULL
        COMMENT 'Stripe 周期末取消自动续费'
        AFTER subscription_expires_at;
