-- 初始化应用版本（首次启用版本表时执行）
-- 请先执行 migration_create_app_version.sql 建表，或依赖 JPA ddl-auto 建表
-- 若表中已有数据可跳过
USE ultrasend;

INSERT INTO app_version (version, build_number, download_url, release_notes, ios_store_url, enabled, created_at)
SELECT '1.0.5', 5, '', '', '', 1, NOW(3)
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM app_version LIMIT 1);
