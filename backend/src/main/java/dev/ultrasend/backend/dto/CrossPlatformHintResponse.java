package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Tells the calling client where the user should go to manage / upgrade their subscription
 * (cross-platform channel-affinity). Returned by {@code GET /api/membership/cross-platform-hint}.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CrossPlatformHintResponse {
    /** Current active channel: FREE / APPLE_RC / GOOGLE_RC / STRIPE / ALIPAY_LIFETIME. */
    private String paymentChannel;
    /** Where the user should go to manage: STRIPE_WEB / APP_STORE / PLAY_STORE / APP / WEB. */
    private String manageTarget;
    /** Stripe Customer Portal URL (when manageTarget == STRIPE_WEB), else null. */
    private String manageUrl;
    /** Web settings page URL (always present for overseas; web fallback). */
    private String webMembershipUrl;
    /** Apple subscriptions deep link (only meaningful on iOS). */
    private String appleSubscriptionsUrl;
    /** Google Play subscriptions deep link (only meaningful on Android). */
    private String playSubscriptionsUrl;
    /** Localization key for the user-facing hint message. */
    private String messageKey;
}
