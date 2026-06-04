package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;

@Data
public class ReleasePresignRequest {

    @NotBlank(message = "platform 不能为空")
    private String platform;

    @NotNull(message = "buildNumber 不能为空")
    @Positive(message = "buildNumber 必须为正整数")
    private Integer buildNumber;

    @NotBlank(message = "fileName 不能为空")
    private String fileName;

    private String contentType;
}
