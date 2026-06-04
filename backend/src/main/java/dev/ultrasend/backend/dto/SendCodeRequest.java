package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class SendCodeRequest {

    @NotBlank
    @Email
    private String email;

    /** Optional: REGISTER or LOGIN. If null or blank, defaults to REGISTER. */
    private String type;

    /** LOGIN 时必填：与登录接口一致，用于校验会员设备数量。 */
    private String deviceId;

    private String platform;
}
