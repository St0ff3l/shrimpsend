package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MembershipMigrationVerifyResponse {

    private boolean success;
    private String message;
    private String tierCode;
    private String tierName;
    private Integer deviceLimit;
}
