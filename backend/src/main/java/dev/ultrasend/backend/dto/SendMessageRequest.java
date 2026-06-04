package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.Map;

@Data
public class SendMessageRequest {

    @NotNull
    private Object data; // message envelope: { type, payload, fromDeviceId, ts }
}
