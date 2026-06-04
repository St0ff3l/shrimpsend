'use client';

import { Check, Copy } from 'lucide-react';
import type { ComponentPropsWithoutRef, ReactNode } from 'react';
import { useCallback, useState } from 'react';
import { useI18n } from '@/contexts/I18nContext';
import { cn } from '@/lib/utils';

function extractCodeText(node: ReactNode): string {
  if (typeof node === 'string') return node;
  if (typeof node === 'number') return String(node);
  if (Array.isArray(node)) return node.map(extractCodeText).join('');
  if (node && typeof node === 'object' && 'props' in node) {
    return extractCodeText((node as { props?: { children?: ReactNode } }).props?.children);
  }
  return '';
}

export function DocsCodeBlock({
  children,
  className,
  ...props
}: ComponentPropsWithoutRef<'pre'>) {
  const { t } = useI18n();
  const [copied, setCopied] = useState(false);
  const text = extractCodeText(children).replace(/\n$/, '');

  const copy = useCallback(async () => {
    if (!text) return;
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard may be unavailable outside secure context.
    }
  }, [text]);

  return (
    <div className="group relative mb-4">
      <button
        type="button"
        onClick={() => void copy()}
        disabled={!text}
        className={cn(
          'absolute right-2 top-2 z-10 flex size-8 items-center justify-center rounded-lg border border-white/10 bg-black/50 text-muted-foreground shadow-sm backdrop-blur-sm transition-colors hover:bg-black/70 hover:text-foreground focus-visible:opacity-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40 disabled:pointer-events-none disabled:opacity-40',
          copied ? 'border-primary/30 text-primary' : 'opacity-80 group-hover:opacity-100',
        )}
        aria-label={copied ? t('docs.code.copied') : t('docs.code.copy')}
        title={copied ? t('docs.code.copied') : t('docs.code.copy')}
      >
        {copied ? <Check className="size-4" aria-hidden /> : <Copy className="size-4" aria-hidden />}
      </button>
      <pre
        className={cn(
          'overflow-x-auto rounded-2xl border border-white/10 bg-black/20 p-4 pr-12 text-xs leading-relaxed',
          className,
        )}
        {...props}
      >
        {children}
      </pre>
    </div>
  );
}
