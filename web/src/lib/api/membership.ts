import { getApiUrl, TAG, AuthError, getToken, isAuthFailure, withAuthRetry } from './client';
import { logger } from '../logger';
import { logStripeOverseasPriceDebug } from '../stripeOverseasPrices';

export type MembershipTier = {
  code: string;
  name: string;
  deviceLimit: number;
  priceCent: number;
  productType?: string;
  billingPeriod?: string;
  currency?: string;
};

export const ADDON_PRODUCT_CODE = 'ADDON_5';

export type PaymentChannel =
  | 'FREE'
  | 'APPLE_RC'
  | 'GOOGLE_RC'
  | 'STRIPE'
  | 'ALIPAY_LIFETIME';

export type MembershipMe = {
  tierCode: string;
  tierName: string;
  deviceLimit: number;
  addonPacks?: number;
  currentDeviceCount: number;
  canAddDevice: boolean;
  canBuyAddon?: boolean;
  subscriptionExpiresAtMs?: number;
  /** Stripe: true = auto-renew off, ends at subscriptionExpiresAtMs */
  subscriptionCancelAtPeriodEnd?: boolean | null;
  /** Web Stripe subscription exists — use portal / upgrade APIs */
  stripeSubscriptionPresent?: boolean | null;
  hostedUploadQuotaBytes?: number;
  hostedUploadUsedBytes?: number;
  currency?: string;
  /** Active subscription channel (cross-platform affinity). */
  paymentChannel?: PaymentChannel | string;
  /** true when the user has no active subscription channel and may start in any channel. */
  canSwitchChannel?: boolean;
};

export type MembershipOrder = {
  orderNo: string;
  fromTier: string;
  toTier: string;
  payableAmountCent: number;
  currency: string;
  channel: string;
  status: string;
  createdAt: number;
  updatedAt: number;
};

export type MembershipCreateOrderResponse = {
  order: MembershipOrder;
  /** 手机网站支付跳转链接（alipay.trade.wap.pay，GET 签名 URL） */
  alipayPayUrl?: string | null;
  /** PC 网页支付跳转链接（alipay.trade.page.pay），桌面浏览器优先使用 */
  alipayPcPayUrl?: string | null;
  /** APP 支付订单串（仅原生客户端） */
  alipayOrderString?: string | null;
};

export async function listMembershipTiers(): Promise<MembershipTier[]> {
  logger.info(TAG, 'listMembershipTiers');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/membership/tiers`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) throw new Error('errors.membershipTiersFailed');
    return await res.json() as MembershipTier[];
  });
}

export async function fetchMyMembership(): Promise<MembershipMe> {
  logger.info(TAG, 'fetchMyMembership');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/membership/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) throw new Error('errors.membershipStatusFailed');
    return await res.json() as MembershipMe;
  });
}

/** Open Stripe Customer Billing Portal (cancel / payment methods). */
export async function createStripeBillingPortalSession(): Promise<{ url: string }> {
  logger.info(TAG, 'createStripeBillingPortalSession');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/membership/stripe/billing-portal-session`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error((err as { error?: string }).error || 'Billing portal failed');
    }
    return (await res.json()) as { url: string };
  });
}

/** Upgrade existing Stripe subscription to a higher tier price (proration). */
export async function updateStripeSubscriptionPrice(priceId: string): Promise<{ status: string }> {
  logger.info(TAG, 'updateStripeSubscriptionPrice priceId=', priceId);
  logStripeOverseasPriceDebug(TAG, 'before subscription/update-price', priceId);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/membership/stripe/subscription/update-price`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ priceId }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error((err as { error?: string }).error || 'Subscription upgrade failed');
    }
    return (await res.json()) as { status: string };
  });
}

/** Overseas ShrimpSend — Stripe Checkout (price id from Stripe Dashboard). */
export async function createStripeCheckoutSession(priceId: string): Promise<{ url: string }> {
  logger.info(TAG, 'createStripeCheckoutSession priceId=', priceId);
  logStripeOverseasPriceDebug(TAG, 'before create-checkout-session', priceId);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/membership/stripe/create-checkout-session`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ priceId }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error((err as { error?: string }).error || 'Stripe checkout failed');
    }
    return (await res.json()) as { url: string };
  });
}

export async function createMembershipOrder(targetTier: string, channel: 'ALIPAY' | 'APPLE_RC'): Promise<MembershipCreateOrderResponse> {
  logger.info(TAG, 'createMembershipOrder targetTier=', targetTier, 'channel=', channel);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/membership/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify({ targetTier, channel }),
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error((err as { error?: string }).error || 'errors.membershipOrderFailed');
    }
    return await res.json() as MembershipCreateOrderResponse;
  });
}

export async function getMembershipOrder(orderNo: string): Promise<MembershipOrder> {
  logger.info(TAG, 'getMembershipOrder orderNo=', orderNo);
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('errors.notAuthenticated');
    const res = await fetch(`${getApiUrl()}/api/membership/orders/${encodeURIComponent(orderNo)}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) throw new Error('errors.membershipOrderQueryFailed');
    return await res.json() as MembershipOrder;
  });
}
