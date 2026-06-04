import http from '@ohos.net.http';
import {
  apiUrl,
  checkAuthOk,
  requestWithAuthRetry
} from './HttpHelper';

export interface UserProfile {
  userId: string;
  email: string;
  username: string;
}

export class UserApi {
  static async fetchProfile(): Promise<UserProfile> {
    const url = apiUrl('/api/user/profile');
    const res = await requestWithAuthRetry(http.RequestMethod.GET, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '获取用户信息失败');
    const j = JSON.parse(res.body) as Record<string, Object>;
    const un = j['username'];
    return {
      userId: `${j['userId']}`,
      email: `${j['email']}`,
      username: un !== undefined ? `${un}` : ''
    };
  }

  static async sendChangePasswordCode(): Promise<void> {
    const url = apiUrl('/api/user/send-change-password-code');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    });
    await checkAuthOk(res, '发送验证码失败');
  }

  static async changePassword(code: string, newPassword: string): Promise<void> {
    const url = apiUrl('/api/user/change-password');
    const res = await requestWithAuthRetry(http.RequestMethod.POST, url, {
      'Content-Type': 'application/json'
    }, JSON.stringify({
      'code': code,
      'newPassword': newPassword
    }));
    await checkAuthOk(res, '修改密码失败');
  }
}
