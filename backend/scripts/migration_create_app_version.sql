-- 创建应用版本表（用于应用自动更新：最新版本与版本历史）
USE ultrasend;

CREATE TABLE IF NOT EXISTS app_version (
  id            BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  version       VARCHAR(32)  NOT NULL COMMENT '版本名，如 1.0.5',
  build_number  INT          NOT NULL COMMENT '构建号，用于比较新旧',
  download_url  VARCHAR(1024) DEFAULT NULL COMMENT 'Android 安装包下载地址',
  release_notes TEXT         DEFAULT NULL COMMENT '更新说明',
  ios_store_url VARCHAR(1024) DEFAULT NULL COMMENT 'iOS App Store 链接',
  enabled       TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '是否启用：1=启用，0=隐藏',
  created_at    DATETIME(3)  NOT NULL COMMENT '创建时间',
  UNIQUE KEY uk_build_number (build_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='应用版本（启用版本用于更新检查与历史）';
