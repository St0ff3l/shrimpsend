package dev.ultrasend.backend.service;

import com.tencentcloudapi.common.Credential;
import com.tencentcloudapi.common.exception.TencentCloudSDKException;
import com.tencentcloudapi.common.profile.ClientProfile;
import com.tencentcloudapi.common.profile.HttpProfile;
import com.tencentcloudapi.sms.v20210111.SmsClient;
import com.tencentcloudapi.sms.v20210111.models.SendSmsRequest;
import com.tencentcloudapi.sms.v20210111.models.SendSmsResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class TencentSmsService {

    private final String secretId;
    private final String secretKey;
    private final String smsSdkAppId;
    private final String templateId;
    private final String signName;

    public TencentSmsService(
            @Value("${tencent.sms.secret-id:}") String secretId,
            @Value("${tencent.sms.secret-key:}") String secretKey,
            @Value("${tencent.sms.sms-sdk-app-id:}") String smsSdkAppId,
            @Value("${tencent.sms.template-id:}") String templateId,
            @Value("${tencent.sms.sign-name:虾传}") String signName) {
        this.secretId = secretId;
        this.secretKey = secretKey;
        this.smsSdkAppId = smsSdkAppId;
        this.templateId = templateId;
        this.signName = signName;
        
        // 启动时验证配置
        if (secretId != null && !secretId.isBlank() && 
            secretKey != null && !secretKey.isBlank()) {
            log.info("tencent sms service initialized: smsSdkAppId={} templateId={} signName={} secretId length={}", 
                    smsSdkAppId, templateId, signName, secretId.length());
        } else {
            log.warn("tencent sms service initialized but credentials are missing");
        }
    }

    public void sendVerificationCode(String mobile, String code) {
        if (secretId == null || secretId.isBlank() || 
            secretKey == null || secretKey.isBlank() ||
            smsSdkAppId == null || smsSdkAppId.isBlank() ||
            templateId == null || templateId.isBlank()) {
            log.warn("tencent sms not configured, skipping send to={}", mobile);
            throw new RuntimeException("短信服务未配置，请联系管理员");
        }

        // 检查配置是否有效（不记录完整密钥，只记录长度）
        log.debug("tencent sms config check: secretId length={} secretKey length={} smsSdkAppId={} templateId={} signName={}", 
                secretId.length(), secretKey.length(), smsSdkAppId, templateId, signName);

        try {
            // 格式化手机号：如果已经是国际格式（+86开头），直接使用；否则添加+86前缀
            String formattedMobile = formatMobileNumber(mobile);
            
            Credential cred = new Credential(secretId, secretKey);
            HttpProfile httpProfile = new HttpProfile();
            httpProfile.setEndpoint("sms.tencentcloudapi.com");
            ClientProfile clientProfile = new ClientProfile();
            clientProfile.setHttpProfile(httpProfile);
            SmsClient client = new SmsClient(cred, "ap-beijing", clientProfile);

            SendSmsRequest req = new SendSmsRequest();
            req.setSmsSdkAppId(smsSdkAppId);
            req.setSignName(signName);
            req.setTemplateId(templateId);
            String[] phoneNumberSet = {formattedMobile};
            req.setPhoneNumberSet(phoneNumberSet);
            // 根据模板ID 1758330，需要检查模板实际需要的参数数量
            // 腾讯云短信模板参数格式：{1} 表示第一个参数，{2} 表示第二个参数
            // 如果模板是 "您的验证码是{1}，有效期{2}分钟"，则需要两个参数：[code, "10"]
            // 如果模板是 "您的验证码是{1}"，则只需要一个参数：[code]
            // 当前错误提示模板参数不匹配，可能是参数数量或格式不对
            // 先尝试只传验证码，如果模板需要有效期参数，再添加
            String[] templateParamSet = {code};
            req.setTemplateParamSet(templateParamSet);
            
            log.info("tencent sms request params: phoneNumberSet={} templateParamSet={}", 
                    java.util.Arrays.toString(phoneNumberSet), java.util.Arrays.toString(templateParamSet));

            log.info("tencent sms sending to={} formattedMobile={} smsSdkAppId={} templateId={} signName={} code={}", 
                    mobile, formattedMobile, smsSdkAppId, templateId, signName, code);
            
            SendSmsResponse resp = client.SendSms(req);
            
            // 记录响应的详细信息
            log.info("tencent sms response to={} requestId={} sendStatusSet={}", 
                    mobile, resp.getRequestId(), resp.getSendStatusSet());
            
            // 检查发送状态
            if (resp.getSendStatusSet() != null && resp.getSendStatusSet().length > 0) {
                var status = resp.getSendStatusSet()[0];
                log.info("tencent sms status to={} code={} message={} phoneNumber={}", 
                        mobile, status.getCode(), status.getMessage(), status.getPhoneNumber());
                
                // 如果发送失败，记录错误
                if (!"Ok".equals(status.getCode())) {
                    log.error("tencent sms failed to={} code={} message={}", 
                            mobile, status.getCode(), status.getMessage());
                    throw new RuntimeException("短信发送失败：" + status.getMessage() + " (code: " + status.getCode() + ")");
                }
            } else {
                log.warn("tencent sms response has no sendStatusSet to={} requestId={}", 
                        mobile, resp.getRequestId());
            }
        } catch (TencentCloudSDKException e) {
            log.error("tencent sms exception to={} errorCode={} errorMessage={} requestId={}", 
                    mobile, e.getErrorCode(), e.getMessage(), e.getRequestId(), e);
            // 记录更详细的错误信息
            if (e.getErrorCode() != null) {
                log.error("tencent sms error details: code={} message={} requestId={}", 
                        e.getErrorCode(), e.getMessage(), e.getRequestId());
            }
            throw new RuntimeException("短信发送失败：" + e.getMessage() + 
                    (e.getErrorCode() != null ? " (错误码: " + e.getErrorCode() + ")" : ""));
        } catch (Exception e) {
            log.error("tencent sms unexpected error to={}", mobile, e);
            throw new RuntimeException("短信发送失败：" + e.getMessage());
        }
    }

    /**
     * 格式化手机号为国际格式（+86开头）
     * 腾讯云短信要求手机号必须是国际格式
     */
    private String formatMobileNumber(String mobile) {
        if (mobile == null || mobile.isBlank()) {
            throw new IllegalArgumentException("手机号不能为空");
        }
        
        // 移除所有空格和特殊字符，只保留数字和+
        String cleaned = mobile.trim().replaceAll("[^0-9+]", "");
        
        // 如果已经是+86开头，直接返回
        if (cleaned.startsWith("+86")) {
            return cleaned;
        }
        
        // 如果是86开头（没有+），添加+
        if (cleaned.startsWith("86") && cleaned.length() > 2) {
            return "+" + cleaned;
        }
        
        // 如果是11位数字（中国大陆手机号），添加+86
        if (cleaned.length() == 11 && cleaned.matches("^1[3-9]\\d{9}$")) {
            return "+86" + cleaned;
        }
        
        // 其他情况，尝试添加+86
        if (cleaned.matches("^\\d+$")) {
            return "+86" + cleaned;
        }
        
        // 如果都不匹配，返回原值（让API返回错误）
        log.warn("mobile number format may be invalid: original={} cleaned={}", mobile, cleaned);
        return cleaned;
    }
}
