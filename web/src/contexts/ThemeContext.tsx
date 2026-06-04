'use client';

import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';

const STORAGE_KEY = 'ultrasend-theme';

export type ThemeMode = 'light' | 'dark' | 'system';

type ThemeContextType = {
  theme: ThemeMode;
  setTheme: (theme: ThemeMode) => void;
  resolved: 'light' | 'dark';
};

const ThemeContext = createContext<ThemeContextType | null>(null);

function loadStored(): ThemeMode {
  if (typeof window === 'undefined') return 'system';
  const v = localStorage.getItem(STORAGE_KEY);
  if (v === 'light' || v === 'dark' || v === 'system') return v;
  return 'system';
}

function getSystemDark(): boolean {
  if (typeof window === 'undefined') return true;
  return window.matchMedia('(prefers-color-scheme: dark)').matches;
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<ThemeMode>('system');
  const [resolved, setResolved] = useState<'light' | 'dark'>(() =>
    getSystemDark() ? 'dark' : 'light'
  );

  useEffect(() => {
    queueMicrotask(() => setThemeState(loadStored()));
  }, []);

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const updateResolved = () => {
      const sysDark = media.matches;
      setResolved(theme === 'system' ? (sysDark ? 'dark' : 'light') : theme);
    };
    updateResolved();
    media.addEventListener('change', updateResolved);
    return () => media.removeEventListener('change', updateResolved);
  }, [theme]);

  useEffect(() => {
    const next = resolved === 'dark';
    if (next) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [resolved]);

  const setTheme = useCallback((value: ThemeMode) => {
    setThemeState(value);
    localStorage.setItem(STORAGE_KEY, value);
  }, []);

  return (
    <ThemeContext.Provider value={{ theme, setTheme, resolved }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider');
  return ctx;
}
