'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { Centrifuge } from 'centrifuge';
import { getAccessToken, getUserId, tryRefreshAndSave } from '@/lib/api';
import { getCentrifugoToken } from '@/lib/api';
import type { MessageEnvelope } from '@/lib/api';
import { useAuth } from '@/contexts/AuthContext';
import { logger } from '@/lib/logger';
import { getCentrifugoWsUrl } from '@/lib/config';

const TAG = 'useCentrifuge';

export type CentrifugeLifecycle = {
  onConnected?: () => void;
  onDisconnected?: () => void;
};

/**
 * Web 端使用 JWT token 认证连接 Centrifugo（与 Flutter 端一致）。
 * 通过 /api/centrifugo/token 获取 connectionToken + subscriptionToken，
 * 直接传给 Centrifugo SDK，无需 connect proxy。
 */
export function useCentrifuge(
  enabled: boolean,
  onMessage: (data: MessageEnvelope) => void,
  lifecycle?: CentrifugeLifecycle,
  connectData?: Record<string, unknown>,
) {
  const { accessToken } = useAuth();
  const [connected, setConnected] = useState(false);
  const centrifugeRef = useRef<Centrifuge | null>(null);
  const onMessageRef = useRef(onMessage);
  const lifecycleRef = useRef(lifecycle);
  const mountedRef = useRef(true);
  const reconnectTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    onMessageRef.current = onMessage;
  }, [onMessage]);
  useEffect(() => {
    lifecycleRef.current = lifecycle;
  }, [lifecycle]);

  const clearReconnectTimer = useCallback(() => {
    if (reconnectTimerRef.current) {
      clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
  }, []);

  useEffect(() => {
    mountedRef.current = true;

    if (!enabled) return () => {};

    const appToken = accessToken ?? getAccessToken();
    const userId = getUserId();
    if (!appToken || !userId) {
      logger.warn(TAG, 'connect skipped: no token or userId');
      return () => {};
    }

    const prev = centrifugeRef.current;
    if (prev) {
      prev.disconnect();
      centrifugeRef.current = null;
    }
    clearReconnectTimer();

    let cancelled = false;

    async function bootstrap() {
      let tokens;
      try {
        tokens = await getCentrifugoToken();
      } catch (e) {
        logger.warn(TAG, 'getCentrifugoToken failed, cannot connect:', e);
        return;
      }
      if (cancelled || !mountedRef.current) return;

      const centrifuge = new Centrifuge(getCentrifugoWsUrl(), {
        token: tokens.connectionToken,
        data: connectData,
        getToken: async () => {
          const r = await getCentrifugoToken();
          return r.connectionToken;
        },
      });
      centrifuge.on('connected', () => {
        logger.info(TAG, 'connected');
        clearReconnectTimer();
        if (mountedRef.current) setConnected(true);
        lifecycleRef.current?.onConnected?.();
      });
      centrifuge.on('disconnected', (ctx) => {
        logger.info(TAG, 'disconnected', ctx.reason || '', 'code=', ctx.code);
        if (mountedRef.current) setConnected(false);
        lifecycleRef.current?.onDisconnected?.();
        scheduleTokenRefresh();
      });
      centrifuge.on('error', (ctx) => {
        logger.warn(TAG, 'error', ctx.error?.message || ctx);
      });

      const sub = centrifuge.newSubscription(tokens.channel, {
        token: tokens.subscriptionToken,
        getToken: async () => {
          const r = await getCentrifugoToken();
          return r.subscriptionToken;
        },
      });
      sub.on('publication', (ctx) => {
        const data = ctx.data as MessageEnvelope;
        if (data && typeof data === 'object') {
          logger.debug(TAG, 'publication type=', data.type);
          onMessageRef.current(data);
        }
      });
      sub.subscribe();
      centrifuge.connect();
      centrifugeRef.current = centrifuge;
      logger.info(TAG, 'subscribe channel=', tokens.channel);

      function scheduleTokenRefresh() {
        clearReconnectTimer();
        reconnectTimerRef.current = setTimeout(() => {
          if (!mountedRef.current) return;
          if (centrifugeRef.current?.state === 'connected') return;
          logger.info(TAG, 'SDK reconnect not recovered, refreshing token');
          tryRefreshAndSave().then((ok) => {
            if (ok && mountedRef.current) {
              logger.info(TAG, 'token refreshed, will reconnect via effect');
            }
          });
        }, 3000);
      }
    }

    bootstrap();

    function handleVisibilityChange() {
      if (document.visibilityState !== 'visible' || !mountedRef.current) return;
      const c = centrifugeRef.current;
      if (!c || c.state === 'connected') return;
      logger.info(TAG, 'tab visible, connection state=', c.state, ', triggering reconnect');
      tryRefreshAndSave().then((ok) => {
        if (ok && mountedRef.current) {
          logger.info(TAG, 'visibility refresh ok, will reconnect via effect');
        } else if (mountedRef.current && centrifugeRef.current?.state !== 'connected') {
          centrifugeRef.current?.connect();
        }
      });
    }
    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      cancelled = true;
      mountedRef.current = false;
      clearReconnectTimer();
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      lifecycleRef.current?.onDisconnected?.();
      const c = centrifugeRef.current;
      if (c) {
        logger.info(TAG, 'cleanup disconnect');
        c.disconnect();
        centrifugeRef.current = null;
      }
      setConnected(false);
    };
  }, [enabled, accessToken, clearReconnectTimer, connectData]);

  return { connected };
}
