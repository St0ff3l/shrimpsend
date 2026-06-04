/** Font size preferences. Align key with Flutter `font_size_preferences.dart`. */

import {
  decodeFontSizeLevel,
  encodeFontSizeLevel,
  type FontSizeLevel,
} from '@/lib/typography';

export const KEY_FONT_SIZE = 'ultrasend_font_size';
export const FONT_SIZE_CHANGED_EVENT = 'ultrasend:font-size-changed';

export function loadFontSizeLevel(): FontSizeLevel {
  if (typeof window === 'undefined') {
    return 'standard';
  }
  return decodeFontSizeLevel(localStorage.getItem(KEY_FONT_SIZE));
}

export function persistFontSizeLevel(level: FontSizeLevel): void {
  localStorage.setItem(KEY_FONT_SIZE, encodeFontSizeLevel(level));
  window.dispatchEvent(new CustomEvent(FONT_SIZE_CHANGED_EVENT));
}
