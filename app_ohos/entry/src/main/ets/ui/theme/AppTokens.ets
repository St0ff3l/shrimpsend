/**
 * 设计令牌（数值类；颜色优先用 $r('app.color.*')）
 * 对齐 Flutter AppSpacing / AppRadius / AppSize 量级
 */
export class AppTokens {
  static readonly spaceXs: number = 4;
  static readonly spaceSm: number = 8;
  static readonly spaceMd: number = 12;
  static readonly spaceLg: number = 16;
  static readonly spaceXl: number = 24;

  static readonly radiusSm: number = 12;
  static readonly radiusMd: number = 16;
  static readonly radiusLg: number = 20;

  static readonly fontTitle: number = 22;
  static readonly fontHeadline: number = 18;
  static readonly fontBody: number = 16;
  static readonly fontCaption: number = 12;
  static readonly fontMeta: number = 11;

  /** 与 Flutter controlHeight ~52 接近 */
  static readonly controlHeight: number = 48;

  static readonly chatBubbleMaxWidthPct: string = '82%';

  static readonly formMaxWidth: number = 440;
}
