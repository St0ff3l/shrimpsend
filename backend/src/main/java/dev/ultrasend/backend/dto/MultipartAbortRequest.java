package dev.ultrasend.backend.dto;

import lombok.Data;

@Data
public class MultipartAbortRequest {
    private String uploadId;
    private String key;
}
