/**
 * Map ShrimpSend tier codes to Stripe Price IDs.
 *
 * 沙盒 / 线上两套变量均在 `web/.env`：
 * - `NEXT_PUBLIC_STRIPE_BILLING=sandbox|live` 选择使用哪一套
 * - `NEXT_PUBLIC_STRIPE_SANDBOX_*` / `NEXT_PUBLIC_STRIPE_LIVE_*`
 *
 * 必须用静态 `process.env.NEXT_PUBLIC_*` 访问，Next 才能在构建时内联进客户端。
 * 兜底：`stripeOverseasPrices.local.ts`（沙盒默认值）。
 */
import {
  stripeOverseasPriceLocal,
  type StripeOverseasTierCode,
} from '@/lib/stripeOverseasPrices.local';
import { logger } from '@/lib/logger';

function envOrLocal(env: string | undefined, local: string): string | undefined {
  if (typeof env === 'string' && env.trim()) {
    return env.trim();
  }
  if (typeof local === 'string' && local.trim()) {
    return local.trim();
  }
  return undefined;
}

/** true = 使用 NEXT_PUBLIC_STRIPE_LIVE_*；否则使用 SANDBOX_* */
function isLiveStripeBilling(): boolean {
  const m = process.env.NEXT_PUBLIC_STRIPE_BILLING?.trim().toLowerCase();
  return m === 'live' || m === 'production';
}

function pickTier(
  live: string | undefined,
  sandbox: string | undefined,
  local: string,
): string | undefined {
  return envOrLocal(isLiveStripeBilling() ? live : sandbox, local);
}

const OVERSEAS_STRIPE_TIER_CODES: StripeOverseasTierCode[] = [
  'PLUS_MONTHLY',
  'PLUS_YEARLY',
  'PRO_MONTHLY',
  'PRO_YEARLY',
  'ULTRA_MONTHLY',
  'ULTRA_YEARLY',
];

/** 当前构建/运行选择的计费模式（用于调试日志）。 */
export function stripeOverseasBillingLabel(): string {
  return isLiveStripeBilling() ? 'live' : 'sandbox';
}

/** Resolved Price ID per catalog tier. */
export function resolvedStripeOverseasPriceMap(): Record<StripeOverseasTierCode, string | undefined> {
  const out = {} as Record<StripeOverseasTierCode, string | undefined>;
  for (const code of OVERSEAS_STRIPE_TIER_CODES) {
    out[code] = stripePriceIdForTierCode(code);
  }
  return out;
}

/** Log client-side Stripe price resolution (browser console + same logger as API). */
export function logStripeOverseasPriceDebug(
  tag: string,
  context: string,
  incomingPriceId?: string,
): void {
  const payload = {
    billing: stripeOverseasBillingLabel(),
    incoming: incomingPriceId ?? '(n/a)',
    catalog: resolvedStripeOverseasPriceMap(),
  };
  console.info(`[stripe][${context}]`, payload);
  logger.info(tag, `[stripe] ${context}`, payload);
}

export function stripePriceIdForTierCode(code: string): string | undefined {
  switch (code) {
    case 'PLUS_MONTHLY':
      return pickTier(
        process.env.NEXT_PUBLIC_STRIPE_LIVE_PLUS_MONTHLY,
        process.env.NEXT_PUBLIC_STRIPE_SANDBOX_PLUS_MONTHLY,
        stripeOverseasPriceLocal.PLUS_MONTHLY,
      );
    case 'PLUS_YEARLY':
      return pickTier(
        process.env.NEXT_PUBLIC_STRIPE_LIVE_PLUS_YEARLY,
        process.env.NEXT_PUBLIC_STRIPE_SANDBOX_PLUS_YEARLY,
        stripeOverseasPriceLocal.PLUS_YEARLY,
      );
    case 'PRO_MONTHLY':
      return pickTier(
        process.env.NEXT_PUBLIC_STRIPE_LIVE_PRO_MONTHLY,
        process.env.NEXT_PUBLIC_STRIPE_SANDBOX_PRO_MONTHLY,
        stripeOverseasPriceLocal.PRO_MONTHLY,
      );
    case 'PRO_YEARLY':
      return pickTier(
        process.env.NEXT_PUBLIC_STRIPE_LIVE_PRO_YEARLY,
        process.env.NEXT_PUBLIC_STRIPE_SANDBOX_PRO_YEARLY,
        stripeOverseasPriceLocal.PRO_YEARLY,
      );
    case 'ULTRA_MONTHLY':
      return pickTier(
        process.env.NEXT_PUBLIC_STRIPE_LIVE_ULTRA_MONTHLY,
        process.env.NEXT_PUBLIC_STRIPE_SANDBOX_ULTRA_MONTHLY,
        stripeOverseasPriceLocal.ULTRA_MONTHLY,
      );
    case 'ULTRA_YEARLY':
      return pickTier(
        process.env.NEXT_PUBLIC_STRIPE_LIVE_ULTRA_YEARLY,
        process.env.NEXT_PUBLIC_STRIPE_SANDBOX_ULTRA_YEARLY,
        stripeOverseasPriceLocal.ULTRA_YEARLY,
      );
    default:
      return undefined;
  }
}
