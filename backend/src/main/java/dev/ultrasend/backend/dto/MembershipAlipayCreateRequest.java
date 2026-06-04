package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MembershipAlipayCreateRequest {
    @NotBlank(message = "orderNo 不能为空")
    private String orderNo;
}
