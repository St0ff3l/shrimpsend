-- 给 s3_config 增加 path_style_access_enabled 字段
-- true（默认）= Path-style：{endpoint}/{bucket}/{key}
-- false = 虚拟托管：{scheme}://{bucket}.{host}/{key}

USE ultrasend;

ALTER TABLE s3_config
    ADD COLUMN path_style_access_enabled TINYINT(1) NOT NULL DEFAULT 1
        COMMENT '1=Path-style URL；0=虚拟托管（bucket 作为子域）'
        AFTER prefers_hosted;
