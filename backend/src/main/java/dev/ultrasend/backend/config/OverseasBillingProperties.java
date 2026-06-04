package dev.ultrasend.backend.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * RevenueCat / Stripe product identifiers for ShrimpSend overseas (prod-overseas).
 * Placeholders until App Store / Play / Stripe dashboard IDs are finalized.
 */
@Getter
@Setter
@ConfigurationProperties(prefix = "app.membership.overseas")
public class OverseasBillingProperties {

    /** RevenueCat subscription product IDs */
    private String rcPlusMonthly = "shrimpsend_plus_monthly";
    private String rcPlusYearly = "shrimpsend_plus_yearly";
    private String rcProMonthly = "shrimpsend_pro_monthly";
    private String rcProYearly = "shrimpsend_pro_yearly";
    private String rcUltraMonthly = "shrimpsend_ultra_monthly";
    private String rcUltraYearly = "shrimpsend_ultra_yearly";

    /** Stripe Price IDs for web checkout */
    private String stripePricePlusMonthly = "";
    private String stripePricePlusYearly = "";
    private String stripePriceProMonthly = "";
    private String stripePriceProYearly = "";
    private String stripePriceUltraMonthly = "";
    private String stripePriceUltraYearly = "";

    private String stripeWebhookSecret = "";
    private String stripeSecretKey = "";
    private String stripeSuccessUrl = "https://shrimpsend.com/settings/membership?checkout=success";
    private String stripeCancelUrl = "https://shrimpsend.com/settings/membership?checkout=cancel";
    /** Return URL after Stripe Customer Billing Portal session */
    private String stripeBillingPortalReturnUrl = "https://shrimpsend.com/settings/membership";
}
