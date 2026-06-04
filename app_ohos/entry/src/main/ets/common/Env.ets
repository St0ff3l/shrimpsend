/**
 * 对齐 Flutter app/lib/config/env.dart（默认开发地址可按构建替换）
 */
export enum AppEnv {
  DEV = 0,
  PROD = 1
}

/** 与 Flutter ServiceRegion / mainland_china | international 对应 */
export enum ServiceRegion {
  MAINLAND_CHINA = 0,
  INTERNATIONAL = 1
}

export class Env {
  private static currentEnv: AppEnv = AppEnv.DEV;
  private static prodRegion: ServiceRegion = ServiceRegion.MAINLAND_CHINA;

  /** Release 构建可在入口改为 PROD */
  static setEnv(env: AppEnv): void {
    Env.currentEnv = env;
  }

  static getCurrent(): AppEnv {
    return Env.currentEnv;
  }

  static setProdRegion(region: ServiceRegion): void {
    Env.prodRegion = region;
  }

  static get apiUrl(): string {
    if (Env.currentEnv !== AppEnv.PROD) {
      return Env.DEV_API;
    }
    return Env.prodRegion === ServiceRegion.INTERNATIONAL ? Env.PROD_API_SHRIMPSEND : Env.PROD_API_XIACHUAN;
  }

  static get centrifugoWs(): string {
    if (Env.currentEnv !== AppEnv.PROD) {
      return Env.DEV_WS;
    }
    return Env.prodRegion === ServiceRegion.INTERNATIONAL ? Env.PROD_WS_SHRIMPSEND : Env.PROD_WS_XIACHUAN;
  }

  static get label(): string {
    return Env.currentEnv === AppEnv.PROD ? '线上' : '测试';
  }

  private static readonly DEV_API = 'http://192.168.0.100:9000';
  private static readonly DEV_WS = 'ws://192.168.0.100:8000/connection/websocket';
  private static readonly PROD_API_XIACHUAN = 'https://api.xiachuan.net';
  private static readonly PROD_WS_XIACHUAN = 'wss://ws.xiachuan.net/connection/websocket';
  private static readonly PROD_API_SHRIMPSEND = 'https://api.shrimpsend.com';
  private static readonly PROD_WS_SHRIMPSEND = 'wss://ws.shrimpsend.com/connection/websocket';
}
