#!/usr/bin/env node
/**
 * Headless export for ShrimpSend store screenshots.
 * Requires: dev server running at BASE_URL (default http://localhost:3000)
 *
 * Usage:
 *   npm run dev   # in another terminal
 *   npm run export
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "output");
const BASE_URL = process.env.EXPORT_BASE_URL || "http://localhost:3000";
const CHROME =
  process.env.PUPPETEER_EXECUTABLE_PATH ||
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const EXPORTS = [
  { platformTab: "ios", device: "iphone", label: "iPhone", pickDevice: false },
  { platformTab: "android", device: "android", label: "Android Phone", pickDevice: false },
  {
    platformTab: "android",
    device: "feature-graphic",
    label: "Feature Graphic",
    pickDevice: true,
  },
];

async function waitForServer(page, url, attempts = 30) {
  for (let i = 0; i < attempts; i++) {
    try {
      await page.goto(url, { waitUntil: "load", timeout: 15000 });
      return;
    } catch {
      await sleep(1000);
    }
  }
  throw new Error(`Server not reachable at ${url}`);
}

async function clickTab(page, tab) {
  const tabs = await page.$$('[role="tab"]');
  for (const t of tabs) {
    const text = await page.evaluate((el) => el.textContent?.trim(), t);
    if (text?.toLowerCase() === tab) {
      await t.click();
      await sleep(500);
      return;
    }
  }
  throw new Error(`Tab not found: ${tab}`);
}

async function selectDevice(page, deviceValue) {
  const labelMap = {
    iphone: "iPhone",
    android: "Android Phone",
    "feature-graphic": "Feature Graphic",
  };
  const targetLabel = labelMap[deviceValue] || deviceValue;
  const deviceLabels = Object.values(labelMap);

  const triggerIdx = await page.evaluate((labels) => {
    const boxes = Array.from(document.querySelectorAll('[role="combobox"]'));
    return boxes.findIndex((el) => labels.some((l) => (el.textContent || "").includes(l)));
  }, deviceLabels);
  if (triggerIdx < 0) throw new Error("Device combobox not found");

  const triggers = await page.$$('[role="combobox"]');
  const trigger = triggers[triggerIdx];
  const current = await page.evaluate((el) => el.textContent?.trim() || "", trigger);
  if (current.includes(targetLabel)) return;

  await trigger.click();
  await page.waitForSelector('[role="option"]', { timeout: 10000 });
  const clicked = await page.evaluate((label) => {
    const opts = Array.from(document.querySelectorAll('[role="option"]'));
    const hit =
      opts.find((o) => (o.textContent || "").trim() === label) ||
      opts.find((o) => (o.textContent || "").includes(label));
    if (hit) {
      hit.click();
      return true;
    }
    return false;
  }, targetLabel);
  if (!clicked) throw new Error(`Could not select device: ${deviceValue}`);
  await sleep(800);
}

async function waitForEditor(page) {
  await page.waitForFunction(
    () => {
      const buttons = Array.from(document.querySelectorAll("button"));
      return buttons.some((b) => b.textContent?.includes("Export bundle"));
    },
    { timeout: 60000 },
  );
  await sleep(5000);
}

async function exportOne(spec) {
  const downloadDir = path.join(OUT_DIR, spec.device);
  fs.mkdirSync(downloadDir, { recursive: true });

  const browser = await puppeteer.launch({
    headless: true,
    executablePath: CHROME,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });

  try {
    const page = await browser.newPage();
    const client = await page.createCDPSession();
    await client.send("Page.setDownloadBehavior", {
      behavior: "allow",
      downloadPath: downloadDir,
    });

    await waitForServer(page, BASE_URL);
    await waitForEditor(page);
    await clickTab(page, spec.platformTab);
    if (spec.pickDevice) await selectDevice(page, spec.device);
    await sleep(2000);

    const before = new Set(fs.readdirSync(downloadDir));
    await page.evaluate(() => {
      const buttons = Array.from(document.querySelectorAll("button"));
      const btn = buttons.find((b) => b.textContent?.includes("Export bundle"));
      btn?.click();
    });

    const timeoutMs = spec.device === "iphone" ? 180000 : 120000;
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      const zips = fs
        .readdirSync(downloadDir)
        .filter((f) => f.endsWith(".zip") && !before.has(f));
      if (zips.length > 0) {
        return path.join(downloadDir, zips[0]);
      }
      await sleep(1000);
    }
    throw new Error(`Export timed out for ${spec.label}`);
  } finally {
    await browser.close();
  }
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const results = [];

  for (const spec of EXPORTS) {
    console.log(`Exporting ${spec.label} ...`);
    const zipPath = await exportOne(spec);
    console.log(`  ✓ ${zipPath}`);
    results.push(zipPath);
  }

  console.log("\nDone. Exported zips:");
  for (const p of results) console.log(`  ${p}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
