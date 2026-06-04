'use client';

import Link from 'next/link';
import { Package } from 'lucide-react';
import { buttonVariants } from '@/components/ui/button';
import { cn } from '@/lib/utils';

export default function AdminDashboardPage() {
  return (
    <div className="mx-auto max-w-3xl space-y-8 px-4 py-10">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-xl font-semibold tracking-tight">后台管理</h1>
          <p className="mt-1 text-sm text-muted-foreground">管理员控制台，请选择下方模块。</p>
        </div>
        <Link href="/chat" className={cn(buttonVariants({ variant: 'outline' }))}>
          返回会话
        </Link>
      </div>

      <div className="grid gap-4">
        <Link
          href="/admin/versions"
          className={cn(
            'group flex gap-4 rounded-2xl border border-border/60 bg-card p-5 shadow-sm ring-1 ring-foreground/5 transition-colors',
            'hover:bg-muted/40 hover:border-border',
          )}
        >
          <span className="flex size-12 shrink-0 items-center justify-center rounded-xl bg-primary/12 text-primary">
            <Package className="size-6" aria-hidden />
          </span>
          <div className="min-w-0 flex-1 text-left">
            <h2 className="text-base font-medium transition-colors group-hover:text-primary">版本管理</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              上传各端安装包至对象存储，维护发布版本信息。
            </p>
          </div>
        </Link>
      </div>
    </div>
  );
}
