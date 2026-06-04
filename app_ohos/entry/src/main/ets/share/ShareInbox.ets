/** 来自 EntryAbility.onNewWant 的分享 URI，聊天页可读取后清空 */
export class ShareInbox {
  private static pending: string[] = [];

  static push(uri: string): void {
    ShareInbox.pending.push(uri);
  }

  static takeAll(): string[] {
    const copy = ShareInbox.pending.slice();
    ShareInbox.pending = [];
    return copy;
  }

  static peekCount(): number {
    return ShareInbox.pending.length;
  }
}
