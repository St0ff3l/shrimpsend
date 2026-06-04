package dev.ultrasend.backend.dto.centrifugo;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

/**
 * Centrifugo refresh proxy 请求体。
 */
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class RefreshRequestDto {

    private String client;
    private String transport;
    private String protocol;
    private String encoding;
    private String user;
}
