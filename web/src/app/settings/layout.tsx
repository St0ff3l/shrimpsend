import type { Metadata } from 'next';
import { appRobotsNoIndex } from '@/lib/seo';
import SettingsLayoutClient from './settings-layout-client';

export const metadata: Metadata = {
  robots: appRobotsNoIndex,
};

export default function SettingsLayout({ children }: { children: React.ReactNode }) {
  return <SettingsLayoutClient>{children}</SettingsLayoutClient>;
}
