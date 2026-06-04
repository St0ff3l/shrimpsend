'use client';

import { useEffect, useState } from 'react';

/**
 * Subscribes to a CSS media query. SSR / first paint returns `false` to avoid hydration mismatch.
 */
export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const m = window.matchMedia(query);
    const initialTimer = window.setTimeout(() => setMatches(m.matches), 0);
    const onChange = () => setMatches(m.matches);
    m.addEventListener('change', onChange);
    return () => {
      window.clearTimeout(initialTimer);
      m.removeEventListener('change', onChange);
    };
  }, [query]);

  return matches;
}

/** Tailwind `md` breakpoint (768px). */
export function useMinWidthMd(): boolean {
  return useMediaQuery('(min-width: 768px)');
}
