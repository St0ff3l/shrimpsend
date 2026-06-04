'use client';

import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { login as apiLogin, register as apiRegister, saveTokens, clearStorage, getAccessToken, getUserId, setOnRefreshSuccess } from '@/lib/api';
import { apiLogout } from '@/lib/api/auth';
import type { AuthResponse } from '@/lib/api';
import { getOrCreateDeviceId } from '@/lib/deviceId';
import { logger } from '@/lib/logger';
import { analyticsLengthBucket, analyticsTrack } from '@/lib/analytics';
import { AnalyticsEvents } from '@/lib/analyticsEvents';
import { getOpenPanelClient } from '@/lib/openpanelClient';

const TAG = 'AuthContext';

type AuthContextType = {
  userId: string | null;
  accessToken: string | null;
  isReady: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string, code: string, username?: string) => Promise<void>;
  logout: () => Promise<void>;
  setAuthFromTokens: (data: AuthResponse) => void;
};

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [userId, setUserId] = useState<string | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [isReady, setIsReady] = useState(false);
  const prevUserIdRef = useRef<string | null | undefined>(undefined);

  useEffect(() => {
    let cancelled = false;
    queueMicrotask(() => {
      if (cancelled) return;
      const storedToken = getAccessToken();
      const storedUserId = getUserId();
      if (storedToken && storedUserId) {
        logger.info(TAG, 'loadStored restored userId=', storedUserId);
        setUserId(storedUserId);
        setAccessToken(storedToken);
      } else {
        logger.info(TAG, 'loadStored no stored auth');
      }
      setIsReady(true);
    });
    setOnRefreshSuccess((data: AuthResponse) => {
      setUserId(data.userId);
      setAccessToken(data.accessToken);
    });
    return () => {
      cancelled = true;
      setOnRefreshSuccess(null);
    };
  }, []);

  useEffect(() => {
    if (!isReady) return;
    const op = getOpenPanelClient();
    if (!op) return;
    if (userId) {
      void op.identify({ profileId: userId });
    } else if (prevUserIdRef.current) {
      op.clear();
    }
    prevUserIdRef.current = userId;
  }, [isReady, userId]);

  const login = useCallback(async (email: string, password: string) => {
    try {
      const data = await apiLogin(email, password);
      saveTokens(data);
      setUserId(data.userId);
      setAccessToken(data.accessToken);
      logger.info(TAG, 'login success userId=', data.userId);
      analyticsTrack(AnalyticsEvents.loginSubmit, {
        result: 'success',
        length_bucket: analyticsLengthBucket(email.trim().length),
      });
    } catch (e) {
      analyticsTrack(AnalyticsEvents.loginSubmit, {
        result: 'fail',
        length_bucket: analyticsLengthBucket(email.trim().length),
      });
      throw e;
    }
  }, []);

  const register = useCallback(async (email: string, password: string, code: string, username?: string) => {
    try {
      const data = await apiRegister(email, password, code, username);
      saveTokens(data);
      setUserId(data.userId);
      setAccessToken(data.accessToken);
      logger.info(TAG, 'register success userId=', data.userId);
      analyticsTrack(AnalyticsEvents.registerSubmit, {
        result: 'success',
        length_bucket: analyticsLengthBucket(email.trim().length),
      });
    } catch (e) {
      analyticsTrack(AnalyticsEvents.registerSubmit, {
        result: 'fail',
        length_bucket: analyticsLengthBucket(email.trim().length),
      });
      throw e;
    }
  }, []);

  const logout = useCallback(async () => {
    logger.info(TAG, 'logout');
    let apiOk = true;
    try {
      const deviceId = getOrCreateDeviceId();
      await apiLogout(deviceId || undefined);
    } catch {
      apiOk = false;
    }
    clearStorage();
    setUserId(null);
    setAccessToken(null);
    analyticsTrack(AnalyticsEvents.logout, { api_logout_ok: apiOk });
  }, []);

  const setAuthFromTokens = useCallback((data: AuthResponse) => {
    setUserId(data.userId);
    setAccessToken(data.accessToken);
    logger.info(TAG, 'setAuthFromTokens userId=', data.userId);
  }, []);

  return (
    <AuthContext.Provider value={{ userId, accessToken, isReady, login, register, logout, setAuthFromTokens }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
