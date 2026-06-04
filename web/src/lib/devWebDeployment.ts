/**
 * Whether the dev-only “API environment” card should appear in settings.
 * Not for public deployments: requires LAN-style hostname and dev-mode (or explicit opt-in).
 */

export function isLanHostname(): boolean {
  if (typeof window === 'undefined') return false;
  const h = window.location.hostname;
  return (
    h === 'localhost' ||
    h === '127.0.0.1' ||
    h.startsWith('192.168.') ||
    h.startsWith('10.')
  );
}

/**
 * Show on e.g. http://localhost:3000 in `next dev`, or when NEXT_PUBLIC_SHOW_DEV_API_ENV=1
 * (e.g. `next start` after build while still on a LAN hostname).
 */
export function shouldShowDevApiEnvironmentSwitcher(): boolean {
  if (typeof window === 'undefined') return false;
  if (!isLanHostname()) return false;
  if (process.env.NEXT_PUBLIC_SHOW_DEV_API_ENV === '1') return true;
  return process.env.NODE_ENV === 'development';
}
