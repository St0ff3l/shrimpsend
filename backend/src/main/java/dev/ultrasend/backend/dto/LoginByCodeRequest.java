package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginByCodeRequest {

    @NotBlank
    @Email
    private String email;

    @NotBlank
    private String code;

    @NotBlank
    private String deviceId;

    private String platform;
}
