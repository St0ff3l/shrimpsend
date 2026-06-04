const PREFIX = '[Ultrasend]';
const isProd = typeof process !== 'undefined' && process.env.NODE_ENV === 'production';

function format(tag: string, level: string, message: string, ...args: unknown[]): void {
  const line = `${PREFIX}[${tag}] ${level}: ${message}`;
  if (args.length > 0) {
    console.log(line, ...args);
  } else {
    console.log(line);
  }
}

export const logger = {
  debug(tag: string, message: string, ...args: unknown[]): void {
    if (isProd) return;
    format(tag, 'DEBUG', message, ...args);
  },
  info(tag: string, message: string, ...args: unknown[]): void {
    format(tag, 'INFO', message, ...args);
  },
  warn(tag: string, message: string, ...args: unknown[]): void {
    console.warn(`${PREFIX}[${tag}] WARN: ${message}`, ...args);
  },
  error(tag: string, message: string, ...args: unknown[]): void {
    console.error(`${PREFIX}[${tag}] ERROR: ${message}`, ...args);
  },
};
