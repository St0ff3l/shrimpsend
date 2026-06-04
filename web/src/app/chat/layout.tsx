import type { Metadata } from 'next';
import { appRobotsNoIndex } from '@/lib/seo';

export const metadata: Metadata = {
  robots: appRobotsNoIndex,
};

export default function ChatLayout({ children }: { children: React.ReactNode }) {
  return children;
}
