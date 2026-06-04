#!/usr/bin/env node
/** Optimize documentation images: resize, recompress PNG, generate WebP, write manifest. */

import { createRequire } from 'node:module';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT, 'web', 'public');
const DOCS_DIR = path.join(PUBLIC_DIR, 'docs');
const MANIFEST_PUBLIC = path.join(DOCS_DIR, 'image-manifest.json');
const MANIFEST_SRC = path.join(ROOT, 'web', 'src', 'lib', 'docsImageManifest.json');

const MAX_WIDTH = 1344;
const WEBP_QUALITY = 85;
const WEBP_EFFORT = 6;

const require = createRequire(path.join(ROOT, 'web', 'package.json'));
const sharp = require('sharp');

async function collectImages(dir) {
  const images = [];

  async function walk(current) {
    const entries = await readdir(current, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        await walk(full);
      } else if (/\.(png|jpe?g)$/i.test(entry.name)) {
        images.push(full);
      }
    }
  }

  await walk(dir);
  return images.sort();
}

function toPublicPath(filePath) {
  const relative = path.relative(PUBLIC_DIR, filePath);
  return `/${relative.split(path.sep).join('/')}`;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  return `${(bytes / 1024).toFixed(1)} KB`;
}

async function optimizeImage(filePath) {
  const originalBuffer = await readFile(filePath);
  const beforeSize = originalBuffer.length;
  const metadata = await sharp(originalBuffer).metadata();
  const needsResize = (metadata.width ?? 0) > MAX_WIDTH;

  let pipeline = sharp(originalBuffer);
  if (needsResize) {
    pipeline = pipeline.resize(MAX_WIDTH, null, { withoutEnlargement: true });
  }

  const { data: pngData, info } = await pipeline
    .png({ compressionLevel: 9, adaptiveFiltering: true })
    .toBuffer({ resolveWithObject: true });

  const savedPng =
    needsResize || pngData.length < beforeSize ? pngData : originalBuffer;

  const webpBuffer = await sharp(savedPng)
    .webp({ quality: WEBP_QUALITY, effort: WEBP_EFFORT })
    .toBuffer();

  await writeFile(filePath, savedPng);

  const webpPath = filePath.replace(/\.(png|jpe?g)$/i, '.webp');
  await writeFile(webpPath, webpBuffer);

  const finalMeta = await sharp(savedPng).metadata();
  const publicPath = toPublicPath(filePath);

  return {
    path: publicPath,
    width: finalMeta.width ?? info.width,
    height: finalMeta.height ?? info.height,
    beforeSize,
    afterPngSize: savedPng.length,
    webpSize: webpBuffer.length,
  };
}

async function main() {
  const images = await collectImages(DOCS_DIR);
  if (images.length === 0) {
    console.log('No images found under web/public/docs/');
    return;
  }

  const manifest = {};
  let totalBefore = 0;
  let totalPngAfter = 0;
  let totalWebp = 0;

  console.log(`Optimizing ${images.length} documentation images...\n`);
  console.log('File'.padEnd(52), 'Before', 'PNG', 'WebP', 'Saved');
  console.log('-'.repeat(90));

  for (const filePath of images) {
    const result = await optimizeImage(filePath);
    manifest[result.path] = { width: result.width, height: result.height };

    totalBefore += result.beforeSize;
    totalPngAfter += result.afterPngSize;
    totalWebp += result.webpSize;

    const saved = result.beforeSize - result.webpSize;
    const label = result.path.replace('/docs/', '');
    console.log(
      label.padEnd(52),
      formatBytes(result.beforeSize).padStart(8),
      formatBytes(result.afterPngSize).padStart(8),
      formatBytes(result.webpSize).padStart(8),
      `${saved >= 0 ? '-' : '+'}${formatBytes(Math.abs(saved)).padStart(8)}`,
    );
  }

  const manifestJson = `${JSON.stringify(manifest, null, 2)}\n`;
  await writeFile(MANIFEST_PUBLIC, manifestJson);
  await writeFile(MANIFEST_SRC, manifestJson);

  const pngSaved = totalBefore - totalPngAfter;
  const webpSaved = totalBefore - totalWebp;

  console.log('-'.repeat(90));
  console.log(
    'TOTAL'.padEnd(52),
    formatBytes(totalBefore).padStart(8),
    formatBytes(totalPngAfter).padStart(8),
    formatBytes(totalWebp).padStart(8),
    `-${formatBytes(webpSaved)}`,
  );
  console.log(
    `\nPNG reduction: ${formatBytes(pngSaved)} (${((pngSaved / totalBefore) * 100).toFixed(1)}%)`,
  );
  console.log(
    `WebP vs original: ${formatBytes(webpSaved)} (${((webpSaved / totalBefore) * 100).toFixed(1)}%)`,
  );
  console.log(`\nWrote ${MANIFEST_PUBLIC}`);
  console.log(`Wrote ${MANIFEST_SRC}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
