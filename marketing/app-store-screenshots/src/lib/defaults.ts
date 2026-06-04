import type { Device, ProjectState, Slide } from "./types";

let _id = 0;
export const nid = () => `s_${Date.now().toString(36)}_${(_id++).toString(36)}`;

const DEFAULT_LOCALE = "zh";
const zh = (s: string) => ({ [DEFAULT_LOCALE]: s });

const IOS_SHOT = "/screenshots/apple/iphone/{locale}/";
const ANDROID_SHOT = "/screenshots/android/phone/{locale}/";

function shrimpsendSlides(screenshotBase: string): Slide[] {
  return [
    {
      id: "ss-connect",
      layout: "hero",
      label: zh("连接"),
      headline: zh("所有设备，\n一眼即连"),
      screenshot: `${screenshotBase}01-connect.png`,
    },
    {
      id: "ss-transfer",
      layout: "device-bottom",
      label: zh("传输"),
      headline: zh("像发消息一样\n传文件"),
      screenshot: `${screenshotBase}02-transfer.png`,
    },
    {
      id: "ss-s3-relay",
      layout: "device-top",
      label: zh("S3 云端"),
      headline: zh("跨网不稳？\n云端接力"),
      screenshot: `${screenshotBase}03-s3-relay.png`,
      inverted: true,
    },
    {
      id: "ss-files",
      layout: "device-bottom",
      label: zh("文件"),
      headline: zh("每次传输，\n清晰归档"),
      screenshot: `${screenshotBase}04-files.png`,
    },
  ];
}

function fgStarter(): Slide[] {
  return [
    {
      id: "ss-feature-graphic",
      layout: "feature-graphic",
      label: {},
      headline: zh("跨设备传文件，\n直达你的设备。"),
      screenshot: "",
    },
  ];
}

export const DEFAULT_PROJECT: ProjectState = {
  appName: "虾传",
  themeId: "shrimpsend-emerald",
  locales: [DEFAULT_LOCALE],
  locale: DEFAULT_LOCALE,
  device: "iphone",
  orientation: "portrait",
  appIcon: "/app-icon.png",
  slidesByDevice: {
    iphone: shrimpsendSlides(IOS_SHOT),
    android: shrimpsendSlides(ANDROID_SHOT),
    ipad: shrimpsendSlides(IOS_SHOT),
    "android-7": shrimpsendSlides(ANDROID_SHOT),
    "android-10": shrimpsendSlides(ANDROID_SHOT),
    "feature-graphic": fgStarter(),
  },
};

export function newSlide(layout: Slide["layout"] = "device-bottom"): Slide {
  return {
    id: nid(),
    layout,
    label: zh("新建"),
    headline: zh("编辑此\n标题"),
    screenshot: "",
  };
}

export function detectPlatform(device: Device): "ios" | "android" {
  return device === "iphone" || device === "ipad" ? "ios" : "android";
}
