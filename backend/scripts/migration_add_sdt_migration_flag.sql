-- 在闪电藤数据库的 member_user 表中添加迁移标记字段
-- 用于防止一个闪电藤手机号被多个虾传用户重复迁移

-- 添加迁移标记字段
ALTER TABLE member_user
    ADD COLUMN migrated_to_ultrasend TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否已迁移到虾传（0=未迁移，1=已迁移）',
    ADD COLUMN migrated_at DATETIME(3) DEFAULT NULL COMMENT '迁移到虾传的时间';

-- 添加索引用于快速查询
CREATE INDEX idx_member_user_migrated ON member_user(migrated_to_ultrasend, mobile);
