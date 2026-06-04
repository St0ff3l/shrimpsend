'use client';

import { useEffect, type ReactNode } from 'react';
import { AuthProvider } from '@/contexts/AuthContext';
import { ThemeProvider } from '@/contexts/ThemeContext';
import { ColorThemeProvider } from '@/contexts/ColorThemeContext';
import { TypographyProvider } from '@/contexts/TypographyContext';
import { I18nProvider } from '@/contexts/I18nContext';
import { OpenPanelRouteTracker } from '@/components/OpenPanelRouteTracker';
import { initOpenPanelInBrowser } from '@/lib/openpanelClient';
import { COOKIE_CONSENT_EVENT, hasAnalyticsConsent } from '@/lib/privacyConsent';

/** Root client boundary: i18n outermost so Auth/toasts can use `useI18n`. */
export function ClientProviders({ children }: { children: ReactNode }) {
  useEffect(() => {
    if (hasAnalyticsConsent()) {
      initOpenPanelInBrowser();
    }

    const onConsentChange = () => {
      if (hasAnalyticsConsent()) {
        initOpenPanelInBrowser();
      }
    };

    window.addEventListener(COOKIE_CONSENT_EVENT, onConsentChange);
    return () => window.removeEventListener(COOKIE_CONSENT_EVENT, onConsentChange);
  }, []);

  return (
    <I18nProvider>
      <TypographyProvider>
        <AuthProvider>
          <OpenPanelRouteTracker />
          <ThemeProvider>
            <ColorThemeProvider>{children}</ColorThemeProvider>
          </ThemeProvider>
        </AuthProvider>
      </TypographyProvider>
    </I18nProvider>
  );
}
