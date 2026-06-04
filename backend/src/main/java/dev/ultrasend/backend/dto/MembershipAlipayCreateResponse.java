package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MembershipAlipayCreateResponse {
    private String orderNo;
    private String payUrl;
}
