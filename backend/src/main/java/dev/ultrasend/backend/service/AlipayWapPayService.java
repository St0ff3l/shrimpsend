package dev.ultrasend.backend.service;

import com.alipay.api.AlipayApiException;
import com.alipay.api.AlipayClient;
import com.alipay.api.DefaultAlipayClient;
import com.alipay.api.domain.AlipayTradeWapPayModel;
import com.alipay.api.request.AlipayTradeWapPayRequest;
import com.alipay.api.response.AlipayTradeWapPayResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

/**
 * Generates a signed Alipay mobile web payment URL ({@code alipay.trade.wap.pay}) for phone browsers.
 */
@Service
@Slf4j
public class AlipayWapPayService {

    private static final String CHARSET = "UTF-8";
    private static final String FORMAT = "json";
    private static final String SIGN_TYPE = "RSA2";
    /** 手机网站支付产品码 */
    private static final String PRODUCT_CODE = "QUICK_WAP_WAY";

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

    public AlipayWapPayService(Environment environment) {
        this.environment = environment;
    }

    /**
     * @return signed GET redirect URL, or {@code null} if Alipay is not configured or the SDK call fails
     */
    public String createWapPayUrl(String orderNo, String subject, int amountCent) {
        if (appId == null || appId.isBlank() || privateKey == null || privateKey.isBlank()) {
            log.debug("alipay wap pay not configured, skip url");
            return null;
        }
        try {
            AlipayClient client = new DefaultAlipayClient(
                    gateway, appId, privateKey, FORMAT, CHARSET, alipayPublicKey, SIGN_TYPE);
            AlipayTradeWapPayRequest request = new AlipayTradeWapPayRequest();
            request.setReturnUrl(returnUrl);
            String finalNotifyUrl = resolveNotifyUrl();
            if (finalNotifyUrl != null && !finalNotifyUrl.isBlank()) {
                request.setNotifyUrl(finalNotifyUrl);
            }
            AlipayTradeWapPayModel model = new AlipayTradeWapPayModel();
            model.setOutTradeNo(orderNo);
            model.setSubject(subject);
            model.setTotalAmount(String.format("%.2f", amountCent / 100.0));
            model.setProductCode(PRODUCT_CODE);
            model.setBody(subject);
            request.setBizModel(model);

            AlipayTradeWapPayResponse response = client.pageExecute(request, "GET");
            String url = response.getBody();
            log.info("alipay wap pay url created orderNo={}", orderNo);
            return url;
        } catch (AlipayApiException e) {
            log.warn("alipay wap pay url failed orderNo={} {}", orderNo, e.getMessage());
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
