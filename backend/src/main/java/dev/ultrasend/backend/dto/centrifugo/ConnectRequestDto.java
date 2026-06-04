package dev.ultrasend.backend.dto.centrifugo;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

import java.util.Map;

/**
 * Centrifugo connect proxy 请求体。
 * @see <a href="https://centrifugal.dev/docs/server/proxy#connect-proxy">Connect proxy</a>
 */
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class ConnectRequestDto {

    private String client;
    private String transport;
    private String protocol;
    private String encoding;
    /** 客户端通过 SDK 的 data 传入，如 { "deviceId": "...", "name": "..." } */
    private Map<String, Object> data;
}
