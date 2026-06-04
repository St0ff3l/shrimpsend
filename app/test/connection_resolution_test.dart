import 'package:flutter_test/flutter_test.dart';
import 'package:app/network/connection_resolution.dart';
import 'package:app/network/link_models.dart';
import 'package:app/providers/device_provider.dart';

void main() {
  group('resolveSendModeAutoPreferHttp', () {
    List<ConnectionCandidate> candidates({
      bool lan = false,
      bool webrtc = false,
      bool s3 = false,
    }) {
      return [
        ConnectionCandidate(
          mode: SendMode.lan,
          kind: SmartLinkKind.sameLan,
          available: lan,
          reason: '',
        ),
        ConnectionCandidate(
          mode: SendMode.webrtc,
          kind: SmartLinkKind.sameLan,
          available: webrtc,
          reason: '',
        ),
        ConnectionCandidate(
          mode: SendMode.s3,
          kind: SmartLinkKind.internetRelay,
          available: s3,
          reason: '',
        ),
      ];
    }

    test('prefers lan when all available', () {
      expect(
        resolveSendModeAutoPreferHttp(
          candidates: candidates(lan: true, webrtc: true, s3: true),
          isLoggedIn: true,
          isRegisteredPeer: true,
        ),
        SendMode.lan,
      );
    });

    test('falls back to s3 when only s3 available', () {
      expect(
        resolveSendModeAutoPreferHttp(
          candidates: candidates(s3: true),
          isLoggedIn: true,
          isRegisteredPeer: true,
        ),
        SendMode.s3,
      );
    });

    test('upgrades from s3 to lan when http comes online', () {
      final onlyS3 = resolveSendModeAutoPreferHttp(
        candidates: candidates(s3: true),
        isLoggedIn: true,
        isRegisteredPeer: true,
      );
      expect(onlyS3, SendMode.s3);

      final withHttp = resolveSendModeAutoPreferHttp(
        candidates: candidates(lan: true, s3: true),
        isLoggedIn: true,
        isRegisteredPeer: true,
      );
      expect(withHttp, SendMode.lan);
    });
  });
}
