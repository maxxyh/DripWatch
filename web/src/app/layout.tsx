import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/sonner";
import { PwaClient } from "@/components/pwa-client";
import { ThemeProvider } from "@/components/theme-provider";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: { default: "DripWatch", template: "%s · DripWatch" },
  description: "A shared brew → taste → next recipe coffee notebook.",
  applicationName: "DripWatch",
  appleWebApp: { capable: true, statusBarStyle: "default", title: "DripWatch" },
  formatDetection: { telephone: false },
};
export const viewport = {
  width: "device-width",
  initialScale: 1,
  // Deliberately no pinch/double-tap zoom: this is an app shell, not a document, and iOS auto-
  // zooms on focusing any text input under 16px regardless of this setting. Fixing every input's
  // font size for that one case is more fragile than just turning zoom off outright, but it does
  // trade away zoom as an accessibility tool for low-vision users — acceptable here since the UI
  // itself must stay legible at 1x (see Theme/Dynamic Type invariants in CLAUDE.md).
  maximumScale: 1,
  userScalable: false,
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#fafafa" },
    { media: "(prefers-color-scheme: dark)", color: "#09090b" },
  ],
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <ThemeProvider>
          <PwaClient />
          {children}
          <Toaster richColors />
        </ThemeProvider>
      </body>
    </html>
  );
}
