package dev.ultrasend.backend.membership;

/**
 * Payment / subscription channels tracked on entitlements and orders.
 *
 * <p>{@link #APPLE_RC} = iOS App Store via RevenueCat.
 * {@link #GOOGLE_RC} = Android Play Store via RevenueCat.
 * {@link #STRIPE} = overseas web Stripe Checkout / Portal.
 * {@link #ALIPAY} = mainland Alipay (lifetime / one-shot upgrade).
 * {@link #ALIPAY_LIFETIME} = entitlement-side label for already-granted mainland lifetime.
 */
public enum MembershipChannel {
    ALIPAY,
    ALIPAY_LIFETIME,
    APPLE_RC,
    GOOGLE_RC,
    STRIPE;

    /** Returns true if the channel represents an in-app store subscription (Apple / Google via RC). */
    public boolean isStoreSubscription() {
        return this == APPLE_RC || this == GOOGLE_RC;
    }
}
