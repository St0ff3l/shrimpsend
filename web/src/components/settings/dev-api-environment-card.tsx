'use client';

import { useI18n } from '@/contexts/I18nContext';
import { shouldShowDevApiEnvironmentSwitcher } from '@/lib/devWebDeployment';
import { useEffect, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';

export function DevApiEnvironmentCard() {
  const { t } = useI18n();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    /* eslint-disable react-hooks/set-state-in-effect -- client-only: LAN + dev gate */
    setVisible(shouldShowDevApiEnvironmentSwitcher());
    /* eslint-enable react-hooks/set-state-in-effect */
  }, []);

  if (!visible) return null;

  return (
    <Card className="border-amber-500/35 bg-amber-500/5">
      <CardHeader className="pb-2">
        <div className="flex flex-wrap items-center gap-2">
          <CardTitle className="text-base">{t('settings.devApiEnv.title')}</CardTitle>
          <Badge variant="outline" className="border-amber-600/50 text-amber-800 dark:text-amber-300">
            {t('settings.devApiEnv.badge')}
          </Badge>
        </div>
        <CardDescription>{t('settings.devApiEnv.description')}</CardDescription>
      </CardHeader>
      <CardContent className="pt-0">
        <p className="text-xs text-muted-foreground">{t('settings.devApiEnv.hint')}</p>
      </CardContent>
    </Card>
  );
}
