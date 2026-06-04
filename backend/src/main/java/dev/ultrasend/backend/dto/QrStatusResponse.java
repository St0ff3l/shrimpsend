package dev.ultrasend.backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class QrStatusResponse {
    private String status;
    private String accessToken;
    private String refreshToken;
    private String userId;
    private Long expiresIn;
}
