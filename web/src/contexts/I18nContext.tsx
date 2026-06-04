'use client';

import { usePathname } from 'next/navigation';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { getApiUrl } from '@/lib/config';
import { isLocalePath, localePathToTag } from '@/lib/i18nRouting';
import type { LocaleTagValue } from '@/lib/localeRegionPreferences';
import { getRawLocaleTag, setStoredLocaleTag } from '@/lib/localeRegionPreferences';
import zhMessages from '@/messages/zh.json';
import enMessages from '@/messages/en.json';

type Messages = typeof zhMessages;

const MESSAGES: Record<LocaleTagValue, Messages> = {
  zh_CN: zhMessages,
  en: enMessages,
};

function getNestedString(obj: Record<string, unknown>, path: string): string | undefined {
  const parts = path.split('.');
  let cur: unknown = obj;
  for (const p of parts) {
    if (cur === null || typeof cur !== 'object') return undefined;
    cur = (cur as Record<string, unknown>)[p];
  }
  return typeof cur === 'string' ? cur : undefined;
}

function interpolate(template: string, vars?: Record<string, string | number>): string {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (_, k: string) =>
    vars[k] !== undefined ? String(vars[k]) : `{${k}}`,
  );
}

export type TranslateFn = (key: string, vars?: Record<string, string | number>) => string;

type I18nContextValue = {
  localeTag: LocaleTagValue;
  /** BCP 47 for Intl / html lang */
  localeBcp47: string;
  setLocaleTag: (tag: LocaleTagValue) => void;
  t: TranslateFn;
  messages: Messages;
};

const I18nContext = createContext<I18nContextValue | null>(null);

function defaultLocaleForCurrentCluster(): LocaleTagValue {
  if (typeof window === 'undefined') return 'zh_CN';
  return getApiUrl().toLowerCase().includes('shrimpsend.com') ? 'en' : 'zh_CN';
}

function localeForPath(pathname: string | null): LocaleTagValue | null {
  const firstPathSegment = pathname?.split('/').filter(Boolean)[0];
  return firstPathSegment && isLocalePath(firstPathSegment) ? localePathToTag(firstPathSegment) : null;
}

export function I18nProvider({
  children,
  initialLocaleTag,
}: {
  children: ReactNode;
  initialLocaleTag?: LocaleTagValue;
}) {
  const pathname = usePathname();
  const [localeTag, setLocaleTagState] = useState<LocaleTagValue>(initialLocaleTag ?? 'zh_CN');
  useEffect(() => {
    queueMicrotask(() => {
      if (initialLocaleTag) {
        setLocaleTagState(initialLocaleTag);
        setStoredLocaleTag(initialLocaleTag);
        return;
      }
      const tag = localeForPath(pathname) ?? getRawLocaleTag() ?? defaultLocaleForCurrentCluster();
      setLocaleTagState(tag);
      if (typeof document !== 'undefined') {
        document.documentElement.lang = tag === 'zh_CN' ? 'zh-CN' : 'en';
      }
    });
  }, [initialLocaleTag, pathname]);

  const setLocaleTag = useCallback((tag: LocaleTagValue) => {
    setLocaleTagState(tag);
    setStoredLocaleTag(tag);
  }, []);

  const messages = MESSAGES[localeTag];

  const t = useCallback(
    (key: string, vars?: Record<string, string | number>) => {
      const raw = getNestedString(messages as unknown as Record<string, unknown>, key);
      const template = raw ?? key;
      return interpolate(template, vars);
    },
    [messages],
  );

  const localeBcp47 = localeTag === 'zh_CN' ? 'zh-CN' : 'en';

  const value = useMemo<I18nContextValue>(
    () => ({
      localeTag,
      localeBcp47,
      setLocaleTag,
      t,
      messages,
    }),
    [localeTag, localeBcp47, setLocaleTag, t, messages],
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) {
    throw new Error('useI18n must be used within I18nProvider');
  }
  return ctx;
}

/** Safe for optional provider during tests; returns zh_CN / identity t when missing. */
export function useOptionalI18n(): I18nContextValue | null {
  return useContext(I18nContext);
}
