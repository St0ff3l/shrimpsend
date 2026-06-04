package dev.ultrasend.backend.dto.centrifugo;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

/**
 * Centrifugo connect proxy 完整响应。
 */
@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ConnectResponseDto {

    private ConnectResultDto result;
    /** 拒绝连接时返回 disconnect */
    private DisconnectDto disconnect;
}
