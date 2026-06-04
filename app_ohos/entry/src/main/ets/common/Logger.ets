import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x3200;

export class Log {
  static info(tag: string, fmt: string, ...args: Object[]): void {
    hilog.info(DOMAIN, tag, fmt, ...args);
  }

  static warn(tag: string, fmt: string, ...args: Object[]): void {
    hilog.warn(DOMAIN, tag, fmt, ...args);
  }

  static error(tag: string, fmt: string, ...args: Object[]): void {
    hilog.error(DOMAIN, tag, fmt, ...args);
  }
}
