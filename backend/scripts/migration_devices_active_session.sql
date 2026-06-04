-- 设备会话与软删除：用于会员设备上限统计（仅 active）与踢出/登出后 JWT 失效
ALTER TABLE devices
    ADD COLUMN active TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'false=已踢出/登出，不计入上限' AFTER last_seen,
    ADD COLUMN session_version INT NOT NULL DEFAULT 0 COMMENT 'JWT dsv 需与此一致' AFTER active;
