import type { MetadataRoute } from 'next';
import { BRAND_ICON_192_SRC, BRAND_ICON_512_SRC } from '@/lib/brandAssets';
import { getConfiguredSiteOrigin } from '@/lib/seo';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: '虾传 / ShrimpSend',
    short_name: '虾传',
    description: '跨设备消息与文件传输，支持局域网直连、WebRTC 与 S3 后备。',
    start_url: '/',
    scope: '/',
    display: 'standalone',
    background_color: '#050816',
    theme_color: '#6f88ff',
    icons: [
      {
        src: new URL(BRAND_ICON_192_SRC, getConfiguredSiteOrigin()).toString(),
        sizes: '192x192',
        type: 'image/png',
        purpose: 'any',
      },
      {
        src: new URL(BRAND_ICON_512_SRC, getConfiguredSiteOrigin()).toString(),
        sizes: '512x512',
        type: 'image/png',
        purpose: 'any',
      },
    ],
  };
}
