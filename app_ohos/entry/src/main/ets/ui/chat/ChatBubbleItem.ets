import { MessageCategory } from './MessagePreviewFormatter';
import { AppTokens } from '../theme/AppTokens';

@Component
export struct ChatBubbleItem {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop timeLabel: string = '';
  @Prop self: boolean = false;
  @Prop category: MessageCategory = 'other';

  private isSideBubble(): boolean {
    return this.category === 'user_text' || this.category === 'file';
  }

  build() {
    Column() {
      if (this.isSideBubble()) {
        Row() {
          if (!this.self) {
            Column() {
              Text(this.timeLabel)
                .fontSize(AppTokens.fontMeta)
                .fontColor($r('app.color.chat_meta_text'))
                .width('100%')
                .textAlign(TextAlign.Start)
              Column() {
                Text(this.title)
                  .fontSize(AppTokens.fontBody)
                  .fontColor($r('app.color.chat_bubble_received_text'))
                  .maxLines(40)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.subtitle.length > 0) {
                  Text(this.subtitle)
                    .fontSize(AppTokens.fontCaption)
                    .fontColor($r('app.color.chat_bubble_received_subtext'))
                    .margin({ top: AppTokens.spaceXs })
                    .maxLines(6)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .padding({
                left: AppTokens.spaceMd,
                right: AppTokens.spaceMd,
                top: AppTokens.spaceSm,
                bottom: AppTokens.spaceSm
              })
              .backgroundColor($r('app.color.chat_bubble_received'))
              .borderRadius(AppTokens.radiusMd)
              .constraintSize({ maxWidth: AppTokens.chatBubbleMaxWidthPct })
              .margin({ top: AppTokens.spaceXs })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          } else {
            Blank().layoutWeight(1)
            Column() {
              Text(this.timeLabel)
                .fontSize(AppTokens.fontMeta)
                .fontColor($r('app.color.chat_meta_text'))
                .width('100%')
                .textAlign(TextAlign.End)
              Column() {
                Text(this.title)
                  .fontSize(AppTokens.fontBody)
                  .fontColor($r('app.color.chat_bubble_sent_text'))
                  .maxLines(40)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.subtitle.length > 0) {
                  Text(this.subtitle)
                    .fontSize(AppTokens.fontCaption)
                    .fontColor($r('app.color.chat_bubble_sent_subtext'))
                    .margin({ top: AppTokens.spaceXs })
                    .maxLines(6)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .padding({
                left: AppTokens.spaceMd,
                right: AppTokens.spaceMd,
                top: AppTokens.spaceSm,
                bottom: AppTokens.spaceSm
              })
              .backgroundColor($r('app.color.chat_bubble_sent'))
              .borderRadius(AppTokens.radiusMd)
              .constraintSize({ maxWidth: AppTokens.chatBubbleMaxWidthPct })
              .margin({ top: AppTokens.spaceXs })
            }
            .alignItems(HorizontalAlign.End)
          }
        }
        .width('100%')
      } else {
        Text(this.timeLabel)
          .fontSize(AppTokens.fontMeta)
          .fontColor($r('app.color.chat_meta_text'))
          .margin({ bottom: AppTokens.spaceXs })
          .width('100%')
          .textAlign(TextAlign.Center)

        Column() {
          Text(this.title)
            .fontSize(AppTokens.fontCaption)
            .fontColor($r('app.color.chat_system_text'))
            .maxLines(12)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(AppTokens.fontMeta)
              .fontColor($r('app.color.chat_meta_text'))
              .margin({ top: AppTokens.spaceXs })
              .maxLines(8)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width(AppTokens.chatBubbleMaxWidthPct)
        .padding({
          left: AppTokens.spaceMd,
          right: AppTokens.spaceMd,
          top: AppTokens.spaceSm,
          bottom: AppTokens.spaceSm
        })
        .backgroundColor($r('app.color.chat_system_surface'))
        .borderRadius(AppTokens.radiusSm)
        .alignSelf(ItemAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: AppTokens.spaceXs, bottom: AppTokens.spaceXs })
  }
}
