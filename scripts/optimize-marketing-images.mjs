#!/usr/bin/env node
/** Convert marketing banner source to lossless WebP (no resize) for README + landing page. */

import { createRequire } from 'node:module';
import { access, copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const BANNER_SOURCE = path.join(ROOT, 'marketing', 'banner-source.png');
const BANNER_SOURCE_2X = path.join(ROOT, 'marketing', 'banner-source@2x.png');
const LANDING_ASSETS = path.join(ROOT, 'web', 'src', 'lib', 'landingAssets.ts');

const require = createRequire(path.join(ROOT, 'web', 'package.json'));
const sharp = require('sharp');

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  return `${(bytes / 1024).toFixed(1)} KB`;
}

function labelFor(filePath) {
  return path.relative(ROOT, filePath);
}

async function fileExists(filePath) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

function extForFormat(format) {
  if (format === 'jpeg') return '.jpg';
  if (format === 'png') return '.png';
  if (format === 'webp') return '.webp';
  return '.bin';
}

async function convertBanner({ inputPath, suffix = '' }) {
  const originalBuffer = await readFile(inputPath);
  const beforeSize = originalBuffer.length;
  const sourceMeta = await sharp(originalBuffer).metadata();
  const format = sourceMeta.format ?? 'jpeg';
  const ext = extForFormat(format);

  const webpBuffer = await sharp(originalBuffer).webp({ lossless: true }).toBuffer();
  const webpMeta = await sharp(webpBuffer).metadata();

  const webpOutputs = [
    path.join(ROOT, 'marketing', `readme-banner${suffix}.webp`),
    path.join(ROOT, 'web', 'public', 'landing', `hero-showcase${suffix}.webp`),
  ];
  const nativeOutput = path.join(ROOT, 'web', 'public', 'landing', `hero-showcase${suffix}${ext}`);

  console.log(`Source ${labelFor(inputPath)}`.padEnd(44), formatBytes(beforeSize).padStart(8));
  console.log(`WebP (lossless) ${suffix || '1x'}`.padEnd(44), formatBytes(webpBuffer.length).padStart(8));
  console.log(`Dimensions: ${webpMeta.width}×${webpMeta.height}`);

  for (const outputPath of webpOutputs) {
    await mkdir(path.dirname(outputPath), { recursive: true });
    await writeFile(outputPath, webpBuffer);
    console.log(`  → ${labelFor(outputPath)}`);
  }

  await mkdir(path.dirname(nativeOutput), { recursive: true });
  await copyFile(inputPath, nativeOutput);
  console.log(`  → ${labelFor(nativeOutput)} (verbatim copy, no re-encode)`);

  if ((webpMeta.width ?? 0) < 1920 && !suffix) {
    console.warn(
      '\n⚠ Source is below 1920px wide — hero will look soft on Retina displays.',
      'Add marketing/banner-source@2x.png (≥2048px wide) for sharp 2x rendering.\n',
    );
  }

  return {
    width: webpMeta.width ?? 0,
    height: webpMeta.height ?? 0,
    has2x: suffix === '@2x',
  };
}

async function writeLandingAssets({ width, height, has2x }) {
  const content = `/** Marketing showcase — lossless WebP + verbatim native copy (no resize, no lossy re-encode). */
export const LANDING_HERO_SHOWCASE_SRC = '/landing/hero-showcase.webp';
export const LANDING_HERO_SHOWCASE_SRC_2X = '/landing/hero-showcase@2x.webp';
export const LANDING_HERO_SHOWCASE_HAS_2X = ${has2x};

export const LANDING_HERO_SHOWCASE_WIDTH = ${width};
export const LANDING_HERO_SHOWCASE_HEIGHT = ${height};
`;
  await writeFile(LANDING_ASSETS, content);
  console.log(`  → ${labelFor(LANDING_ASSETS)}`);
}

async function main() {
  console.log('Converting marketing banner to lossless WebP (no resize)...\n');

  const primary = await convertBanner({ inputPath: BANNER_SOURCE });
  let has2x = false;

  if (await fileExists(BANNER_SOURCE_2X)) {
    console.log('');
    await convertBanner({ inputPath: BANNER_SOURCE_2X, suffix: '@2x' });
    has2x = true;
  }

  console.log('');
  await writeLandingAssets({ width: primary.width, height: primary.height, has2x });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
