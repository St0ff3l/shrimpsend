/** Wide layout breakpoint — keep in sync with Tailwind `md` and Flutter `main_layout.dart`. */
export const DEVICE_LIST_WIDE_BREAKPOINT = 768;

/** Sidebar width at the minimum wide viewport (768px). */
export const DEVICE_LIST_PANEL_MIN_WIDTH = 240;

/** Sidebar width cap on very large screens. */
export const DEVICE_LIST_PANEL_MAX_WIDTH = 420;

/** Fraction of viewport width used for the device list on wide layouts. */
export const DEVICE_LIST_PANEL_WIDTH_RATIO = 0.28;

/**
 * Resolve device-list sidebar width from viewport width.
 * Narrow wide screens get a tighter list; larger screens get more room for names/status.
 */
export function resolveDeviceListPanelWidth(viewportWidth: number): number {
  if (viewportWidth < DEVICE_LIST_WIDE_BREAKPOINT) {
    return viewportWidth;
  }
  const raw = viewportWidth * DEVICE_LIST_PANEL_WIDTH_RATIO;
  return Math.round(
    Math.min(DEVICE_LIST_PANEL_MAX_WIDTH, Math.max(DEVICE_LIST_PANEL_MIN_WIDTH, raw)),
  );
}
