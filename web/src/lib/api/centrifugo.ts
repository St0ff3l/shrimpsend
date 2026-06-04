import { logger } from '../logger';
import { getApiUrl, TAG, AuthError, getToken, isAuthFailure, withAuthRetry } from './client';

export type CentrifugoTokenResponse = {
  connectionToken: string;
  subscriptionToken: string;
  channel: string;
};

export async function getCentrifugoToken(): Promise<CentrifugoTokenResponse> {
  logger.info(TAG, 'getCentrifugoToken');
  return withAuthRetry(async () => {
    const token = getToken();
    if (!token) throw new Error('Not authenticated');
    const res = await fetch(`${getApiUrl()}/api/centrifugo/token`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (isAuthFailure(res)) throw new AuthError();
    if (!res.ok) {
      logger.warn(TAG, 'getCentrifugoToken failed', res.status);
      throw new Error('Failed to get Centrifugo token');
    }
    const data = await res.json() as CentrifugoTokenResponse;
    logger.info(TAG, 'getCentrifugoToken success channel=', data.channel);
    return data;
  });
}
