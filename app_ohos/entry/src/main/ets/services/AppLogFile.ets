import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { getAbilityContext } from '../common/AppContext';

const MAX_TAIL = 128 * 1024;

export class AppLogFile {
  static logPath(): string {
    return `${getAbilityContext().filesDir}/ultrasend_app.log`;
  }

  static append(line: string): void {
    try {
      const path = AppLogFile.logPath();
      const stamp = new Date().toISOString();
      const msg = `[${stamp}] ${line}\n`;
      try {
        const f = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.APPEND);
        const enc = new util.TextEncoder();
        const u8 = enc.encodeInto(msg);
        fs.writeSync(f.fd, u8);
        fs.closeSync(f.fd);
      } catch (_) {
        const f = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
        const enc = new util.TextEncoder();
        const u8 = enc.encodeInto(msg);
        fs.writeSync(f.fd, u8);
        fs.closeSync(f.fd);
      }
    } catch (_) {
      // ignore
    }
  }

  static readTail(): string {
    try {
      const path = AppLogFile.logPath();
      const stat = fs.statSync(path);
      const size = stat.size;
      const readLen = size > MAX_TAIL ? MAX_TAIL : size;
      const start = size - readLen;
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(readLen);
      fs.readSync(file.fd, buf, { offset: start, length: readLen });
      fs.closeSync(file.fd);
      const dec = util.TextDecoder.create('utf-8');
      return dec.decodeWithStream(new Uint8Array(buf));
    } catch (_) {
      return '';
    }
  }
}
