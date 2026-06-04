import 'package:flutter_test/flutter_test.dart';
import 'package:app/chat/thread_key.dart';

void main() {
  test('one-to-one is symmetric', () {
    const acc = 'u:42';
    expect(
      threadKeyOneToOne(acc, 'device-b', 'device-a'),
      threadKeyOneToOne(acc, 'device-a', 'device-b'),
    );
    expect(threadKeyOneToOne(acc, 'device-a', 'device-b'), 'u:42|d1:device-a|d2:device-b');
  });

  test('S3 cloud key', () {
    expect(threadKeyS3Cloud('u:1'), 'u:1|kind:s3_cloud');
  });

  test('peer selection uses S3 kind', () {
    expect(
      threadKeyForPeerSelection(
        accountPart: 'u:9',
        myDeviceId: 'me',
        selectedPeerId: kS3VirtualDeviceId,
      ),
      'u:9|kind:s3_cloud',
    );
  });

  test('derive uses explicit thread key', () {
    expect(
      deriveThreadKeyForStoredMessage(
        accountPart: 'u:1',
        fromDeviceId: 'a',
        toDeviceId: 'b',
        myDeviceId: 'me',
        explicitThreadKey: 'custom',
      ),
      'custom',
    );
  });
}
