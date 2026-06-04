'use client';

import Link from 'next/link';
import { useAuth } from '@/contexts/AuthContext';
import { useCallback, useEffect, useState } from 'react';
import {
  PublicDownloadFields,
  emptyPublicDownloadForm,
  publicDownloadFormFromRow,
  publicDownloadToApiBody,
  publicDownloadToCreateApiBody,
} from '@/components/admin/PublicDownloadFields';
import {
  createAdminAppVersion,
  deleteAdminAppVersion,
  listAdminAppVersions,
  publishWebAdminAppVersion,
  updateAdminAppVersion,
  uploadReleaseDirect,
  type AdminAppVersionRow,
  type ReleaseUploadProgress,
} from '@/lib/api/adminAppVersion';
import { formatFileSize } from '@/lib/fileUtils';
import { logger } from '@/lib/logger';
import { toast } from 'sonner';
import { Button, buttonVariants } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { Progress } from '@/components/ui/progress';
import { Badge } from '@/components/ui/badge';

const TAG = 'adminVersions';

type PackageSlot = 'android' | 'ios' | 'windows' | 'macos' | 'linux';

const PACKAGE_SLOTS: { key: PackageSlot; label: string }[] = [
  { key: 'android', label: 'Android' },
  { key: 'ios', label: 'iOS' },
  { key: 'windows', label: 'Windows' },
  { key: 'macos', label: 'macOS' },
  { key: 'linux', label: 'Linux' },
];

function hasPackage(row: AdminAppVersionRow, slot: PackageSlot): boolean {
  switch (slot) {
    case 'android':
      return Boolean(row.downloadUrl?.trim());
    case 'ios':
      return Boolean(row.iosStoreUrl?.trim());
    case 'windows':
      return Boolean(row.desktopWindowsZipUrl?.trim());
    case 'macos':
      return Boolean(row.desktopMacosZipUrl?.trim());
    case 'linux':
      return Boolean(row.desktopLinuxZipUrl?.trim());
  }
}

function packageSize(row: AdminAppVersionRow, slot: PackageSlot): number | null {
  switch (slot) {
    case 'windows':
      return row.desktopWindowsZipBytes;
    case 'macos':
      return row.desktopMacosZipBytes;
    case 'linux':
      return row.desktopLinuxZipBytes;
    default:
      return null;
  }
}

function PublicWebBadges({ row }: { row: AdminAppVersionRow }) {
  return (
    <div className="flex flex-wrap gap-1 mt-1">
      {row.webPublished ? (
        <Badge className="font-normal bg-primary/15 text-primary border-primary/30">官网发布中</Badge>
      ) : null}
      {row.mainlandPublicConfigured ? (
        <Badge variant="outline" className="font-normal">
          大陆公开
        </Badge>
      ) : null}
      {row.overseasPublicConfigured ? (
        <Badge variant="outline" className="font-normal">
          海外公开
        </Badge>
      ) : null}
      {row.overseasPlayConfigured ? (
        <Badge variant="secondary" className="font-normal">
          Play
        </Badge>
      ) : null}
      {row.overseasAppStoreConfigured ? (
        <Badge variant="secondary" className="font-normal">
          App Store
        </Badge>
      ) : null}
    </div>
  );
}

function VersionPackagesBadges({ row }: { row: AdminAppVersionRow }) {
  return (
    <div className="flex flex-wrap gap-1 max-w-md">
      {PACKAGE_SLOTS.map((slot) => {
        const present = hasPackage(row, slot.key);
        const size = packageSize(row, slot.key);
        const sizeLabel = present && size != null && size > 0 ? formatFileSize(size) : '';
        const title = present
          ? `${slot.label}${sizeLabel ? ` · ${sizeLabel}` : ''}`
          : `未配置 ${slot.label}`;

        return (
          <Badge
            key={slot.key}
            variant={present ? 'secondary' : 'outline'}
            className={cn(
              'font-normal',
              !present && 'border-dashed text-muted-foreground opacity-70',
            )}
            title={title}
          >
            {slot.label}
            {present && sizeLabel ? ` · ${sizeLabel}` : null}
          </Badge>
        );
      })}
    </div>
  );
}

