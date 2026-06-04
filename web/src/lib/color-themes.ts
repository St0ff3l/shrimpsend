export type ColorThemeId =
  | 'emerald'
  | 'ocean'
  | 'sunset'
  | 'lavender'
  | 'rose'
  | 'graphite';

export type ColorTheme = {
  id: ColorThemeId;
  label: string;
  accent: string;
  light: ThemeVars;
  dark: ThemeVars;
};

type ThemeVars = {
  primary: string;
  primaryForeground: string;
  ring: string;
  bubbleOwn: string;
  accentSoft: string;
};

export const DEFAULT_COLOR_THEME: ColorThemeId = 'emerald';

export const colorThemes: readonly ColorTheme[] = [
  {
    id: 'emerald',
    label: '翡翠绿',
    accent: '#3D9B7E',
    light: {
      primary: 'oklch(0.596 0.145 163)',
      primaryForeground: 'oklch(1 0 0)',
      ring: 'oklch(0.596 0.145 163)',
      bubbleOwn: 'oklch(0.93 0.045 163)',
      accentSoft: 'oklch(0.945 0.025 163)',
    },
    dark: {
      primary: 'oklch(0.696 0.17 163)',
      primaryForeground: 'oklch(0.21 0 0)',
      ring: 'oklch(0.696 0.17 163)',
      bubbleOwn: 'oklch(0.30 0.07 163)',
      accentSoft: 'oklch(0.35 0.04 163)',
    },
  },
  {
    id: 'ocean',
    label: '海洋蓝',
    accent: '#4A72C4',
    light: {
      primary: 'oklch(0.55 0.145 258)',
      primaryForeground: 'oklch(1 0 0)',
      ring: 'oklch(0.55 0.145 258)',
      bubbleOwn: 'oklch(0.93 0.04 258)',
      accentSoft: 'oklch(0.945 0.022 258)',
    },
    dark: {
      primary: 'oklch(0.65 0.17 258)',
      primaryForeground: 'oklch(0.21 0 0)',
      ring: 'oklch(0.65 0.17 258)',
      bubbleOwn: 'oklch(0.30 0.065 258)',
      accentSoft: 'oklch(0.35 0.035 258)',
    },
  },
  {
    id: 'sunset',
    label: '暖阳橙',
    accent: '#D07840',
    light: {
      primary: 'oklch(0.63 0.155 55)',
      primaryForeground: 'oklch(1 0 0)',
      ring: 'oklch(0.63 0.155 55)',
      bubbleOwn: 'oklch(0.93 0.045 55)',
      accentSoft: 'oklch(0.945 0.025 55)',
    },
    dark: {
      primary: 'oklch(0.73 0.155 55)',
      primaryForeground: 'oklch(0.21 0 0)',
      ring: 'oklch(0.73 0.155 55)',
      bubbleOwn: 'oklch(0.30 0.065 55)',
      accentSoft: 'oklch(0.35 0.04 55)',
    },
  },
  {
    id: 'lavender',
    label: '薰衣草紫',
    accent: '#7B65B0',
    light: {
      primary: 'oklch(0.52 0.13 300)',
      primaryForeground: 'oklch(1 0 0)',
      ring: 'oklch(0.52 0.13 300)',
      bubbleOwn: 'oklch(0.93 0.04 300)',
      accentSoft: 'oklch(0.945 0.022 300)',
    },
    dark: {
      primary: 'oklch(0.62 0.15 300)',
      primaryForeground: 'oklch(0.21 0 0)',
      ring: 'oklch(0.62 0.15 300)',
      bubbleOwn: 'oklch(0.30 0.06 300)',
      accentSoft: 'oklch(0.35 0.035 300)',
    },
  },
  {
    id: 'rose',
    label: '玫瑰粉',
    accent: '#C4506A',
    light: {
      primary: 'oklch(0.56 0.165 10)',
      primaryForeground: 'oklch(1 0 0)',
      ring: 'oklch(0.56 0.165 10)',
      bubbleOwn: 'oklch(0.93 0.045 10)',
      accentSoft: 'oklch(0.945 0.025 10)',
    },
    dark: {
      primary: 'oklch(0.66 0.17 10)',
      primaryForeground: 'oklch(0.21 0 0)',
      ring: 'oklch(0.66 0.17 10)',
      bubbleOwn: 'oklch(0.30 0.065 10)',
      accentSoft: 'oklch(0.35 0.04 10)',
    },
  },
  {
    id: 'graphite',
    label: '石墨灰',
    accent: '#475569',
    light: {
      primary: 'oklch(0.446 0.043 257)',
      primaryForeground: 'oklch(1 0 0)',
      ring: 'oklch(0.446 0.043 257)',
      bubbleOwn: 'oklch(0.93 0.012 257)',
      accentSoft: 'oklch(0.945 0.006 257)',
    },
    dark: {
      primary: 'oklch(0.55 0.05 257)',
      primaryForeground: 'oklch(1 0 0)',
      ring: 'oklch(0.55 0.05 257)',
      bubbleOwn: 'oklch(0.30 0.02 257)',
      accentSoft: 'oklch(0.35 0.015 257)',
    },
  },
] as const;

export function getColorTheme(id: string): ColorTheme {
  return colorThemes.find((t) => t.id === id) ?? colorThemes[0];
}
