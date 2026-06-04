package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class DeviceRegisterRequest {

    @NotBlank
    private String deviceId;

    @NotBlank
    @Size(max = 128)
    private String name;

    private String platform;

    private String lanHttpUrl;

    private String sessionId;
}
