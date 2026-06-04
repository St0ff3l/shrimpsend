package dev.ultrasend.backend.service;

import com.alipay.api.AlipayApiException;
import com.alipay.api.AlipayClient;
import com.alipay.api.DefaultAlipayClient;
import com.alipay.api.request.AlipayTradeAppPayRequest;
import com.alipay.api.response.AlipayTradeAppPayResponse;
import com.alipay.api.domain.AlipayTradeAppPayModel;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

/**
 * 为 Flutter Tobias 插件生成支付宝 APP 支付订单字符串（orderStr）。
 * 需配置 app_id、应用私钥、支付宝公钥、异步通知地址。
 */
@Service
@Slf4j
public class AlipayAppPayService {

    private static final String CHARSET = "UTF-8";
    private static final String FORMAT = "json";
    private static final String SIGN_TYPE = "RSA2";
    private static final String PRODUCT_CODE = "QUICK_MSECURITY_PAY";

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

    private final Environment environment;

    public AlipayAppPayService(Environment environment) {
        this.environment = environment;
    }

    /**
     * 生成 APP 支付订单字符串，供客户端 Tobias.pay(orderStr) 调起支付宝。
     *
     * @param orderNo   商户订单号
     * @param subject   商品标题
     * @param amountCent 金额（分），会转为元保留两位小数
     * @return 签名的 orderStr，未配置时返回 null
     */
    public String createOrderString(String orderNo, String subject, int amountCent) {
        if (appId == null || appId.isBlank() || privateKey == null || privateKey.isBlank()) {
            log.debug("alipay app pay not configured, skip orderString");
            return null;
        }
        try {
            AlipayClient client = new DefaultAlipayClient(
                    gateway, appId, privateKey, FORMAT, CHARSET, alipayPublicKey, SIGN_TYPE);
            AlipayTradeAppPayRequest request = new AlipayTradeAppPayRequest();
            // 本地环境使用配置的 local-notify-url
            String finalNotifyUrl = getNotifyUrl();
            if (finalNotifyUrl != null && !finalNotifyUrl.isBlank()) {
                request.setNotifyUrl(finalNotifyUrl);
            }
            AlipayTradeAppPayModel model = new AlipayTradeAppPayModel();
            model.setOutTradeNo(orderNo);
            model.setSubject(subject);
            model.setTotalAmount(String.format("%.2f", amountCent / 100.0));
            model.setProductCode(PRODUCT_CODE);
            model.setBody(subject);
            request.setBizModel(model);

            AlipayTradeAppPayResponse response = client.sdkExecute(request);
            String body = response.getBody();
            log.info("alipay app pay orderString created orderNo={}", orderNo);
            return body;
        } catch (AlipayApiException e) {
            log.warn("alipay app pay orderString failed orderNo={} {}", orderNo, e.getMessage());
            return null;
        }
    }

    /**
     * 获取回调地址
     * 本地环境使用配置的 local-notify-url
     */
    private String getNotifyUrl() {
        if (isLocalEnvironment()) {
            return localNotifyUrl != null && !localNotifyUrl.isBlank() ? localNotifyUrl : notifyUrl;
        }
        return notifyUrl;
    }

    /**
     * 判断是否是本地环境（非生产环境）
     * 通过检查 spring.profiles.active 是否包含 "prod" 来判断
     */
    private boolean isLocalEnvironment() {
        String[] activeProfiles = environment.getActiveProfiles();
        for (String profile : activeProfiles) {
            if ("prod".equals(profile)) {
                return false;
            }
        }
        return true;
    }
}
