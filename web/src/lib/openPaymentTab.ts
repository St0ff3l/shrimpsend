/**
 * Opens a blank payment tab during the user click (synchronous). Navigate it with
 * {@link navigatePaymentTab} after the pay URL is ready so the current page stays put.
 *
 * Do not pass `noopener` to `window.open` here: modern browsers then return a handle
 * that cannot navigate the new tab, leaving it stuck on about:blank. We detach
 * `window.opener` on the child immediately after open instead.
 */
export function openPaymentTabPlaceholder(): Window | null {
  if (typeof window === 'undefined') return null;
  const tab = window.open('about:blank', '_blank');
  if (!tab) return null;
  tab.opener = null;
  return tab;
}

export function navigatePaymentTab(tab: Window, payUrl: string): void {
  if (tab.closed) return;
  try {
    tab.location.replace(payUrl);
    return;
  } catch {
    // replace may throw in edge cases; try assign / meta redirect below
  }
  try {
    tab.location.href = payUrl;
    return;
  } catch {
    // last resort: same-origin about:blank can run a redirect script
  }
  try {
    tab.document.open();
    tab.document.write(
      `<!DOCTYPE html><html><body><script>location.replace(${JSON.stringify(payUrl)});</script></body></html>`,
    );
    tab.document.close();
  } catch {
    tab.close();
    throw new Error('payment_tab_navigate_failed');
  }
}
