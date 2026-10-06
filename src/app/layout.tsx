import type { Metadata, Viewport } from "next";
import "@fontsource-variable/source-sans-3";
import { themeInitScript } from "@/components/ThemeToggle";
import "./globals.css";

// La configuración (base de datos, Liveblocks, Google) se lee al ejecutar, no al construir:
// una misma imagen de Docker sirve para cualquier servidor.
export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: { default: "DistiNode", template: "%s · DistiNode" },
  description:
    "Diseña sistemas distribuidos en equipo y míralos funcionar en vivo: balanceadores, servidores, cachés y bases de datos.",
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f3f6f4" },
    { media: "(prefers-color-scheme: dark)", color: "#0d1512" },
  ],
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="es" className="h-full" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
      </head>
      <body className="flex min-h-full flex-col">{children}</body>
    </html>
  );
}
