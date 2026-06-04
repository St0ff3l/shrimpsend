import type { MetadataRoute } from 'next';
import { absoluteUrl, getConfiguredSiteOrigin, publicPagePaths } from '@/lib/seo';

export default function sitemap(): MetadataRoute.Sitemap {
  const origin = getConfiguredSiteOrigin();
  const now = new Date();

  return publicPagePaths().map((path) => {
    const isHome = path === '/zh' || path === '/en';
    const isDocs = path.includes('/docs/');

    return {
      url: absoluteUrl(path, origin),
      lastModified: now,
      changeFrequency: isHome ? 'weekly' : 'monthly',
      priority: isHome ? 1 : isDocs ? 0.8 : 0.6,
    };
  });
}
