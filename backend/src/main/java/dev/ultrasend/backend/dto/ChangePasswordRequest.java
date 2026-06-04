package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ChangePasswordRequest {

    @NotBlank
    private String code;

    @NotBlank
    @Size(min = 6, message = "新密码至少需要6个字符")
    private String newPassword;
}
