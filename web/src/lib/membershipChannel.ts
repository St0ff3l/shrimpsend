import type { MembershipMe, PaymentChannel } from './api/membership';

/** Where the buy/upgrade action is being attempted from. */
export type PurchaseSurface = 'native' | 'stripeWeb' | 'alipayApp' | 'alipayPcWeb' | 'none';

export type LockReason =
  | 'none'
  | 'boundToStripeManageOnWeb'
  | 'boundToAppStore'
  | 'boundToPlayStore'
  | 'lifetimeMainland';

export type MembershipChannelDecision = {
  canPurchase: boolean;
  reason: LockReason;
  preferredSurface: PurchaseSurface;
};

const FREE: PaymentChannel = 'FREE';

export function decideMembershipPurchase(args: {
  me: MembershipMe | null;
  surface: PurchaseSurface;
}): MembershipChannelDecision {
  const { me, surface } = args;
  const channel = (me?.paymentChannel ?? FREE).toString().toUpperCase();
  const canSwitch = me?.canSwitchChannel ?? channel === 'FREE';

  if (channel === 'FREE' || canSwitch) {
    return { canPurchase: true, reason: 'none', preferredSurface: surface };
  }

  switch (channel) {
    case 'STRIPE':
      return surface === 'stripeWeb'
        ? { canPurchase: true, reason: 'none', preferredSurface: surface }
        : {
            canPurchase: false,
            reason: 'boundToStripeManageOnWeb',
            preferredSurface: 'stripeWeb',
          };
    case 'APPLE_RC':
      return surface === 'native'
        ? { canPurchase: true, reason: 'none', preferredSurface: surface }
        : {
            canPurchase: false,
            reason: 'boundToAppStore',
            preferredSurface: 'native',
          };
    case 'GOOGLE_RC':
      return surface === 'native'
        ? { canPurchase: true, reason: 'none', preferredSurface: surface }
        : {
            canPurchase: false,
            reason: 'boundToPlayStore',
            preferredSurface: 'native',
          };
    case 'ALIPAY_LIFETIME':
      return {
        canPurchase: false,
        reason: 'lifetimeMainland',
        preferredSurface: 'none',
      };
    default:
      return { canPurchase: true, reason: 'none', preferredSurface: surface };
  }
}

/** Plus/Pro/Ultra rank from /membership/me tierCode. FREE = 0. */
export function overseasTierRankFromTierCode(tierCode: string): number {
  switch (tierCode.toUpperCase()) {
    case 'ULTRA':
      return 3;
    case 'PRO':
      return 2;
    case 'PLUS':
      return 1;
    default:
      return 0;
  }
}