type PlatformKey = 'apk' | 'windows' | 'macos' | 'linux';

const PLATFORM_LABEL: Record<PlatformKey, string> = {
  apk: 'Android APK',
  windows: 'Windows',
  macos: 'macOS',
  linux: 'Linux',
};

type TransferOverlayState = {
  title: string;
  percent: number;
  detail?: string;
};

function safePresignName(platform: string, buildNumber: number, original: string): string {
  const i = original.lastIndexOf('.');
  const ext = i >= 0 ? original.slice(i) : '';
  return `${platform}-${buildNumber}${ext}`;
}

async function uploadPlatformFile(
  platform: PlatformKey,
  buildNumber: number,
  file: File,
  onProgress?: (p: ReleaseUploadProgress) => void,
): Promise<{ url: string; size: number }> {
  const fileName = safePresignName(platform, buildNumber, file.name);
  const res = await uploadReleaseDirect(
    {
      platform,
      buildNumber,
      file,
      fileName,
    },
    onProgress,
  );
  return { url: res.publicUrl, size: res.sizeBytes };
}

export default function AdminVersionsPage() {
  const { accessToken, isReady } = useAuth();

  const [versions, setVersions] = useState<AdminAppVersionRow[]>([]);
  const [listLoading, setListLoading] = useState(false);

  const [createVersion, setCreateVersion] = useState('');
  const [createBuild, setCreateBuild] = useState('');
  const [createNotes, setCreateNotes] = useState('');
  const [createIosStore, setCreateIosStore] = useState('');
  const [createEnabled, setCreateEnabled] = useState(true);
  const [apkFile, setApkFile] = useState<File | null>(null);
  const [winFile, setWinFile] = useState<File | null>(null);
  const [macFile, setMacFile] = useState<File | null>(null);
  const [linuxFile, setLinuxFile] = useState<File | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [transferOverlay, setTransferOverlay] = useState<TransferOverlayState | null>(null);

  const [editing, setEditing] = useState<AdminAppVersionRow | null>(null);
  const [editNotes, setEditNotes] = useState('');
  const [editIos, setEditIos] = useState('');
  const [editEnabled, setEditEnabled] = useState(true);
  const [editApk, setEditApk] = useState<File | null>(null);
  const [editWin, setEditWin] = useState<File | null>(null);
  const [editMac, setEditMac] = useState<File | null>(null);
  const [editLinux, setEditLinux] = useState<File | null>(null);
  const [editSaving, setEditSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [publishingWebId, setPublishingWebId] = useState<number | null>(null);
  const [createPublic, setCreatePublic] = useState(emptyPublicDownloadForm);
  const [editPublic, setEditPublic] = useState(emptyPublicDownloadForm);

  const refreshList = useCallback(async () => {
    setListLoading(true);
    try {
      const list = await listAdminAppVersions();
      setVersions(list);
    } catch (e) {
      logger.warn(TAG, 'list failed', e);
      toast.error(e instanceof Error ? e.message : '加载版本列表失败');
    } finally {
      setListLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!isReady || !accessToken) return;
    void refreshList();
  }, [isReady, accessToken, refreshList]);

  const submitCreate = async () => {
    const bn = parseInt(createBuild, 10);
    if (!createVersion.trim() || Number.isNaN(bn) || bn <= 0) {
      toast.error('请填写有效的版本号与 buildNumber');
      return;
    }
    setSubmitting(true);
    setTransferOverlay(null);
    try {
      let downloadUrl: string | undefined;
      let desktopWindowsZipUrl: string | undefined;
      let desktopMacosZipUrl: string | undefined;
      let desktopLinuxZipUrl: string | undefined;
      let desktopWindowsZipBytes: number | null | undefined;
      let desktopMacosZipBytes: number | null | undefined;
      let desktopLinuxZipBytes: number | null | undefined;

      const uploadJobs: { platform: PlatformKey; file: File }[] = [];
      if (apkFile) uploadJobs.push({ platform: 'apk', file: apkFile });
      if (winFile) uploadJobs.push({ platform: 'windows', file: winFile });
      if (macFile) uploadJobs.push({ platform: 'macos', file: macFile });
      if (linuxFile) uploadJobs.push({ platform: 'linux', file: linuxFile });

      for (let i = 0; i < uploadJobs.length; i++) {
        const { platform, file } = uploadJobs[i];
        const label = PLATFORM_LABEL[platform];
        setTransferOverlay({
          title: `正在上传 ${label}`,
          detail: `第 ${i + 1} / ${uploadJobs.length} 个文件`,
          percent: 0,
        });
        const r = await uploadPlatformFile(platform, bn, file, (p: ReleaseUploadProgress) => {
          setTransferOverlay({
            title: `正在上传 ${label}`,
            detail: `${formatFileSize(p.loaded)} / ${formatFileSize(p.total)} · 第 ${i + 1} / ${uploadJobs.length} 个文件`,
            percent: p.percent,
          });
        });
        switch (platform) {
          case 'apk':
            downloadUrl = r.url;
            break;
          case 'windows':
            desktopWindowsZipUrl = r.url;
            desktopWindowsZipBytes = r.size;
            break;
          case 'macos':
            desktopMacosZipUrl = r.url;
            desktopMacosZipBytes = r.size;
            break;
          case 'linux':
            desktopLinuxZipUrl = r.url;
            desktopLinuxZipBytes = r.size;
            break;
          default:
            break;
        }
      }

      setTransferOverlay({ title: '正在保存版本信息…', percent: 100, detail: undefined });
      await createAdminAppVersion({
        version: createVersion.trim(),
        buildNumber: bn,
        releaseNotes: createNotes.trim() || undefined,
        iosStoreUrl: createIosStore.trim() || undefined,
        downloadUrl,
        desktopWindowsZipUrl,
        desktopMacosZipUrl,
        desktopLinuxZipUrl,
        desktopWindowsZipBytes,
        desktopMacosZipBytes,
        desktopLinuxZipBytes,
        enabled: createEnabled,
        ...publicDownloadToCreateApiBody(createPublic),
      });
      toast.success('已创建版本');
      setCreateVersion('');
      setCreateBuild('');
      setCreateNotes('');
      setCreateIosStore('');
      setCreateEnabled(true);
      setCreatePublic(emptyPublicDownloadForm());
      setApkFile(null);
      setWinFile(null);
      setMacFile(null);
      setLinuxFile(null);
      await refreshList();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : '创建失败');
    } finally {
      setTransferOverlay(null);
      setSubmitting(false);
    }
  };

  const openEdit = (row: AdminAppVersionRow) => {
    setEditing(row);
    setEditNotes(row.releaseNotes ?? '');
    setEditIos(row.iosStoreUrl ?? '');
    setEditEnabled(row.enabled);
    setEditPublic(publicDownloadFormFromRow(row));
    setEditApk(null);
    setEditWin(null);
    setEditMac(null);
    setEditLinux(null);
  };

  const deleteVersion = async (row: AdminAppVersionRow) => {
    const label = `${row.version} (build ${row.buildNumber})`;
    if (
      !window.confirm(
        `确定删除版本 ${label}？\n\n此操作不可恢复，已上传的安装包文件不会从对象存储中自动删除。`,
      )
    ) {
      return;
    }
    setDeletingId(row.id);
    try {
      await deleteAdminAppVersion(row.id);
      toast.success('已删除版本');
      if (editing?.id === row.id) {
        setEditing(null);
      }
      await refreshList();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : '删除失败');
    } finally {
      setDeletingId(null);
    }
  };

  const saveEdit = async () => {
    if (!editing) return;
    setEditSaving(true);
    setTransferOverlay(null);
    try {
      const bn = editing.buildNumber;
      const body: Parameters<typeof updateAdminAppVersion>[1] = {
        releaseNotes: editNotes.trim() || null,
        iosStoreUrl: editIos.trim() || null,
        enabled: editEnabled,
        ...publicDownloadToApiBody(editPublic),
      };

      const editJobs: { platform: PlatformKey; file: File }[] = [];
      if (editApk) editJobs.push({ platform: 'apk', file: editApk });
      if (editWin) editJobs.push({ platform: 'windows', file: editWin });
      if (editMac) editJobs.push({ platform: 'macos', file: editMac });
      if (editLinux) editJobs.push({ platform: 'linux', file: editLinux });

      for (let i = 0; i < editJobs.length; i++) {
        const { platform, file } = editJobs[i];
        const label = PLATFORM_LABEL[platform];
        setTransferOverlay({
          title: `正在上传 ${label}`,
          detail: `第 ${i + 1} / ${editJobs.length} 个文件`,
          percent: 0,
        });
        const r = await uploadPlatformFile(platform, bn, file, (p: ReleaseUploadProgress) => {
          setTransferOverlay({
            title: `正在上传 ${label}`,
            detail: `${formatFileSize(p.loaded)} / ${formatFileSize(p.total)} · 第 ${i + 1} / ${editJobs.length} 个文件`,
            percent: p.percent,
          });
        });
        switch (platform) {
          case 'apk':
            body.downloadUrl = r.url;
            break;
          case 'windows':
            body.desktopWindowsZipUrl = r.url;
            body.desktopWindowsZipBytes = r.size;
            break;
          case 'macos':
            body.desktopMacosZipUrl = r.url;
            body.desktopMacosZipBytes = r.size;
            break;
          case 'linux':
            body.desktopLinuxZipUrl = r.url;
            body.desktopLinuxZipBytes = r.size;
            break;
          default:
            break;
        }
      }

      setTransferOverlay({ title: '正在保存修改…', percent: 100, detail: undefined });
      await updateAdminAppVersion(editing.id, body);
      toast.success('已保存');
      setEditing(null);
      await refreshList();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : '保存失败');
    } finally {
      setTransferOverlay(null);
      setEditSaving(false);
    }
  };

  const publishWeb = async (row: AdminAppVersionRow) => {
    setPublishingWebId(row.id);
    try {
      await publishWebAdminAppVersion(row.id);
      toast.success(`已将 build ${row.buildNumber} 设为官网展示版本`);
      await refreshList();
      if (editing?.id === row.id) {
        const updated = (await listAdminAppVersions()).find((x) => x.id === row.id);
        if (updated) {
          setEditing(updated);
          setEditPublic(publicDownloadFormFromRow(updated));
        }
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : '设置失败');
    } finally {
      setPublishingWebId(null);
    }
  };

  if (!isReady || !accessToken) {
    return (
      <div className="flex min-h-dvh items-center justify-center text-muted-foreground text-sm">加载中…</div>
    );
  }

  return (
    <>
      {transferOverlay && (
        <div
          className="fixed inset-0 z-[100] flex items-center justify-center bg-background/75 px-4 py-8 backdrop-blur-[2px]"
          role="dialog"
          aria-modal="true"
          aria-labelledby="admin-upload-progress-title"
        >
          <Card className="w-full max-w-md shadow-lg">
            <CardContent className="space-y-3 pt-6">
              <p id="admin-upload-progress-title" className="text-sm font-medium">
                {transferOverlay.title}
              </p>
              {transferOverlay.detail ? (
                <p className="text-xs text-muted-foreground">{transferOverlay.detail}</p>
              ) : null}
              <Progress value={transferOverlay.percent} className="h-2" />
              <p className="text-right text-xs tabular-nums text-muted-foreground">{transferOverlay.percent}%</p>
            </CardContent>
          </Card>
        </div>
      )}

    <div className="mx-auto max-w-4xl space-y-8 px-4 py-10">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-xl font-semibold tracking-tight">版本管理</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            上传安装包至对象存储（浏览器直传）并写入发布版本（权限以后端校验为准）。
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link href="/admin" className={cn(buttonVariants({ variant: 'outline' }))}>
            返回后台
          </Link>
          <Link href="/chat" className={cn(buttonVariants({ variant: 'outline' }))}>
            返回会话
          </Link>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>新建版本</CardTitle>
          <CardDescription>
            填写版本信息与 build；可选上传各端文件。文件名将规范为{' '}
            <code className="rounded bg-muted px-1 py-0.5 text-xs">platform-build.ext</code>{' '}
            以满足存储命名规则。
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-2">
              <Label htmlFor="cv">版本号 version</Label>
              <Input
                id="cv"
                value={createVersion}
                onChange={(e) => setCreateVersion(e.target.value)}
                placeholder="例如 1.2.3"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="cb">buildNumber</Label>
              <Input
                id="cb"
                type="number"
                min={1}
                value={createBuild}
                onChange={(e) => setCreateBuild(e.target.value)}
                placeholder="整数，全局唯一"
              />
            </div>
          </div>
          <div className="space-y-2">
            <Label htmlFor="cn">更新说明</Label>
            <Textarea
              id="cn"
              value={createNotes}
              onChange={(e) => setCreateNotes(e.target.value)}
              placeholder="可选，支持多行"
              rows={4}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="ci">iOS App Store 链接</Label>
            <Input
              id="ci"
              value={createIosStore}
              onChange={(e) => setCreateIosStore(e.target.value)}
              placeholder="可选，一般为商店 URL"
            />
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id="ce"
              checked={createEnabled}
              onCheckedChange={(v) => setCreateEnabled(v === true)}
            />
            <Label htmlFor="ce" className="font-normal">
              启用（对外展示）
            </Label>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <FilePick label="Android APK" file={apkFile} onFile={setApkFile} />
            <FilePick label="Windows ZIP" file={winFile} onFile={setWinFile} />
            <FilePick label="macOS ZIP" file={macFile} onFile={setMacFile} />
            <FilePick label="Linux ZIP" file={linuxFile} onFile={setLinuxFile} />
          </div>

          <div className="rounded-xl border border-dashed border-border/80 bg-muted/15 p-4 space-y-3">
            <p className="text-sm font-medium">官网公开发布（外链）</p>
            <PublicDownloadFields idPrefix="create" value={createPublic} onChange={setCreatePublic} />
          </div>

          <Button type="button" disabled={submitting} onClick={() => void submitCreate()}>
            {submitting ? '提交中…' : '上传并创建'}
          </Button>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>已有版本</CardTitle>
          <CardDescription>
            {listLoading
              ? '加载中…'
              : `共 ${versions.length} 条 · 实心标签表示已配置，虚线边框表示该平台尚未上传`}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="overflow-x-auto rounded-xl border">
            <table className="w-full min-w-[880px] text-left text-sm">
              <thead className="border-b bg-muted/40">
                <tr>
                  <th className="px-3 py-2 font-medium">build</th>
                  <th className="px-3 py-2 font-medium">version</th>
                  <th className="px-3 py-2 font-medium">OTA 包</th>
                  <th className="px-3 py-2 font-medium">官网外链</th>
                  <th className="px-3 py-2 font-medium">启用</th>
                  <th className="px-3 py-2 font-medium">创建时间</th>
                  <th className="px-3 py-2 font-medium w-36">操作</th>
                </tr>
              </thead>
              <tbody>
                {versions.map((v) => (
                  <tr key={v.id} className="border-b border-border/60 last:border-0">
                    <td className="px-3 py-2 tabular-nums">{v.buildNumber}</td>
                    <td className="px-3 py-2">{v.version}</td>
                    <td className="px-3 py-2 align-top">
                      <VersionPackagesBadges row={v} />
                    </td>
                    <td className="px-3 py-2 align-top">
                      <PublicWebBadges row={v} />
                    </td>
                    <td className="px-3 py-2">{v.enabled ? '是' : '否'}</td>
                    <td className="px-3 py-2 text-muted-foreground">{v.releasedAt ?? '—'}</td>
                    <td className="px-3 py-2">
                      <div className="flex flex-wrap gap-1">
                        <Button type="button" variant="ghost" size="sm" onClick={() => openEdit(v)}>
                          编辑
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          disabled={publishingWebId === v.id || v.webPublished}
                          onClick={() => void publishWeb(v)}
                        >
                          {publishingWebId === v.id ? '设置中…' : v.webPublished ? '官网中' : '设为官网'}
                        </Button>
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          className="text-destructive hover:text-destructive"
                          disabled={deletingId === v.id}
                          onClick={() => void deleteVersion(v)}
                        >
                          {deletingId === v.id ? '删除中…' : '删除'}
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {editing && (
            <div className="rounded-xl border bg-muted/20 p-4 space-y-4">
              <div className="space-y-2">
                <div className="font-medium">
                  编辑 build {editing.buildNumber}（{editing.version}）
                </div>
                <VersionPackagesBadges row={editing} />
                <PublicWebBadges row={editing} />
              </div>
              <div className="rounded-xl border border-dashed border-border/80 bg-background/60 p-4 space-y-3">
                <p className="text-sm font-medium">官网公开发布（外链）</p>
                <PublicDownloadFields idPrefix="edit" value={editPublic} onChange={setEditPublic} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="en">更新说明</Label>
                <Textarea
                  id="en"
                  value={editNotes}
                  onChange={(e) => setEditNotes(e.target.value)}
                  placeholder="支持多行"
                  rows={5}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="ei">iOS App Store 链接</Label>
                <Input id="ei" value={editIos} onChange={(e) => setEditIos(e.target.value)} />
              </div>
              <div className="flex items-center gap-2">
                <Checkbox
                  id="ee"
                  checked={editEnabled}
                  onCheckedChange={(v) => setEditEnabled(v === true)}
                />
                <Label htmlFor="ee" className="font-normal">
                  启用
                </Label>
              </div>
              <p className="text-xs text-muted-foreground">选择文件则上传并替换对应下载地址。</p>
              <div className="grid gap-4 sm:grid-cols-2">
                <FilePick label="替换 APK" file={editApk} onFile={setEditApk} />
                <FilePick label="替换 Windows ZIP" file={editWin} onFile={setEditWin} />
                <FilePick label="替换 macOS ZIP" file={editMac} onFile={setEditMac} />
                <FilePick label="替换 Linux ZIP" file={editLinux} onFile={setEditLinux} />
              </div>
              <div className="flex flex-wrap gap-2">
                <Button type="button" disabled={editSaving} onClick={() => void saveEdit()}>
                  {editSaving ? '保存中…' : '保存'}
                </Button>
                <Button type="button" variant="outline" onClick={() => setEditing(null)}>
                  取消
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
    </>
  );
}

function FilePick({
  label,
  file,
  onFile,
}: {
  label: string;
  file: File | null;
  onFile: (f: File | null) => void;
}) {
  return (
    <div className="space-y-2">
      <Label className="block">{label}</Label>
      <Input
        type="file"
        onChange={(e) => {
          const f = e.target.files?.[0];
          onFile(f ?? null);
        }}
      />
      {file && <p className="text-xs text-muted-foreground truncate">{file.name}</p>}
    </div>
  );
}
