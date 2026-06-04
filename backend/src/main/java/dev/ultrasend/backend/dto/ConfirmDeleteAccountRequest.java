package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class ConfirmDeleteAccountRequest {

    @NotBlank
    private String code;
}
