import { Image, Video, Music, FileText, FileArchive, Code, File } from 'lucide-react';
import type { FileCategory } from '@/lib/fileUtils';
import type { LucideIcon } from 'lucide-react';

type Props = { category: FileCategory; size?: number; className?: string };

const categoryConfig: Record<FileCategory, { icon: LucideIcon; color: string }> = {
  image:    { icon: Image,       color: '#6FBBE8' },
  video:    { icon: Video,       color: '#E88B5A' },
  audio:    { icon: Music,       color: '#EABD3B' },
  pdf:      { icon: FileText,    color: '#E05252' },
  archive:  { icon: FileArchive, color: '#A77BCA' },
  document: { icon: FileText,    color: '#45B7AA' },
  code:     { icon: Code,        color: '#66C088' },
  other:    { icon: File,        color: '#8B95A5' },
};

export function FileIcon({ category, size = 40, className }: Props) {
  const { icon: Icon, color } = categoryConfig[category] ?? categoryConfig.other;
  const iconSize = Math.round(size * 0.5);
  const radius = size < 36 ? 8 : 10;

  return (
    <div
      className={className}
      style={{
        width: size,
        height: size,
        borderRadius: radius,
        backgroundColor: `${color}24`,
        border: `1px solid ${color}38`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Icon size={iconSize} color={color} strokeWidth={1.5} />
    </div>
  );
}
