package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MembershipOrderResponse {
    private String orderNo;
    private String fromTier;
    private String toTier;
    private Integer payableAmountCent;
    private String currency;
    private String channel;
    private String status;
    private Long createdAt;
    private Long updatedAt;
}
