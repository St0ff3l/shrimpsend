import type { MembershipTier } from '@/lib/api';

/** Mainland lifetime tier row visibility (matches Flutter `shouldShowMainlandTier`). */
export function shouldShowMainlandTier(tier: MembershipTier, currentTierCode: string): boolean {
  if (tier.productType === 'ADDON') return true;
  if (tier.code.toUpperCase() !== 'PRO') return false;
  return currentTierCode.toUpperCase() === 'FREE';
}

export function isMainlandTierPurchaseDisabled(
  tier: MembershipTier,
  currentTierCode: string,
  canBuyAddon: boolean,
  pendingOrder: boolean,
): boolean {
  if (pendingOrder) return true;
  if (tier.productType === 'ADDON') return !canBuyAddon;
  if (tier.code.toUpperCase() === 'PRO') {
    return currentTierCode.toUpperCase() !== 'FREE';
  }
  return true;
}

/** List price only — no Mini→Pro upgrade diff in UI. */
export function mainlandTierDisplayPriceCent(tier: MembershipTier): number {
  return tier.priceCent;
}
