'use client';

import { useI18n } from '@/contexts/I18nContext';
import {
  LANDING_HERO_SHOWCASE_HAS_2X,
  LANDING_HERO_SHOWCASE_HEIGHT,
  LANDING_HERO_SHOWCASE_SRC,
  LANDING_HERO_SHOWCASE_SRC_2X,
  LANDING_HERO_SHOWCASE_WIDTH,
} from '@/lib/landingAssets';
import { cn } from '@/lib/utils';

type Props = {
  /** `hero` — first-screen right column; `section` — full-width block below hero (legacy). */
  variant?: 'hero' | 'section';
};

export function LandingShowcaseImage({ variant = 'hero' }: Props) {
  const { t } = useI18n();

  const sizes = variant === 'hero' ? '(max-width: 1024px) 100vw, 600px' : `(max-width: ${LANDING_HERO_SHOWCASE_WIDTH}px) 100vw, ${LANDING_HERO_SHOWCASE_WIDTH}px`;
  const srcSet = LANDING_HERO_SHOWCASE_HAS_2X
    ? `${LANDING_HERO_SHOWCASE_SRC} 1x, ${LANDING_HERO_SHOWCASE_SRC_2X} 2x`
    : undefined;

  const image = (
    // Native <picture> — no Next.js re-encode; lossless WebP + optional @2x for Retina.
    <picture>
      <source srcSet={srcSet ?? LANDING_HERO_SHOWCASE_SRC} sizes={sizes} type="image/webp" />
      <img
        src={LANDING_HERO_SHOWCASE_SRC}
        srcSet={srcSet}
        sizes={sizes}
        alt={t('landing.showcaseAlt')}
        width={LANDING_HERO_SHOWCASE_WIDTH}
        height={LANDING_HERO_SHOWCASE_HEIGHT}
        decoding="async"
        fetchPriority="high"
        className="h-auto w-full"
      />
    </picture>
  );

  const frame = (
    <div className="overflow-hidden rounded-3xl border border-white/10 bg-white/[0.04] shadow-2xl shadow-black/25 ring-1 ring-white/[0.06]">
      {image}
    </div>
  );

  if (variant === 'hero') {
    return <div className={cn('relative mx-auto w-full motion-safe:animate-app-fade-up')}>{frame}</div>;
  }

  return (
    <section className="relative z-10 mx-auto w-full max-w-7xl px-5 pb-12 md:px-8 lg:pb-16">
      {frame}
    </section>
  );
}
