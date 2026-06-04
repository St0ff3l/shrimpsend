package dev.ultrasend.backend.service;

import com.alipay.api.AlipayApiException;
import com.alipay.api.AlipayClient;
import com.alipay.api.DefaultAlipayClient;
import com.alipay.api.domain.AlipayTradePagePayModel;
import com.alipay.api.request.AlipayTradePagePayRequest;
import com.alipay.api.response.AlipayTradePagePayResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

/**
 * Generates an Alipay PC web payment URL (AlipayTradePagePay) for desktop / browser flows.
 *
 * <p>Used when the calling client is a PC desktop app (macOS / Windows / Linux) that cannot
 * use the Tobias APP SDK and where the existing {@code wap-pay} URL (mobile web) gives a poor
 * experience.
 */
@Service
@Slf4j
public class AlipayPagePayService {

    private static final String CHARSET = "UTF-8";
    private static final String FORMAT = "json";
    private static final String SIGN_TYPE = "RSA2";
    private static final String PRODUCT_CODE = "FAST_INSTANT_TRADE_PAY";

    @Value("${app.membership.alipay.app-id:}")
    private String appId;

    @Value("${app.membership.alipay.private-key:}")
    private String privateKey;

    @Value("${app.membership.alipay.alipay-public-key:}")
    private String alipayPublicKey;

    @Value("${app.membership.alipay.gateway:https://openapi.alipay.com/gateway.do}")
    private String gateway;

    @Value("${app.membership.alipay.notify-url:}")
    private String notifyUrl;

    @Value("${app.membership.alipay.local-notify-url:}")
    private String localNotifyUrl;

    @Value("${app.membership.alipay.return-url:http://localhost:3000/settings/membership}")
    private String returnUrl;

    private final Environment environment;

    public AlipayPagePayService(Environment environment) {
        this.environment = environment;
    }

    /**
     * Builds a fully-formed PC web payment URL that the client can open in a system browser.
     *
     * @param orderNo     merchant order number
     * @param subject     product title
     * @param amountCent  amount in cents; converted to yuan with two decimals
     * @return signed PC web pay URL, or {@code null} if Alipay is not configured
     */
    public String createPagePayUrl(String orderNo, String subject, int amountCent) {
        if (appId == null || appId.isBlank() || privateKey == null || privateKey.isBlank()) {
            log.debug("alipay page pay not configured, skip url");
            return null;
        }
        try {
            AlipayClient client = new DefaultAlipayClient(
                    gateway, appId, privateKey, FORMAT, CHARSET, alipayPublicKey, SIGN_TYPE);
            AlipayTradePagePayRequest request = new AlipayTradePagePayRequest();
            request.setReturnUrl(returnUrl);
            String finalNotifyUrl = resolveNotifyUrl();
            if (finalNotifyUrl != null && !finalNotifyUrl.isBlank()) {
                request.setNotifyUrl(finalNotifyUrl);
            }
            AlipayTradePagePayModel model = new AlipayTradePagePayModel();
            model.setOutTradeNo(orderNo);
            model.setSubject(subject);
            model.setTotalAmount(String.format("%.2f", amountCent / 100.0));
            model.setProductCode(PRODUCT_CODE);
            model.setBody(subject);
            request.setBizModel(model);

            // pageExecute returns a full HTML form-redirect; we instead use the GET form via
            // pageExecute("GET") which yields a signed URL we can hand to the desktop client.
            AlipayTradePagePayResponse response = client.pageExecute(request, "GET");
            String url = response.getBody();
            log.info("alipay page pay url created orderNo={}", orderNo);
            return url;
        } catch (AlipayApiException e) {
            log.warn("alipay page pay url failed orderNo={} {}", orderNo, e.getMessage());
            return null;
        }
    }

    private String resolveNotifyUrl() {
        if (isLocalEnvironment()) {
            return localNotifyUrl != null && !localNotifyUrl.isBlank() ? localNotifyUrl : notifyUrl;
        }
        return notifyUrl;
    }

    private boolean isLocalEnvironment() {
        for (String profile : environment.getActiveProfiles()) {
            if ("prod".equals(profile)) {
                return false;
            }
        }
        return true;
    }
}
