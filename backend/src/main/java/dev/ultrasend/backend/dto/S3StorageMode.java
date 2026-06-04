package dev.ultrasend.backend.dto;

/**
 * 当前用户的 S3 存储模式。
 *
 * <ul>
 *   <li>{@link #DISABLED} —— 当前部署没有内置 S3，且该用户也未配置自建 S3。</li>
 *   <li>{@link #HOSTED} —— 该用户走平台内置 S3（仅海外集群且 hosted 桶启用时可见）。</li>
 *   <li>{@link #CUSTOM} —— 该用户已经配置了自建 S3，所有上传/下载走用户自己的桶。</li>
 * </ul>
 */
public enum S3StorageMode {
    DISABLED,
    HOSTED,
    CUSTOM
}
