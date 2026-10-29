import type { Metadata } from "next";
import "./globals.css";
import "./heist-theme.css";

export const metadata: Metadata = {
  title: "O Cofre Desaparecido",
  description: "Jogo investigativo de geometria espacial: resolva desafios e descubra quem levou o cofre.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body className="antialiased">{children}</body>
    </html>
  );
}
