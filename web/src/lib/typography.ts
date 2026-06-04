/** Typography levels shared with Flutter; Web uses system fonts. */

export type FontWeightLevel =
  | 'lighter'
  | 'light'
  | 'normal'
  | 'medium'
  | 'semibold';

export const FONT_WEIGHT_LEVELS: FontWeightLevel[] = [
  'lighter',
  'light',
  'normal',
  'medium',
  'semibold',
];

export function wghtForFontWeightLevel(level: FontWeightLevel): number {
  switch (level) {
    case 'lighter':
      return 350;
    case 'light':
      return 400;
    case 'normal':
      return 450;
    case 'medium':
      return 500;
    case 'semibold':
      return 550;
    default:
      return 450;
  }
}

export function indexForFontWeightLevel(level: FontWeightLevel): number {
  return FONT_WEIGHT_LEVELS.indexOf(level);
}

export function fontWeightLevelFromIndex(index: number): FontWeightLevel {
  const clamped = Math.min(Math.max(0, index), FONT_WEIGHT_LEVELS.length - 1);
  return FONT_WEIGHT_LEVELS[clamped] ?? 'normal';
}

export function decodeFontWeightLevel(raw: string | null): FontWeightLevel {
  switch (raw) {
    case 'lighter':
    case 'light':
    case 'medium':
    case 'semibold':
      return raw;
    default:
      return 'normal';
  }
}

export function encodeFontWeightLevel(level: FontWeightLevel): string {
  return level;
}

export type FontSizeLevel = 'smaller' | 'small' | 'standard' | 'large' | 'larger';

export const FONT_SIZE_LEVELS: FontSizeLevel[] = [
  'smaller',
  'small',
  'standard',
  'large',
  'larger',
];

export function scaleForFontSizeLevel(level: FontSizeLevel): number {
  switch (level) {
    case 'smaller':
      return 0.88;
    case 'small':
      return 0.94;
    case 'standard':
      return 1;
    case 'large':
      return 1.07;
    case 'larger':
      return 1.14;
    default:
      return 1;
  }
}

export function indexForFontSizeLevel(level: FontSizeLevel): number {
  return FONT_SIZE_LEVELS.indexOf(level);
}

export function fontSizeLevelFromIndex(index: number): FontSizeLevel {
  const clamped = Math.min(Math.max(0, index), FONT_SIZE_LEVELS.length - 1);
  return FONT_SIZE_LEVELS[clamped] ?? 'standard';
}

export function decodeFontSizeLevel(raw: string | null): FontSizeLevel {
  switch (raw) {
    case 'smaller':
    case 'small':
    case 'large':
    case 'larger':
      return raw;
    default:
      return 'standard';
  }
}

export function encodeFontSizeLevel(level: FontSizeLevel): string {
  return level;
}
