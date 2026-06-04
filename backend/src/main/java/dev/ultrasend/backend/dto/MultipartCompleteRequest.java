package dev.ultrasend.backend.dto;

import lombok.Data;

import java.util.List;

@Data
public class MultipartCompleteRequest {
    private String uploadId;
    private String key;
    private List<PartInfo> parts;

    @Data
    public static class PartInfo {
        private int partNumber;
        private String eTag;
    }
}
