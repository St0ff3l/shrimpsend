/** 与后端 {@code app.admin.emails} 保持一致（用于前端门禁展示）；权限以后端为准 */
function parseAdminEmails(): Set<string> {
  const raw =
    process.env.ADMIN_EMAILS ??
    process.env.NEXT_PUBLIC_ADMIN_EMAILS ??
    '';
  return new Set(
    raw
      .split(',')
      .map((email) => email.trim().toLowerCase())
      .filter(Boolean),
  );
}

export const ADMIN_EMAILS = parseAdminEmails();

export function isAdminEmail(email: string | null | undefined): boolean {
  if (!email) return false;
  return ADMIN_EMAILS.has(email.trim().toLowerCase());
}
