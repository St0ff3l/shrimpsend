package dev.ultrasend.backend.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;

@Service
@Slf4j
public class AlipaySignatureService {

    @Value("${app.membership.alipay.alipay-public-key:}")
    private String alipayPublicKey;

    @Value("${app.membership.alipay.mock-notify-enabled:true}")
    private boolean mockNotifyEnabled;

    public boolean verifyNotifySignature(Map<String, String> params) {
        if (mockNotifyEnabled && "true".equalsIgnoreCase(params.getOrDefault("mock_paid", "false"))) {
            return true;
        }
        String sign = params.get("sign");
        if (sign == null || sign.isBlank()) {
            log.warn("alipay notify missing sign");
            return false;
        }
        if (alipayPublicKey == null || alipayPublicKey.isBlank()) {
            log.warn("alipay public key empty");
            return false;
        }
        try {
            String content = buildSignContent(params);
            PublicKey publicKey = loadPublicKey(alipayPublicKey);
            Signature verifier = Signature.getInstance("SHA256withRSA");
            verifier.initVerify(publicKey);
            verifier.update(content.getBytes(StandardCharsets.UTF_8));
            boolean verified = verifier.verify(Base64.getDecoder().decode(sign));
            if (!verified) {
                log.warn("alipay verify sign failed outTradeNo={} signContentLength={} publicKeyPrefix={}", 
                    params.get("out_trade_no"), content.length(), 
                    alipayPublicKey != null && alipayPublicKey.length() > 20 ? alipayPublicKey.substring(0, 20) : "empty");
            }
            return verified;
        } catch (Exception e) {
            log.warn("alipay verify sign exception outTradeNo={} error={}", 
                params.get("out_trade_no"), e.getMessage(), e);
            return false;
        }
    }

    private String buildSignContent(Map<String, String> params) {
        Map<String, String> sorted = new TreeMap<>(params);
        sorted.remove("sign");
        sorted.remove("sign_type");
        return sorted.entrySet().stream()
                .filter(e -> e.getValue() != null && !e.getValue().isBlank())
                .map(e -> e.getKey() + "=" + e.getValue())
                .collect(Collectors.joining("&"));
    }

    private PublicKey loadPublicKey(String key) throws Exception {
        String normalized = key
                .replace("-----BEGIN PUBLIC KEY-----", "")
                .replace("-----END PUBLIC KEY-----", "")
                .replaceAll("\\s+", "");
        byte[] encoded = Base64.getDecoder().decode(normalized);
        X509EncodedKeySpec spec = new X509EncodedKeySpec(encoded);
        return KeyFactory.getInstance("RSA").generatePublic(spec);
    }
}
