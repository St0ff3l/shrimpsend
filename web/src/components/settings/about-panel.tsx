'use client';

import { BrandLogo } from '@/components/brand/BrandLogo';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useI18n } from '@/contexts/I18nContext';
import { SETTINGS_APP_VERSION } from './constants';

export function AboutPanel() {
  const { t } = useI18n();
  return (
    <Card>
      <CardContent className="pt-4 pb-4">
        <div className="flex justify-center mb-3">
          <BrandLogo size={72} alt={t('common.brandName')} />
        </div>
        <p className="text-sm">{t('common.brandName')}</p>
        <p className="text-xs text-muted-foreground mt-1">{t('common.brandTagline')}</p>
        <p className="text-xs text-muted-foreground mt-2">{t('about.fontLicenses')}</p>
        <Separator className="my-2" />
        <p className="text-xs text-muted-foreground">{t('about.versionLine', { version: SETTINGS_APP_VERSION })}</p>
      </CardContent>
    </Card>
  );
}
