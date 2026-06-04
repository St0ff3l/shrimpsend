import type { MembershipTier } from '@/lib/api';

/** Matches backend OverseasMembershipTier hosted monthly upload quotas (GiB). */
export const OVERSEAS_PLAN_UPLOAD_GIB: Record<'PLUS' | 'PRO' | 'ULTRA', number> = {
  PLUS: 80,
  PRO: 250,
  ULTRA: 800,
};

export type OverseasPlanId = 'PLUS' | 'PRO' | 'ULTRA';

export function isUsdSubscriptionCatalog(tiers: MembershipTier[]): boolean {
  return tiers.some((t) => t.currency === 'USD' && t.productType === 'SUBSCRIPTION');
}

export function tierForPlanAndBilling(
  tiers: MembershipTier[],
  plan: OverseasPlanId,
  billing: 'MONTHLY' | 'YEARLY',
): MembershipTier | undefined {
  return tiers.find((t) => t.code === `${plan}_${billing}`);
}

/** Yearly vs paying monthly for 12 months; returns 0–100 rounded. */
export function yearlySavingsPercent(monthlyCent: number, yearlyCent: number): number {
  if (monthlyCent <= 0 || yearlyCent <= 0) return 0;
  const annualIfMonthly = monthlyCent * 12;
  return Math.max(0, Math.round((1 - yearlyCent / annualIfMonthly) * 100));
}

/** Largest savings among PLUS / PRO / ULTRA pairings (for headline badge). */
export function maxYearlySavingsPercentAcrossPlans(tiers: MembershipTier[]): number | null {
  const plans: OverseasPlanId[] = ['PLUS', 'PRO', 'ULTRA'];
  let max = 0;
  for (const p of plans) {
    const m = tierForPlanAndBilling(tiers, p, 'MONTHLY');
    const y = tierForPlanAndBilling(tiers, p, 'YEARLY');
    if (!m || !y) continue;
    max = Math.max(max, yearlySavingsPercent(m.priceCent, y.priceCent));
  }
  return max > 0 ? max : null;
}
