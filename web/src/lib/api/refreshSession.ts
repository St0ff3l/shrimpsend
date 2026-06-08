import { logger } from '../logger';

const TAG = 'refreshSession';

export enum RefreshSessionOutcome {
  success = 'success',
  transientFailure = 'transientFailure',
  permanentFailure = 'permanentFailure',
  noRefreshToken = 'noRefreshToken',
}

export enum RefreshSessionFailureKind {
  transient = 'transient',
  permanent = 'permanent',
}

export class RefreshTokenError extends Error {
  constructor(
    message: string,
    readonly httpStatus?: number,
  ) {
    super(message);
    this.name = 'RefreshTokenError';
  }
}

export class SessionUnavailableError extends Error {
  constructor(
    readonly kind: 'transient' | 'expired',
    message = 'Session unavailable',
  ) {
    super(message);
    this.name = 'SessionUnavailableError';
  }

  get isTransient(): boolean {
    return this.kind === 'transient';
  }

  get isExpired(): boolean {
    return this.kind === 'expired';
  }
}

/** 根据错误文案判断是否为会话/凭证失效（优先于 HTTP 5xx 的 transient 默认规则）。 */
export function isAuthSessionFailureMessage(rawMessage: string): boolean {
  const message = rawMessage.toLowerCase();
  return (
    message.includes('登录已失效') ||
    message.includes('登录已过期') ||
    message.includes('用户不存在') ||
    message.includes('jwt') ||
    message.includes('signature does not match') ||
    message.includes('cannot be asserted') ||
    message.includes('should not be trusted') ||
    (message.includes('malformed') && message.includes('token')) ||
    (message.includes('invalid') && message.includes('token')) ||
    (message.includes('invalid') && message.includes('refresh')) ||
    message.includes('expired') ||
    message.includes('refresh token') ||
    (message.includes('session') && message.includes('invalid'))
  );
}

/** 根据 refresh 失败原因区分临时网络问题与永久会话失效。 */
export function classifyRefreshFailure(
  error: unknown,
  httpStatus?: number,
): RefreshSessionFailureKind {
  if (error instanceof RefreshTokenError && error.httpStatus != null) {
    httpStatus = error.httpStatus;
  }

  if (error instanceof TypeError) {
    // fetch network failures (Failed to fetch, Load failed, etc.)
    return RefreshSessionFailureKind.transient;
  }

  if (error instanceof DOMException && error.name === 'AbortError') {
    return RefreshSessionFailureKind.transient;
  }

  if (httpStatus != null) {
    if (httpStatus === 401 || httpStatus === 403) {
      return RefreshSessionFailureKind.permanent;
    }
    if (httpStatus >= 400 && httpStatus < 500) {
      return RefreshSessionFailureKind.permanent;
    }
    if (httpStatus >= 500) {
      const message = error instanceof Error ? error.message : String(error);
      if (isAuthSessionFailureMessage(message)) {
        return RefreshSessionFailureKind.permanent;
      }
      return RefreshSessionFailureKind.transient;
    }
  }

  const message = error instanceof Error ? error.message : String(error);
  if (isAuthSessionFailureMessage(message)) {
    return RefreshSessionFailureKind.permanent;
  }

  const lower = message.toLowerCase();
  if (
    lower.includes('failed to fetch') ||
    lower.includes('networkerror') ||
    lower.includes('network request failed') ||
    lower.includes('load failed') ||
    lower.includes('connection timed out') ||
    lower.includes('connection refused') ||
    lower.includes('network is unreachable') ||
    lower.includes('operation timed out') ||
    lower.includes('timeout')
  ) {
    return RefreshSessionFailureKind.transient;
  }

  return RefreshSessionFailureKind.transient;
}

export function outcomeFromRefreshFailure(
  kind: RefreshSessionFailureKind,
): RefreshSessionOutcome {
  return kind === RefreshSessionFailureKind.permanent
    ? RefreshSessionOutcome.permanentFailure
    : RefreshSessionOutcome.transientFailure;
}

export function logRefreshFailure(
  outcome: RefreshSessionOutcome,
  failureKind: RefreshSessionFailureKind | null,
  error: unknown,
  httpStatus?: number,
  attempt = 1,
): void {
  if (outcome === RefreshSessionOutcome.success) {
    logger.info(TAG, `refreshStoredSession success attempt=${attempt}`);
    return;
  }
  logger.warn(
    TAG,
    `refreshStoredSession failed attempt=${attempt} outcome=${outcome} failureKind=${failureKind} httpStatus=${httpStatus}`,
    error,
  );
}
