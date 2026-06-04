package dev.ultrasend.backend.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.Map;

@Service
@Slf4j
public class SendCloudMailService {

    private static final String SEND_URL = "https://api.sendcloud.net/apiv2/mail/send";

    private final String apiUser;
    private final String apiKey;
    private final String from;
    private final String fromName;
    private final WebClient webClient;

    public SendCloudMailService(
            @Value("${sendcloud.api-user}") String apiUser,
            @Value("${sendcloud.api-key}") String apiKey,
            @Value("${sendcloud.from}") String from,
            @Value("${sendcloud.from-name:虾传}") String fromName) {
        this.apiUser = apiUser;
        this.apiKey = apiKey;
        this.from = from;
        this.fromName = fromName;
        this.webClient = WebClient.create();
    }

    public void sendVerificationCode(String to, String code) {
        String subject = "虾传 邮箱验证码";
        String html = buildVerificationHtml(code);
        sendMail(to, subject, html);
    }

    private void sendMail(String to, String subject, String html) {
        MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
        formData.add("apiUser", apiUser);
        formData.add("apiKey", apiKey);
        formData.add("from", from);
        formData.add("fromName", fromName);
        formData.add("to", to);
        formData.add("subject", subject);
        formData.add("html", html);

        try {
            String response = webClient.post()
                    .uri(SEND_URL)
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(BodyInserters.fromFormData(formData))
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
            log.info("sendcloud mail sent to={} response={}", to, response);
        } catch (Exception e) {
            log.error("sendcloud mail failed to={}", to, e);
            throw new RuntimeException("邮件发送失败，请稍后重试");
        }
    }

    private String buildVerificationHtml(String code) {
        return """
                <div style="max-width:400px;margin:40px auto;font-family:system-ui,-apple-system,sans-serif;background:#f9fafb;border-radius:12px;padding:32px;text-align:center">
                  <h2 style="margin:0 0 8px;color:#111827">虾传</h2>
                  <p style="color:#6b7280;margin:0 0 24px">邮箱验证码</p>
                  <div style="font-size:32px;font-weight:700;letter-spacing:8px;color:#059669;background:#fff;border-radius:8px;padding:16px;margin:0 0 24px">%s</div>
                  <p style="color:#9ca3af;font-size:13px;margin:0">验证码 10 分钟内有效，请勿泄露给他人</p>
                </div>
                """.formatted(code);
    }
}
