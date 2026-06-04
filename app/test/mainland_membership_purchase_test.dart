import 'package:flutter_test/flutter_test.dart';

import 'package:app/api/membership.dart';
import 'package:app/utils/mainland_membership_purchase.dart';

MembershipMe _me({String tierCode = 'FREE', bool canBuyAddon = false}) {
  return MembershipMe(
    tierCode: tierCode,
    tierName: tierCode,
    deviceLimit: 6,
    currentDeviceCount: 0,
    canAddDevice: true,
    canBuyAddon: canBuyAddon,
  );
}

MembershipTier _tier(String code, {int priceCent = 6000, bool addon = false}) {
  return MembershipTier(
    code: code,
    name: code,
    deviceLimit: addon ? 5 : 12,
    priceCent: priceCent,
    productType: addon ? 'ADDON' : 'TIER',
  );
}

void main() {
  group('shouldShowMainlandTier', () {
    test('FREE sees pro only, not mini', () {
      expect(shouldShowMainlandTier(_tier('MINI', priceCent: 3000), 'FREE'), isFalse);
      expect(shouldShowMainlandTier(_tier('PRO'), 'FREE'), isTrue);
      expect(shouldShowMainlandTier(_tier('ADDON_5', addon: true), 'FREE'), isTrue);
    });

    test('MINI legacy user sees addon only, not pro', () {
      expect(shouldShowMainlandTier(_tier('MINI', priceCent: 3000), 'MINI'), isFalse);
      expect(shouldShowMainlandTier(_tier('PRO'), 'MINI'), isFalse);
      expect(shouldShowMainlandTier(_tier('ADDON_5', addon: true), 'MINI'), isTrue);
    });

    test('PRO hides pro tier, addon still shown', () {
      expect(shouldShowMainlandTier(_tier('PRO'), 'PRO'), isFalse);
      expect(shouldShowMainlandTier(_tier('ADDON_5', addon: true), 'PRO'), isTrue);
    });
  });

  group('isMainlandTierPurchaseDisabled', () {
    test('addon requires mini or pro membership', () {
      expect(
        isMainlandTierPurchaseDisabled(_tier('ADDON_5', addon: true), _me(), pendingOrder: false, purchasing: false),
        isTrue,
      );
      expect(
        isMainlandTierPurchaseDisabled(
          _tier('ADDON_5', addon: true),
          _me(tierCode: 'MINI', canBuyAddon: true),
          pendingOrder: false,
          purchasing: false,
        ),
        isFalse,
      );
      expect(
        isMainlandTierPurchaseDisabled(
          _tier('ADDON_5', addon: true),
          _me(tierCode: 'PRO', canBuyAddon: true),
          pendingOrder: false,
          purchasing: false,
        ),
        isFalse,
      );
    });

    test('mini user cannot buy pro', () {
      expect(
        isMainlandTierPurchaseDisabled(_tier('PRO'), _me(tierCode: 'MINI'), pendingOrder: false, purchasing: false),
        isTrue,
      );
    });

    test('pro user cannot buy pro again', () {
      expect(
        isMainlandTierPurchaseDisabled(_tier('PRO'), _me(tierCode: 'PRO'), pendingOrder: false, purchasing: false),
        isTrue,
      );
    });

    test('free user can buy pro', () {
      expect(
        isMainlandTierPurchaseDisabled(_tier('PRO'), _me(), pendingOrder: false, purchasing: false),
        isFalse,
      );
    });
  });

  group('mainlandTierDisplayPriceCent', () {
    test('always shows list price', () {
      expect(mainlandTierDisplayPriceCent(_tier('PRO')), 6000);
      expect(mainlandTierDisplayPriceCent(_tier('ADDON_5', addon: true, priceCent: 4500)), 4500);
    });
  });
}
