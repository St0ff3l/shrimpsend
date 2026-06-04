-- 已有 users 表时执行：增加邮箱注册支持（请先备份）
USE ultrasend;

-- 1. 增加 email 列
ALTER TABLE users ADD COLUMN email VARCHAR(255) NULL AFTER id;
-- 2. 旧数据：用 username 填充 email
UPDATE users SET email = LOWER(COALESCE(username, CONCAT('user', id, '@local'))) WHERE email IS NULL;
-- 3. 删除旧唯一约束后改为 NOT NULL 并加唯一
ALTER TABLE users DROP INDEX uk_users_username;
ALTER TABLE users MODIFY COLUMN email VARCHAR(255) NOT NULL;
ALTER TABLE users ADD UNIQUE KEY uk_users_email (email);
-- 4. username 改为可选
ALTER TABLE users MODIFY COLUMN username VARCHAR(128) DEFAULT NULL;
