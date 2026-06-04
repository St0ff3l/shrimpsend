import { headers } from 'next/headers';
import { redirect } from 'next/navigation';

export default async function HomePage() {
  const host = (await headers()).get('host')?.toLowerCase() ?? '';
  redirect(host.includes('shrimpsend') ? '/en' : '/zh');
}
