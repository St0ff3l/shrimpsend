package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {

    @NotBlank
    @Email
    private String email;

    @NotBlank
    @Size(min = 6)
    private String password;

    @NotBlank
    @Size(min = 6, max = 6)
    private String code;

    @Size(max = 64)
    private String username;

    @NotBlank
    private String deviceId;

    private String platform;
}
