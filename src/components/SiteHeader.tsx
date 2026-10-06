import Link from "next/link";
import { Logo } from "@/components/Logo";
import { ThemeToggle } from "@/components/ThemeToggle";

export function SiteHeader({ children }: { children?: React.ReactNode }) {
  return (
    <header className="mx-auto flex h-16 w-full max-w-6xl items-center justify-between gap-4 px-5">
      <Link href="/" aria-label="DistiNode, inicio" className="rounded-md">
        <Logo />
      </Link>
      <div className="flex items-center gap-2">
        <Link
          href="/guia"
          className="rounded-full px-3 py-1.5 text-sm font-semibold text-gris-texto hover:bg-verde-suave hover:text-tinta"
        >
          Guía
        </Link>
        {children}
        <ThemeToggle />
      </div>
    </header>
  );
}
