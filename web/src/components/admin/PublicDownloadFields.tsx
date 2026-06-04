'use client';

import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { cn } from '@/lib/utils';
import { useState } from 'react';

export type PublicDownloadFormState = {
  mainlandMac: string;
  mainlandWin: string;
  mainlandApk: string;
  mainlandIos: string;
  overseasMac: string;
  overseasWin: string;
  overseasGooglePlay: string;
  overseasAppStore: string;
  overseasApk: string;
};

export const emptyPublicDownloadForm = (): PublicDownloadFormState => ({
  mainlandMac: '',
  mainlandWin: '',
  mainlandApk: '',
  mainlandIos: '',
  overseasMac: '',
  overseasWin: '',
  overseasGooglePlay: '',
  overseasAppStore: '',
  overseasApk: '',
});

export function publicDownloadFormFromRow(row: {
  publicMacUrlMainland?: string;
  publicWinUrlMainland?: string;
  publicApkUrlMainland?: string;
  publicIosStoreUrlMainland?: string;
  publicMacUrlOverseas?: string;
  publicWinUrlOverseas?: string;
  publicGooglePlayUrlOverseas?: string;
  publicAppStoreUrlOverseas?: string;
  publicApkUrlOverseas?: string;
}): PublicDownloadFormState {
  return {
    mainlandMac: row.publicMacUrlMainland ?? '',
    mainlandWin: row.publicWinUrlMainland ?? '',
    mainlandApk: row.publicApkUrlMainland ?? '',
    mainlandIos: row.publicIosStoreUrlMainland ?? '',
    overseasMac: row.publicMacUrlOverseas ?? '',
    overseasWin: row.publicWinUrlOverseas ?? '',
    overseasGooglePlay: row.publicGooglePlayUrlOverseas ?? '',
    overseasAppStore: row.publicAppStoreUrlOverseas ?? '',
    overseasApk: row.publicApkUrlOverseas ?? '',
  };
}

export function publicDownloadToApiBody(form: PublicDownloadFormState) {
  const t = (s: string) => s.trim();
  return {
    publicMacUrlMainland: t(form.mainlandMac) || null,
    publicWinUrlMainland: t(form.mainlandWin) || null,
    publicApkUrlMainland: t(form.mainlandApk) || null,
    publicIosStoreUrlMainland: t(form.mainlandIos) || null,
    publicMacUrlOverseas: t(form.overseasMac) || null,
    publicWinUrlOverseas: t(form.overseasWin) || null,
    publicGooglePlayUrlOverseas: t(form.overseasGooglePlay) || null,
    publicAppStoreUrlOverseas: t(form.overseasAppStore) || null,
    publicApkUrlOverseas: t(form.overseasApk) || null,
  };
}

export function publicDownloadToCreateApiBody(form: PublicDownloadFormState) {
  const t = (s: string) => s.trim();
  return {
    publicMacUrlMainland: t(form.mainlandMac) || undefined,
    publicWinUrlMainland: t(form.mainlandWin) || undefined,
    publicApkUrlMainland: t(form.mainlandApk) || undefined,
    publicIosStoreUrlMainland: t(form.mainlandIos) || undefined,
    publicMacUrlOverseas: t(form.overseasMac) || undefined,
    publicWinUrlOverseas: t(form.overseasWin) || undefined,
    publicGooglePlayUrlOverseas: t(form.overseasGooglePlay) || undefined,
    publicAppStoreUrlOverseas: t(form.overseasAppStore) || undefined,
    publicApkUrlOverseas: t(form.overseasApk) || undefined,
  };
}

type Props = {
  value: PublicDownloadFormState;
  onChange: (next: PublicDownloadFormState) => void;
  idPrefix: string;
};

export function PublicDownloadFields({ value, onChange, idPrefix }: Props) {
  const [tab, setTab] = useState<'mainland' | 'overseas'>('mainland');
  const set = (patch: Partial<PublicDownloadFormState>) => onChange({ ...value, ...patch });

  return (
    <div className="space-y-3">
      <div className="flex gap-2">
        <button
          type="button"
          className={cn(
            'rounded-lg px-3 py-1.5 text-sm font-medium transition-colors',
            tab === 'mainland' ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground',
          )}
          onClick={() => setTab('mainland')}
        >
          大陆官网
        </button>
        <button
          type="button"
          className={cn(
            'rounded-lg px-3 py-1.5 text-sm font-medium transition-colors',
            tab === 'overseas' ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground',
          )}
          onClick={() => setTab('overseas')}
        >
          海外官网
        </button>
      </div>
      <p className="text-xs text-muted-foreground">
        填写网盘或商店静态链接，用于官网下载展示；与 OTA 直传包分离。
      </p>
      {tab === 'mainland' ? (
        <div className="grid gap-3 sm:grid-cols-2">
          <UrlField id={`${idPrefix}-ml-mac`} label="macOS 安装包" placeholder="https://..." value={value.mainlandMac} onChange={(v) => set({ mainlandMac: v })} />
          <UrlField id={`${idPrefix}-ml-win`} label="Windows 安装包" placeholder="https://..." value={value.mainlandWin} onChange={(v) => set({ mainlandWin: v })} />
          <UrlField id={`${idPrefix}-ml-apk`} label="Android APK（网盘）" placeholder="https://..." value={value.mainlandApk} onChange={(v) => set({ mainlandApk: v })} />
          <UrlField id={`${idPrefix}-ml-ios`} label="iOS App Store" placeholder="https://apps.apple.com/..." value={value.mainlandIos} onChange={(v) => set({ mainlandIos: v })} />
        </div>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          <UrlField id={`${idPrefix}-os-mac`} label="macOS 安装包" placeholder="https://..." value={value.overseasMac} onChange={(v) => set({ overseasMac: v })} />
          <UrlField id={`${idPrefix}-os-win`} label="Windows 安装包" placeholder="https://..." value={value.overseasWin} onChange={(v) => set({ overseasWin: v })} />
          <UrlField id={`${idPrefix}-os-play`} label="Google Play" placeholder="https://play.google.com/store/apps/details?id=..." value={value.overseasGooglePlay} onChange={(v) => set({ overseasGooglePlay: v })} />
          <UrlField id={`${idPrefix}-os-appstore`} label="App Store" placeholder="https://apps.apple.com/app/id..." value={value.overseasAppStore} onChange={(v) => set({ overseasAppStore: v })} />
          <UrlField id={`${idPrefix}-os-apk`} label="Android APK（可选）" placeholder="海外网盘 APK" value={value.overseasApk} onChange={(v) => set({ overseasApk: v })} className="sm:col-span-2" />
        </div>
      )}
    </div>
  );
}

function UrlField({
  id,
  label,
  placeholder,
  value,
  onChange,
  className,
}: {
  id: string;
  label: string;
  placeholder: string;
  value: string;
  onChange: (v: string) => void;
  className?: string;
}) {
  return (
    <div className={cn('space-y-2', className)}>
      <Label htmlFor={id}>{label}</Label>
      <Input id={id} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder} />
    </div>
  );
}