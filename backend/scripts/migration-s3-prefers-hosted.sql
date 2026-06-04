-- 给 s3_config 增加 prefers_hosted 偏好字段
-- 用户切换回内置 S3（HOSTED）时不再清空自建配置，仅切换偏好；
-- prefers_hosted = TRUE  → 即便 BYO 凭证存在也走平台托管 R2/B2
-- prefers_hosted = FALSE → 走自建 S3（默认值，与原有行为一致）

USE ultrasend;

ALTER TABLE s3_config
    ADD COLUMN prefers_hosted TINYINT(1) NOT NULL DEFAULT 0
        COMMENT '1=用户主动切到内置 S3 但保留自建凭证；0=以自建 S3 为活跃模式'
        AFTER secret_access_key;
