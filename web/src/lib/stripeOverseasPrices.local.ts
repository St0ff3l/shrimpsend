/**
 * 沙盒 Stripe Price 兜底（与 `web/.env.local` 中 NEXT_PUBLIC_STRIPE_SANDBOX_* 一致）。
 * 线上价格在 `.env.local` 的 NEXT_PUBLIC_STRIPE_LIVE_*；发海外生产包时设置 NEXT_PUBLIC_STRIPE_BILLING=live。
 */
export const stripeOverseasPriceLocal = {
  PLUS_MONTHLY: 'price_xxx',
  PLUS_YEARLY: 'price_xxx',
  PRO_MONTHLY: 'price_xxx',
  PRO_YEARLY: 'price_xxx',
  ULTRA_MONTHLY: 'price_xxx',
  ULTRA_YEARLY: 'price_xxx',
} as const;

export type StripeOverseasTierCode = keyof typeof stripeOverseasPriceLocal;
