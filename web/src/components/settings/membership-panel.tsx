'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import {
  ADDON_PRODUCT_CODE,
  createMembershipOrder,
  createStripeBillingPortalSession,
  createStripeCheckoutSession,
  fetchMyMembership,
  getMembershipOrder,
  listMembershipTiers,
  updateStripeSubscriptionPrice,
  type MembershipMe,
  type MembershipTier,
} from '@/lib/api';
import { decideMembershipPurchase } from '@/lib/membershipChannel';
import {
  maxYearlySavingsPercentAcrossPlans,
  OVERSEAS_PLAN_UPLOAD_GIB,
  tierForPlanAndBilling,
  yearlySavingsPercent,
  type OverseasPlanId,
  isUsdSubscriptionCatalog,
} from '@/lib/membershipOverseasCatalog';
import { stripePriceIdForTierCode } from '@/lib/stripeOverseasPrices';
import { analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { logger } from '@/lib/logger';
import { useI18n } from '@/contexts/I18nContext';
import { formatUiMessage } from '@/lib/uiMessage';
import {
  shouldShowMainlandTier,
  isMainlandTierPurchaseDisabled,
  mainlandTierDisplayPriceCent,
} from '@/lib/mainlandMembershipPurchase';
import { navigatePaymentTab, openPaymentTabPlaceholder } from '@/lib/openPaymentTab';
import { cn } from '@/lib/utils';
import { Sparkles } from 'lucide-react';

const TAG = 'membership-panel';

const OVERSEAS_PLAN_ORDER: OverseasPlanId[] = ['PLUS', 'PRO', 'ULTRA'];

function formatUsd(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}

function formatSubscriptionDate(ms: number, localeBcp47: string): string {
  try {
    return new Date(ms).toLocaleString(localeBcp47, { dateStyle: 'long', timeStyle: 'short' });
  } catch {
    return new Date(ms).toISOString();
  }
}

/** PLUS / PRO / ULTRA rank from catalog code e.g. PRO_YEARLY */
function overseasTierRankFromCatalogCode(code: string): number {
  const base = code.split('_')[0]?.toUpperCase() ?? '';
  if (base === 'PLUS') return 1;
  if (base === 'PRO') return 2;
  if (base === 'ULTRA') return 3;
  return 0;
}

/** Rank from /membership/me tierCode */
function overseasTierRankFromMe(tierCode: string): number {
  const u = tierCode.toUpperCase();
  if (u === 'PLUS') return 1;
  if (u === 'PRO') return 2;
  if (u === 'ULTRA') return 3;
  return 0;
}

export function MembershipPanel() {
  const { t, localeBcp47 } = useI18n();
  const [tiers, setTiers] = useState<MembershipTier[]>([]);
  const [me, setMe] = useState<MembershipMe | null>(null);
  const [loading, setLoading] = useState(true);
  const [pendingOrderNo, setPendingOrderNo] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [billing, setBilling] = useState<'MONTHLY' | 'YEARLY'>('YEARLY');
  const [portalLoading, setPortalLoading] = useState(false);
  const [stripeBusy, setStripeBusy] = useState(false);

  useEffect(() => {
    Promise.all([listMembershipTiers(), fetchMyMembership()])
      .then(([tierList, my]) => {
        setTiers(tierList);
        setMe(my);
      })
      .finally(() => setLoading(false));
  }, []);

  const membershipViewTracked = useRef(false);
  useEffect(() => {
    if (loading || membershipViewTracked.current) return;
    membershipViewTracked.current = true;
    analyticsTrack(AnalyticsEvents.membershipScreenView, { tier_count: tiers.length });
  }, [loading, tiers.length]);

  useEffect(() => {
    if (!pendingOrderNo) return;
    const timer = window.setInterval(async () => {
      try {
        const order = await getMembershipOrder(pendingOrderNo);
        if (order.status === 'GRANTED') {
          window.clearInterval(timer);
          setPendingOrderNo(null);
          setMessage(t('membership.paySuccess'));
          setMe(await fetchMyMembership());
        }
      } catch (e) {
        logger.warn(TAG, 'poll order failed', e);
      }
    }, 3000);
    return () => window.clearInterval(timer);
  }, [pendingOrderNo, t]);

  const currentTierCode = me?.tierCode ?? 'FREE';

  const isOverseasStripe = useMemo(() => isUsdSubscriptionCatalog(tiers), [tiers]);
  const maxYearlySavings = useMemo(() => maxYearlySavingsPercentAcrossPlans(tiers), [tiers]);

  // Cross-platform channel-affinity decision for the web surface.
  // When the user is locked to APPLE_RC / GOOGLE_RC (paid via app stores) the web
  // surface must NOT allow Stripe purchases — only show "manage in App" guidance.
  const channelDecision = useMemo(
    () => decideMembershipPurchase({ me, surface: 'stripeWeb' }),
    [me],
  );
  const lockedToStore =
    channelDecision.reason === 'boundToAppStore' ||
    channelDecision.reason === 'boundToPlayStore';

  const onManageStripe = async () => {
    try {
      setMessage(null);
      setPortalLoading(true);
      const { url } = await createStripeBillingPortalSession();
      window.location.assign(url);
    } catch (e) {
      const msg = e instanceof Error ? e.message : t('membership.manageStripeFailed');
      setMessage(msg);
      setPortalLoading(false);
    }
  };

  const onBuy = async (target: MembershipTier) => {
    let alipayTab: Window | null = null;
    try {
      setMessage(null);
      const channel =
        target.currency === 'USD' && target.productType === 'SUBSCRIPTION'
          ? 'stripe'
          : 'alipay';
      analyticsTrack(AnalyticsEvents.membershipPurchaseStart, {
        tier_code: target.code,
        channel,
      });
      if (target.currency === 'USD' && target.productType === 'SUBSCRIPTION') {
        const priceId = stripePriceIdForTierCode(target.code);
        if (!priceId) {
          setMessage(
            'Stripe Price ID not configured (NEXT_PUBLIC_STRIPE_PRICE_*). Use iOS/Android app to subscribe.',
          );
          analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
            tier_code: target.code,
            channel: 'stripe',
            status: 'failed',
            reason: 'price_missing',
          });
          return;
        }
        const currentR = overseasTierRankFromMe(me?.tierCode ?? 'FREE');
        const targetR = overseasTierRankFromCatalogCode(target.code);
        if (currentR > 0 && targetR > currentR && me?.stripeSubscriptionPresent) {
          setStripeBusy(true);
          await updateStripeSubscriptionPrice(priceId);
          setMe(await fetchMyMembership());
          setMessage(t('membership.upgradeStripeSuccess'));
          setStripeBusy(false);
          analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
            tier_code: target.code,
            channel: 'stripe',
            status: 'success',
          });
          return;
        }
        if (currentR > 0 && targetR > currentR && !me?.stripeSubscriptionPresent) {
          setMessage(t('membership.upgradeRequiresApp'));
          analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
            tier_code: target.code,
            channel: 'stripe',
            status: 'failed',
            reason: 'requires_app',
          });
          return;
        }
        const { url } = await createStripeCheckoutSession(priceId);
        window.location.assign(url);
        analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
          tier_code: target.code,
          channel: 'stripe',
          status: 'browser_opened',
        });
        return;
      }
      alipayTab = openPaymentTabPlaceholder();
      if (!alipayTab) {
        setMessage(t('membership.paymentPopupBlocked'));
        analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
          tier_code: target.code,
          channel: 'alipay',
          status: 'failed',
          reason: 'popup_blocked',
        });
        return;
      }
      const orderResp = await createMembershipOrder(target.code, 'ALIPAY');
      setPendingOrderNo(orderResp.order.orderNo);
      const pc = orderResp.alipayPcPayUrl?.trim();
      const wap = orderResp.alipayPayUrl?.trim();
      const payUrl = pc || wap;
      if (!payUrl) {
        alipayTab.close();
        alipayTab = null;
        setPendingOrderNo(null);
        setMessage(t('membership.alipayPayNotConfigured'));
        analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
          tier_code: target.code,
          channel: 'alipay',
          status: 'failed',
          reason: 'pay_url_missing',
        });
        return;
      }
      try {
        navigatePaymentTab(alipayTab, payUrl);
      } catch {
        alipayTab.close();
        alipayTab = null;
        setPendingOrderNo(null);
        setMessage(t('membership.paymentTabNavigateFailed'));
        analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
          tier_code: target.code,
          channel: 'alipay',
          status: 'failed',
          reason: 'tab_navigate_failed',
        });
        return;
      }
      alipayTab = null;
      setMessage(t('membership.orderCreated'));
      analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
        tier_code: target.code,
        channel: pc ? 'alipay_pc_web' : 'alipay_wap',
        status: 'browser_opened',
      });
    } catch (e) {
      alipayTab?.close();
      const msg = e instanceof Error ? e.message : t('membership.orderFailed');
      setMessage(msg);
      setStripeBusy(false);
      analyticsTrack(AnalyticsEvents.membershipPurchaseOutcome, {
        tier_code: target.code,
        channel:
          target.currency === 'USD' && target.productType === 'SUBSCRIPTION'
            ? 'stripe'
            : 'alipay',
        status: 'failed',
      });
    }
  };

  const purchaseDisabled = (tier: MembershipTier, isAddon: boolean) => {
    if (isAddon) return !(me?.canBuyAddon ?? false) || pendingOrderNo !== null;
    if (pendingOrderNo !== null || stripeBusy) return true;
    // Channel-affinity: app-store-bound users cannot buy on web.
    if (lockedToStore) return true;
    if (
      isOverseasStripe &&
      tier.currency === 'USD' &&
      tier.productType === 'SUBSCRIPTION'
    ) {
      const currentR = overseasTierRankFromMe(me?.tierCode ?? 'FREE');
      const targetR = overseasTierRankFromCatalogCode(tier.code);
      if (targetR <= currentR) return true;
      if (currentR > 0 && targetR > currentR && !me?.stripeSubscriptionPresent) return true;
      return false;
    }
    return isMainlandTierPurchaseDisabled(
      tier,
      currentTierCode,
      me?.canBuyAddon ?? false,
      pendingOrderNo !== null,
    );
  };

  const stripePrimaryLabel = (tier: MembershipTier) => {
    if (pendingOrderNo) return t('membership.waitingPayment');
    if (stripeBusy) return t('membership.openingPortal');
    const currentR = overseasTierRankFromMe(me?.tierCode ?? 'FREE');
    const targetR = overseasTierRankFromCatalogCode(tier.code);
    if (targetR > currentR && currentR > 0 && me?.stripeSubscriptionPresent) {
      return t('membership.upgradeStripe');
    }
    return t('membership.subscribeStripe');
  };

  const channelLockMessageKey =
    channelDecision.reason === 'boundToAppStore'
      ? 'membership.channelLockedAppStore'
      : channelDecision.reason === 'boundToPlayStore'
        ? 'membership.channelLockedPlayStore'
        : channelDecision.reason === 'lifetimeMainland'
          ? 'membership.channelLifetime'
          : null;

  return (
    <div className="space-y-6">
      {message && (
        <Alert>
          <AlertDescription>{formatUiMessage(message, t)}</AlertDescription>
        </Alert>
      )}

      {channelLockMessageKey && (
        <Alert>
          <AlertDescription>{t(channelLockMessageKey)}</AlertDescription>
        </Alert>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-base">{t('membership.currentTitle')}</CardTitle>
        </CardHeader>
        <CardContent className="pt-0 text-sm text-muted-foreground">
          {loading || !me ? (
            t('membership.loading')
          ) : (
            <div className="space-y-2">
              <div className="flex items-center gap-2">
                <Badge>{me.tierName}</Badge>
                <span>{t('membership.deviceLimit', { count: me.deviceLimit })}</span>
              </div>
              <div>{t('membership.devicesBound', { count: me.currentDeviceCount })}</div>
              {me.hostedUploadQuotaBytes != null && me.hostedUploadUsedBytes != null && (
                <div className="text-xs">
                  Hosted upload: {(me.hostedUploadUsedBytes / (1024 * 1024)).toFixed(1)} /{' '}
                  {(me.hostedUploadQuotaBytes / (1024 * 1024)).toFixed(1)} MiB / month
                </div>
              )}
              {me.addonPacks != null && me.addonPacks > 0 && (
                <div className="text-xs">
                  {t('membership.addonLine', { packs: me.addonPacks, slots: me.addonPacks * 5 })}
                </div>
              )}
              {me.tierCode !== 'FREE' && me.subscriptionExpiresAtMs != null && (
                <div className="text-xs leading-relaxed text-muted-foreground">
                  {me.subscriptionCancelAtPeriodEnd === true
                    ? t('membership.subscriptionEndsAfterCancel', {
                        date: formatSubscriptionDate(me.subscriptionExpiresAtMs, localeBcp47),
                      })
                    : me.subscriptionCancelAtPeriodEnd === false
                      ? t('membership.subscriptionRenewsAt', {
                          date: formatSubscriptionDate(me.subscriptionExpiresAtMs, localeBcp47),
                        })
                      : t('membership.subscriptionValidUntil', {
                          date: formatSubscriptionDate(me.subscriptionExpiresAtMs, localeBcp47),
                        })}
                </div>
              )}
              {isOverseasStripe && me.stripeSubscriptionPresent && (
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="mt-2 w-full sm:w-auto"
                  disabled={portalLoading || stripeBusy}
                  onClick={() => void onManageStripe()}
                >
                  {portalLoading ? t('membership.openingPortal') : t('membership.manageStripe')}
                </Button>
              )}
            </div>
          )}
        </CardContent>
      </Card>

      {isOverseasStripe && !loading && (
        <div className="space-y-6">
          <div className="flex flex-col items-stretch gap-3 sm:items-center">
            <div className="flex w-full flex-col gap-2 sm:w-auto sm:items-center">
              {/* 滑动底块固定为 50% 宽，translate 切换；按钮仅文字颜色变化，避免选中态 ring 撑开布局 */}
              <div className="mx-auto h-12 w-full max-w-md rounded-2xl border border-border/70 bg-muted/35 p-1 shadow-inner">
                <div className="relative flex h-full w-full min-w-0">
                  <div
                    aria-hidden
                    className={cn(
                      'pointer-events-none absolute inset-y-0 left-0 w-1/2 rounded-xl bg-background shadow-md ring-1 ring-border/60 transition-transform duration-200 ease-out motion-reduce:transition-none',
                      billing === 'YEARLY' && 'translate-x-full',
                    )}
                  />
                  <button
                    type="button"
                    className={cn(
                      'relative z-10 flex min-h-0 flex-1 basis-0 items-center justify-center px-2 text-sm font-semibold transition-colors',
                      billing === 'MONTHLY'
                        ? 'text-foreground'
                        : 'text-muted-foreground hover:text-foreground/90',
                    )}
                    onClick={() => setBilling('MONTHLY')}
                  >
                    <span className="whitespace-nowrap">{t('membership.billingMonthly')}</span>
                  </button>
                  <button
                    type="button"
                    className={cn(
                      'relative z-10 flex min-h-0 flex-1 basis-0 items-center justify-center gap-1.5 px-2 text-sm font-semibold transition-colors',
                      billing === 'YEARLY'
                        ? 'text-foreground'
                        : 'text-muted-foreground hover:text-foreground/90',
                    )}
                    onClick={() => setBilling('YEARLY')}
                  >
                    <span className="whitespace-nowrap">{t('membership.billingYearly')}</span>
                    {maxYearlySavings != null && (
                      <span
                        className={cn(
                          'inline-flex shrink-0 tabular-nums rounded-full px-2 py-0.5 text-[11px] font-bold leading-none',
                          billing === 'YEARLY'
                            ? 'bg-emerald-500/20 text-emerald-800 dark:text-emerald-300'
                            : 'bg-emerald-500/10 text-emerald-700/70 dark:text-emerald-400/70',
                        )}
                      >
                        −{maxYearlySavings}%
                      </span>
                    )}
                  </button>
                </div>
              </div>
              <div className="min-h-[2.75rem] px-1">
                {billing === 'YEARLY' && maxYearlySavings != null ? (
                  <p className="text-center text-xs leading-relaxed text-muted-foreground sm:px-4">
                    {t('membership.savingsVsMonthlyYear', { pct: maxYearlySavings })}
                  </p>
                ) : (
                  <p className="invisible text-center text-xs leading-relaxed sm:px-4" aria-hidden>
                    {maxYearlySavings != null
                      ? t('membership.savingsVsMonthlyYear', { pct: maxYearlySavings })
                      : '\u00a0'}
                  </p>
                )}
              </div>
            </div>
            <p className="text-center text-xs text-muted-foreground">{t('membership.planStripeHint')}</p>
          </div>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
            {OVERSEAS_PLAN_ORDER.map((planId) => {
              const tier = tierForPlanAndBilling(tiers, planId, billing);
              const monthly = tierForPlanAndBilling(tiers, planId, 'MONTHLY');
              const yearly = tierForPlanAndBilling(tiers, planId, 'YEARLY');
              const planSavings =
                monthly && yearly ? yearlySavingsPercent(monthly.priceCent, yearly.priceCent) : null;
              const isPro = planId === 'PRO';
              const uploadGib = OVERSEAS_PLAN_UPLOAD_GIB[planId];

              if (!tier) {
                return (
                  <Card key={planId} className="border-dashed opacity-60">
                    <CardContent className="py-8 text-center text-sm text-muted-foreground">
                      —
                    </CardContent>
                  </Card>
                );
              }

              const disabled = purchaseDisabled(tier, false);
              const primaryLabel = stripePrimaryLabel(tier);

              return (
                <Card
                  key={planId}
                  className={cn(
                    'relative flex flex-col overflow-hidden border-border/80 transition-shadow',
                    isPro &&
                      'border-primary/40 bg-gradient-to-b from-primary/[0.07] to-card shadow-lg ring-2 ring-primary/20',
                  )}
                >
                  {isPro && (
                    <div className="absolute right-3 top-3 flex items-center gap-1 rounded-full bg-primary px-2.5 py-1 text-[11px] font-semibold text-primary-foreground shadow-sm">
                      <Sparkles className="size-3.5 opacity-90" aria-hidden />
                      {t('membership.planPopular')}
                    </div>
                  )}
                  <CardHeader className="pb-2 pt-6">
                    <CardTitle className="flex flex-col gap-1 text-lg font-semibold tracking-tight">
                      <span>{tier.name}</span>
                      {billing === 'YEARLY' && planSavings != null && planSavings > 0 && (
                        <Badge variant="secondary" className="w-fit text-[10px] font-normal">
                          {t('membership.planYearlySave', { pct: planSavings })}
                        </Badge>
                      )}
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="flex flex-1 flex-col gap-4 pt-0">
                    <div>
                      <div className="font-display text-3xl font-bold tracking-tight text-foreground">
                        {billing === 'YEARLY'
                          ? t('membership.pricePerYear', { price: formatUsd(tier.priceCent) })
                          : t('membership.pricePerMonth', { price: formatUsd(tier.priceCent) })}
                      </div>
                      {billing === 'YEARLY' && (
                        <p className="mt-1 text-xs text-muted-foreground">
                          {t('membership.pricePerMonthEquiv', {
                            price: formatUsd(Math.round(tier.priceCent / 12)),
                          })}
                        </p>
                      )}
                    </div>

                    <ul className="space-y-2.5 text-sm text-muted-foreground">
                      <li className="flex gap-2">
                        <span className="mt-0.5 text-primary">✓</span>
                        <span>{t('membership.featureDevices', { count: tier.deviceLimit })}</span>
                      </li>
                      <li className="flex gap-2">
                        <span className="mt-0.5 text-primary">✓</span>
                        <span>{t('membership.featureUploadHosted', { gib: uploadGib })}</span>
                      </li>
                    </ul>

                    <Button
                      disabled={disabled}
                      size="lg"
                      className={cn('mt-auto w-full font-semibold', isPro && 'shadow-md')}
                      onClick={() => onBuy(tier)}
                    >
                      {primaryLabel}
                    </Button>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </div>
      )}

      {!isOverseasStripe && (
        <div className="grid gap-4 md:grid-cols-2">
          {tiers
            .filter((tier) => shouldShowMainlandTier(tier, currentTierCode))
            .map((tier) => {
              const isAddon = tier.code === ADDON_PRODUCT_CODE;
              const disabled = purchaseDisabled(tier, isAddon);
              const displayPriceCent = mainlandTierDisplayPriceCent(tier);
              return (
                <Card key={tier.code}>
                  <CardHeader>
                    <CardTitle className="flex items-center justify-between">
                      <span>{tier.name}</span>
                      <Badge variant="secondary">
                        {isAddon
                          ? t('membership.tierBadgeAddon', { n: tier.deviceLimit })
                          : t('membership.tierBadgeDevices', { n: tier.deviceLimit })}
                      </Badge>
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="pt-0">
                    <div className="text-2xl font-bold">
                      {tier.currency === 'USD'
                        ? `$${(displayPriceCent / 100).toFixed(2)}`
                        : `¥${(displayPriceCent / 100).toFixed(0)}`}
                    </div>
                    <div className="mt-1 text-xs text-muted-foreground">
                      {isAddon
                        ? t('membership.addonSubtitle')
                        : tier.productType === 'SUBSCRIPTION'
                          ? 'Subscription'
                          : t('membership.lifetimeSubtitle')}
                    </div>
                    {isAddon && !(me?.canBuyAddon ?? false) && (
                      <p className="mt-2 text-sm text-muted-foreground">
                        {t('membership.needProFirst')}
                      </p>
                    )}
                    <Separator className="my-3" />
                    <Button disabled={disabled} className="w-full" onClick={() => onBuy(tier)}>
                      {pendingOrderNo
                        ? t('membership.waitingPayment')
                        : isAddon && !(me?.canBuyAddon ?? false)
                          ? t('membership.subscribeProFirst')
                          : tier.currency === 'USD' && tier.productType === 'SUBSCRIPTION'
                            ? 'Subscribe with Stripe'
                            : t('membership.buyAlipay')}
                    </Button>
                  </CardContent>
                </Card>
              );
            })}
        </div>
      )}
    </div>
  );
}
