import type { Metadata } from 'next';
import { appRobotsNoIndex } from '@/lib/seo';
import AdminLayoutClient from './admin-layout-client';

export const metadata: Metadata = {
  robots: appRobotsNoIndex,
};

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return <AdminLayoutClient>{children}</AdminLayoutClient>;
}
