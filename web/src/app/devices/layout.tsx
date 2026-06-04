import type { Metadata } from 'next';
import { appRobotsNoIndex } from '@/lib/seo';

export const metadata: Metadata = {
  robots: appRobotsNoIndex,
};

export default function DevicesLayout({ children }: { children: React.ReactNode }) {
  return children;
}
