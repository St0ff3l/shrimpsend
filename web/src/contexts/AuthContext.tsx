'use client';

import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import {
  login as apiLogin,
  register as apiRegister,
  saveTokens,
  clearStorage,
  getAccessToken,
  getUserId,
  hasCompleteStoredSession,
  bootstrapStoredSession,
  RefreshSessionOutcome,
  setOnRefreshSuccess,
  scheduleProactiveTokenRefresh,
  stopProactiveTokenRefresh,
} from '@/lib/api';
import { apiLogout } from '@/lib/api/auth';
import type { AuthResponse } from '@/lib/api';
import { getOrCreateDeviceId } from '@/lib/deviceId';
import { useAuthSessionRefresh } from '@/hooks/useAuthSessionRefresh';
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

  useAuthSessionRefresh(Boolean(accessToken && userId));

  useEffect(() => {
    let cancelled = false;

    async function loadAndBootstrap() {
      if (!hasCompleteStoredSession()) {
        if (getAccessToken() || getUserId()) {
          logger.warn(TAG, 'loadStored incomplete session (missing refreshToken), clearing');
          clearStorage();
        } else {
          logger.info(TAG, 'loadStored no stored auth');
        }
        if (!cancelled) setIsReady(true);
        return;
      }

      const storedToken = getAccessToken();
      const storedUserId = getUserId();
      if (storedToken && storedUserId) {
        logger.info(TAG, 'loadStored restored userId=', storedUserId);
        if (!cancelled) {
          setUserId(storedUserId);
          setAccessToken(storedToken);
        }
      }

      const outcome = await bootstrapStoredSession();
      if (cancelled) return;

      if (
        outcome === RefreshSessionOutcome.permanentFailure
        || outcome === RefreshSessionOutcome.noRefreshToken
      ) {
        logger.warn(TAG, 'bootstrap permanent failure, clearing session outcome=', outcome);
        clearStorage();
        setUserId(null);
        setAccessToken(null);
      } else if (outcome === RefreshSessionOutcome.success) {
        const token = getAccessToken();
        const uid = getUserId();
        if (token && uid) {
          setUserId(uid);
          setAccessToken(token);
        }
      } else {
        logger.warn(TAG, 'bootstrap transient failure, keeping local session');
        scheduleProactiveTokenRefresh();
      }

      setIsReady(true);
    }

    setOnRefreshSuccess((data: AuthResponse) => {
      setUserId(data.userId);
      setAccessToken(data.accessToken);
    });

    void loadAndBootstrap();

    return () => {
      cancelled = true;
      setOnRefreshSuccess(null);
      stopProactiveTokenRefresh();
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
      scheduleProactiveTokenRefresh();
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
      scheduleProactiveTokenRefresh();
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
    stopProactiveTokenRefresh();
    clearStorage();
    setUserId(null);
    setAccessToken(null);
    analyticsTrack(AnalyticsEvents.logout, { api_logout_ok: apiOk });
  }, []);

  const setAuthFromTokens = useCallback((data: AuthResponse) => {
    saveTokens(data);
    setUserId(data.userId);
    setAccessToken(data.accessToken);
    scheduleProactiveTokenRefresh();
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
