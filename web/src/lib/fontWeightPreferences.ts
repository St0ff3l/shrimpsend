/** Font weight preferences. Align key with Flutter `font_weight_preferences.dart`. */

import {
  decodeFontWeightLevel,
  encodeFontWeightLevel,
  type FontWeightLevel,
} from '@/lib/typography';

export const KEY_FONT_WEIGHT = 'ultrasend_font_weight';
export const FONT_WEIGHT_CHANGED_EVENT = 'ultrasend:font-weight-changed';

export function loadFontWeightLevel(): FontWeightLevel {
  if (typeof window === 'undefined') {
    return 'normal';
  }
  return decodeFontWeightLevel(localStorage.getItem(KEY_FONT_WEIGHT));
}

export function persistFontWeightLevel(level: FontWeightLevel): void {
  localStorage.setItem(KEY_FONT_WEIGHT, encodeFontWeightLevel(level));
  window.dispatchEvent(new CustomEvent(FONT_WEIGHT_CHANGED_EVENT));
}
