export type FileCategory = 'image' | 'video' | 'audio' | 'pdf' | 'archive' | 'document' | 'code' | 'other';

const EXT_MAP: Record<string, FileCategory> = {};

const IMAGE_EXTS = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'heic', 'ico', 'tiff'];
const VIDEO_EXTS = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv'];
const AUDIO_EXTS = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a', 'wma'];
const PDF_EXTS = ['pdf'];
const ARCHIVE_EXTS = ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'];
const DOCUMENT_EXTS = ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'md', 'rtf'];
const CODE_EXTS = ['js', 'ts', 'jsx', 'tsx', 'py', 'java', 'go', 'rs', 'c', 'cpp', 'h', 'html', 'css', 'json', 'xml', 'yaml', 'yml', 'sh'];

for (const ext of IMAGE_EXTS) EXT_MAP[ext] = 'image';
for (const ext of VIDEO_EXTS) EXT_MAP[ext] = 'video';
for (const ext of AUDIO_EXTS) EXT_MAP[ext] = 'audio';
for (const ext of PDF_EXTS) EXT_MAP[ext] = 'pdf';
for (const ext of ARCHIVE_EXTS) EXT_MAP[ext] = 'archive';
for (const ext of DOCUMENT_EXTS) EXT_MAP[ext] = 'document';
for (const ext of CODE_EXTS) EXT_MAP[ext] = 'code';

export function getFileCategory(fileName: string | undefined): FileCategory {
  if (!fileName) return 'other';
  const dot = fileName.lastIndexOf('.');
  if (dot < 0) return 'other';
  const ext = fileName.slice(dot + 1).toLowerCase();
  return EXT_MAP[ext] ?? 'other';
}

export function formatFileSize(bytes: number | undefined | null): string {
  if (bytes == null || bytes < 0) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}
