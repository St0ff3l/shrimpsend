'use client';

const BADGE: Record<string, { label: string; bg: string; fg: string }> = {
  lan: { label: 'HTTP', bg: 'rgba(61, 155, 126, 0.14)', fg: '#3D9B7E' },
  webrtc: { label: 'WebRTC', bg: 'rgba(123, 101, 176, 0.14)', fg: '#7B65B0' },
  s3: { label: 'S3', bg: 'rgba(74, 114, 196, 0.14)', fg: '#4A72C4' },
};

export function TransferChannelBadge({ transferType }: { transferType?: string | null }) {
  if (!transferType) return null;
  const spec = BADGE[transferType];
  if (!spec) return null;
  return (
    <span
      className="shrink-0 rounded-full px-2 py-0.5 text-[10px] font-semibold leading-tight"
      style={{ backgroundColor: spec.bg, color: spec.fg }}
    >
      {spec.label}
    </span>
  );
}
