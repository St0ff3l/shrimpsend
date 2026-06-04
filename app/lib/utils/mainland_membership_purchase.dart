import '../api/membership.dart';

/// Whether a mainland (CNY buyout) tier row should appear in the membership list.
/// 新购仅 Pro + 增购；Mini 已停售，存量 Mini 用户不再展示 Pro 升级。
bool shouldShowMainlandTier(MembershipTier tier, String currentTierCode) {
  if (tier.isAddon) return true;
  if (tier.code.toUpperCase() != 'PRO') return false;
  return currentTierCode.toUpperCase() == 'FREE';
}

/// Mainland lifetime tier / add-on purchase button state.
bool isMainlandTierPurchaseDisabled(
  MembershipTier tier,
  MembershipMe? me, {
  required bool pendingOrder,
  required bool purchasing,
}) {
  if (pendingOrder || purchasing) return true;
  if (tier.isAddon) return !(me?.canBuyAddon ?? false);
  final current = (me?.tierCode ?? 'FREE').toUpperCase();
  if (tier.code.toUpperCase() == 'PRO') {
    return current != 'FREE';
  }
  return true;
}

/// Price shown on the card (list price; no tier upgrade diff in UI).
int mainlandTierDisplayPriceCent(MembershipTier tier) {
  return tier.priceCent;
}
