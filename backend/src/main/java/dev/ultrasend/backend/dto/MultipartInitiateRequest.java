package dev.ultrasend.backend.dto;

import lombok.Data;

@Data
public class MultipartInitiateRequest {
    private String fileName;
    private String contentType;
    /** Required for overseas hosted (R2) multipart quota check. */
    private Long totalSize;
}
