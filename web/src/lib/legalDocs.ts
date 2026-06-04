import fs from 'fs';
import path from 'path';

/**
 * Resolve `docs/legal/...` from repo root. Supports `cwd` = `web/` (typical) or monorepo root.
 */
function resolveLegalFile(segments: string[]): string {
  const rel = path.join(...segments);
  const candidates = [
    path.join(process.cwd(), '..', 'docs', 'legal', rel),
    path.join(process.cwd(), 'docs', 'legal', rel),
  ];
  for (const full of candidates) {
    if (fs.existsSync(full)) return full;
  }
  throw new Error(`Legal document not found: docs/legal/${rel}`);
}

export function readLegalMarkdown(...segments: string[]): string {
  const file = resolveLegalFile(segments);
  return fs.readFileSync(file, 'utf8');
}
