package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class DevicePresenceRequest {

    @NotBlank
    private String sessionId;

    /** online or offline. */
    @NotBlank
    private String status;

    private String platform;
}
