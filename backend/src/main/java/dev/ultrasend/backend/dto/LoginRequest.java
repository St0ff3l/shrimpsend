package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LoginRequest {

    @NotBlank
    @Email
    private String email;

    @NotBlank
    private String password;

    @NotBlank
    private String deviceId;

    /** 如 web、android、ios、windows 等，用于会员设备计数（Web 多台浏览器计 1 台）。 */
    private String platform;
}
