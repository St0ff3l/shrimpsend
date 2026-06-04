import type { Metadata } from 'next';
import zhMessages from '@/messages/zh.json';
import { appRobotsNoIndex } from '@/lib/seo';

export const metadata: Metadata = {
  title: zhMessages.metadata.registerTitle,
  description: zhMessages.metadata.registerDescription,
  robots: appRobotsNoIndex,
};

export default function RegisterLayout({ children }: { children: React.ReactNode }) {
  return children;
}
