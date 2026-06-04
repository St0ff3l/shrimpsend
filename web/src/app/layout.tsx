import type { Metadata } from "next";
import { ClientProviders } from "@/components/ClientProviders";
import { AuthExpiredRedirect } from "@/components/AuthExpiredRedirect";
import { CookieConsentDialog } from "@/components/CookieConsentDialog";
import { CorsAlertProvider } from "@/components/CorsAlertProvider";
import { Toaster } from "@/components/ui/sonner";
import "./globals.css";
import zhMessages from "@/messages/zh.json";
import { BRAND_FAVICON_32_SRC, BRAND_ICON_192_SRC, BRAND_ICON_512_SRC } from "@/lib/brandAssets";
import { DEFAULT_OG_IMAGE, SITE_NAME, appRobotsIndex, getConfiguredSiteOrigin } from "@/lib/seo";

export const metadata: Metadata = {
  metadataBase: new URL(getConfiguredSiteOrigin()),
  title: {
    default: zhMessages.metadata.title,
    template: `%s | ${SITE_NAME.zh}`,
  },
  description: zhMessages.metadata.description,
  icons: {
    icon: [
      { url: BRAND_FAVICON_32_SRC, sizes: "32x32", type: "image/png" },
      { url: BRAND_ICON_192_SRC, sizes: "192x192", type: "image/png" },
      { url: BRAND_ICON_512_SRC, sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: BRAND_ICON_192_SRC, sizes: "192x192", type: "image/png" }],
  },
  manifest: "/manifest.webmanifest",
  robots: appRobotsIndex,
  openGraph: {
    type: "website",
    siteName: `${SITE_NAME.zh} / ${SITE_NAME.en}`,
    title: zhMessages.metadata.title,
    description: zhMessages.metadata.description,
    images: [{ url: DEFAULT_OG_IMAGE, alt: zhMessages.metadata.title }],
  },
  twitter: {
    card: "summary_large_image",
    title: zhMessages.metadata.title,
    description: zhMessages.metadata.description,
    images: [DEFAULT_OG_IMAGE],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <head />
      <body className="antialiased">
        <div className="app-root relative min-h-dvh">
          <div className="app-atmosphere" aria-hidden />
          <ClientProviders>
            <div className="relative z-[1] min-h-dvh">
              <AuthExpiredRedirect />
              {children}
              <CookieConsentDialog />
              <CorsAlertProvider />
              <Toaster />
            </div>
          </ClientProviders>
        </div>
      </body>
    </html>
  );
}
