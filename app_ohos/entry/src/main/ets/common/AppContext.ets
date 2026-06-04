import { common } from '@kit.AbilityKit';

/** UIAbility 上下文，供 Preferences / RDB / 文件路径使用 */
let gAbilityContext: common.UIAbilityContext | null = null;

export function setAbilityContext(ctx: common.UIAbilityContext): void {
  gAbilityContext = ctx;
}

export function getAbilityContext(): common.UIAbilityContext {
  if (gAbilityContext === null) {
    throw new Error('Ability context not set');
  }
  return gAbilityContext;
}
