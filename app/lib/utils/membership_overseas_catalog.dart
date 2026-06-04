import '../api/membership.dart';
import '../config/env.dart';
import '../preferences/service_region.dart';

/// Matches backend [OverseasMembershipTier] hosted monthly upload quotas (GiB).
const Map<String, int> kOverseasPlanUploadGib = {
  'PLUS': 80,
  'PRO': 250,
  'ULTRA': 800,
};

const List<String> kOverseasPlanOrder = ['PLUS', 'PRO', 'ULTRA'];

enum OverseasBilling {
  monthly,
  yearly,
}

extension OverseasBillingApi on OverseasBilling {
  String get apiValue => switch (this) {
        OverseasBilling.monthly => 'MONTHLY',
        OverseasBilling.yearly => 'YEARLY',
      };
}

bool isUsdSubscriptionCatalog(List<MembershipTier> tiers) {
  return tiers.any((t) => t.currency == 'USD' && t.productType == 'SUBSCRIPTION');
}

bool isOverseasAppContext(List<MembershipTier> tiers) {
  return Env.overseasBuild ||
      Env.prodServiceRegion == ServiceRegion.international ||
      isUsdSubscriptionCatalog(tiers);
}

/// True when all PLUS/PRO/ULTRA monthly and yearly tiers exist (ShrimpSend catalog).
bool hasCompleteOverseasPlanCodes(List<MembershipTier> tiers) {
  for (final p in kOverseasPlanOrder) {
    if (tierForPlanAndBilling(tiers, p, OverseasBilling.monthly) == null) {
      return false;
    }
    if (tierForPlanAndBilling(tiers, p, OverseasBilling.yearly) == null) {
      return false;
    }
  }
  return true;
}

/// Monthly/yearly paywall + three-column plan list (when catalog is complete).
bool showOverseasSubscriptionPaywall(List<MembershipTier> tiers) {
  return isOverseasAppContext(tiers) && hasCompleteOverseasPlanCodes(tiers);
}

MembershipTier? tierForPlanAndBilling(
  List<MembershipTier> tiers,
  String plan,
  OverseasBilling billing,
) {
  final code = '${plan}_${billing.apiValue}';
  for (final t in tiers) {
    if (t.code == code) return t;
  }
  return null;
}

/// Yearly vs paying monthly for 12 months; returns 0–100 rounded.
int yearlySavingsPercent(int monthlyCent, int yearlyCent) {
  if (monthlyCent <= 0 || yearlyCent <= 0) return 0;
  final annualIfMonthly = monthlyCent * 12;
  return ((1 - yearlyCent / annualIfMonthly) * 100).round().clamp(0, 100);
}

/// Largest savings among PLUS / PRO / ULTRA pairings (for headline badge).
int? maxYearlySavingsPercentAcrossPlans(List<MembershipTier> tiers) {
  var max = 0;
  for (final p in kOverseasPlanOrder) {
    final m = tierForPlanAndBilling(tiers, p, OverseasBilling.monthly);
    final y = tierForPlanAndBilling(tiers, p, OverseasBilling.yearly);
    if (m == null || y == null) continue;
    final pct = yearlySavingsPercent(m.priceCent, y.priceCent);
    if (pct > max) max = pct;
  }
  return max > 0 ? max : null;
}

/// Rank from `/membership/me` tierCode (base plan, not *_MONTHLY).
int overseasTierRankFromMe(String tierCode) {
  final u = tierCode.toUpperCase();
  if (u == 'PLUS') return 1;
  if (u == 'PRO') return 2;
  if (u == 'ULTRA') return 3;
  return 0;
}

/// Rank from catalog code e.g. `PRO_YEARLY` → PRO → 2.
int overseasTierRankFromCatalogCode(String code) {
  final base = code.split('_').first.toUpperCase();
  if (base == 'PLUS') return 1;
  if (base == 'PRO') return 2;
  if (base == 'ULTRA') return 3;
  return 0;
}

bool overseasSubscriptionPurchaseDisabled({
  required MembershipMe? me,
  required MembershipTier tier,
  required bool pendingOrder,
  required bool purchasing,
}) {
  if (pendingOrder || purchasing) return true;
  if (tier.currency != 'USD' || tier.productType != 'SUBSCRIPTION') return false;
  final currentR = overseasTierRankFromMe(me?.tierCode ?? 'FREE');
  final targetR = overseasTierRankFromCatalogCode(tier.code);
  return targetR <= currentR;
}

String formatUsdPrice(int priceCent) => '\$${(priceCent / 100).toStringAsFixed(2)}';
