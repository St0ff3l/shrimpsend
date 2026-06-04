/** Open an in-app or external URL in a new tab without navigating the current page. */
export function openInNewTab(url: string): void {
  if (typeof window === 'undefined') return;
  window.open(url, '_blank', 'noopener,noreferrer');
}
