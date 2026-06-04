import connection from '@ohos.net.connection';
import { Log } from '../common/Logger';

const TAG = 'Mdns';

/**
 * mDNS 服务发现占位：Bonsoir 对齐需 WLAN + NSD API；此处提供本机局域网 IP 辅助展示。
 * 后续可接 @ohos.net.mdns / NSD 扫描 `_ultrasend._tcp` 等服务类型。
 */
export class MdnsDiscovery {
  static logLocalIpv4Hint(): void {
    try {
      const netHandle = connection.getDefaultNetSync();
      Log.info(TAG, 'defaultNet %{public}s', `${netHandle.netId}`);
    } catch (e) {
      Log.warn(TAG, 'net hint %{public}s', JSON.stringify(e));
    }
  }
}
