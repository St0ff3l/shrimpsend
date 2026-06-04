package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MembershipCreateOrderResponse {
    private MembershipOrderResponse order;
    /** 手机网站支付跳转链接（{@code alipay.trade.wap.pay}，SDK 签名 GET URL） */
    private String alipayPayUrl;
    /** PC 网页支付跳转链接（AlipayTradePagePay），桌面端使用 */
    private String alipayPcPayUrl;
    /** APP 支付订单字符串，Flutter Tobias 调起支付宝使用 */
    private String alipayOrderString;
}
