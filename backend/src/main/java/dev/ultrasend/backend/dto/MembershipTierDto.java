package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MembershipTierDto {
    private String code;
    private String name;
    private Integer deviceLimit;
    private Integer priceCent;
    /** TIER=档位 ADDON=增购包，仅 ADDON 时需已开通 Mini 或 Pro 才可购买 */
    private String productType;
    /** MONTHLY / YEARLY — overseas subscriptions */
    private String billingPeriod;
    /** CNY domestic, USD overseas */
    private String currency;
}
