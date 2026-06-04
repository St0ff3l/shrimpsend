package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class DeviceUpdateRequest {

    @Size(max = 128)
    private String name;

    private String lanHttpUrl;
}
