package dev.ultrasend.backend.dto;

import lombok.Data;

@Data
public class MultipartPresignPartRequest {
    private String uploadId;
    private String key;
    private int partNumber;
}
