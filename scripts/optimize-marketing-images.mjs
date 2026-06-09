#!/usr/bin/env node
/** Convert README marketing banner to lossless WebP (no resize). */

import { createRequire } from 'node:module';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const BANNER_SOURCE = path.join(ROOT, 'marketing', 'banner-source.png');
const README_WEBP = path.join(ROOT, 'marketing', 'readme-banner.webp');

const require = createRequire(path.join(ROOT, 'web', 'package.json'));
const sharp = require('sharp');

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  return `${(bytes / 1024).toFixed(1)} KB`;
}

async function main() {
  const originalBuffer = await readFile(BANNER_SOURCE);
  const webpBuffer = await sharp(originalBuffer)
    .webp({ lossless: true })
    .toBuffer();
  const metadata = await sharp(webpBuffer).metadata();

  console.log('Converting README banner to lossless WebP (no resize)...\n');
  console.log('Source'.padEnd(44), formatBytes(originalBuffer.length).padStart(8));
  console.log('WebP'.padEnd(44), formatBytes(webpBuffer.length).padStart(8));
  console.log(`Dimensions: ${metadata.width}×${metadata.height}\n`);

  await mkdir(path.dirname(README_WEBP), { recursive: true });
  await writeFile(README_WEBP, webpBuffer);
  console.log(`  → ${path.relative(ROOT, README_WEBP)}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
