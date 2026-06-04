import { LegalShell } from '@/components/legal/legal-shell';

export default function LegalLayout({ children }: { children: React.ReactNode }) {
  return <LegalShell>{children}</LegalShell>;
}
