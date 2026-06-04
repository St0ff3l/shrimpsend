import type { MetadataRoute } from 'next';
import { absoluteUrl, getConfiguredSiteOrigin, privateAppPaths } from '@/lib/seo';

export default function robots(): MetadataRoute.Robots {
  const origin = getConfiguredSiteOrigin();

  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: [
        ...privateAppPaths.map((path) => `${path}/`),
        ...privateAppPaths,
        '/api/',
      ],
    },
    sitemap: absoluteUrl('/sitemap.xml', origin),
    host: origin,
  };
}
