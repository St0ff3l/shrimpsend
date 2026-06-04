package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CentrifugoTokenResponse {

    private String connectionToken;
    private String subscriptionToken;
    private String channel; // user#<userId>
}
