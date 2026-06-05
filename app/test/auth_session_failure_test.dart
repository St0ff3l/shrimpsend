import 'package:flutter_test/flutter_test.dart';
import 'package:app/api/api.dart';

void main() {
  group('classifyRefreshFailure', () {
    test('JWT signature mismatch on 500 is permanent session failure', () {
      const error = RefreshTokenException(
        'JWT signature does not match locally computed signature. '
        'JWT validity cannot be asserted and should not be trusted.',
        httpStatus: 500,
      );

      expect(
        classifyRefreshFailure(error, httpStatus: 500),
        RefreshSessionFailureKind.permanent,
      );
    });

    test('generic 500 without auth message stays transient', () {
      const error = RefreshTokenException('Internal Server Error', httpStatus: 500);

      expect(
        classifyRefreshFailure(error, httpStatus: 500),
        RefreshSessionFailureKind.transient,
      );
    });

    test('401 is permanent regardless of message', () {
      expect(
        classifyRefreshFailure(
          const RefreshTokenException('登录已失效，请重新登录', httpStatus: 401),
          httpStatus: 401,
        ),
        RefreshSessionFailureKind.permanent,
      );
    });

    test('登录已过期 message is permanent regardless of status', () {
      expect(
        classifyRefreshFailure(
          const RefreshTokenException('登录已过期，请重新登录', httpStatus: 500),
          httpStatus: 500,
        ),
        RefreshSessionFailureKind.permanent,
      );
    });
  });
}
