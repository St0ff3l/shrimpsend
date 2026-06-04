package dev.ultrasend.backend.dto.centrifugo;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Builder;
import lombok.Data;

/**
 * Centrifugo connect proxy 成功响应中的 result 部分。
 * 不再返回 channels，避免与客户端订阅冲突（server-side vs client-side subscription）。
 * Web 端通过 user-limited channel (user#userId) 自行客户端订阅即可。
 */
@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ConnectResultDto {

    /** 用户 ID，Centrifugo 要求为字符串 */
    private String user;
    /** 连接过期时间（Unix 秒），设置后 Centrifugo 会定期调用 refresh proxy */
    @JsonProperty("expire_at")
    private Long expireAt;
}
