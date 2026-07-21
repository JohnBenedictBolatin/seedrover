import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "SeedRover Admin",
  description: "Farm sales, inventory, crop, and activity supervision for SeedRover.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              try {
                var theme = window.localStorage.getItem("seedrover-theme");
                document.documentElement.dataset.theme = theme === "light" ? "light" : "dark";
              } catch (_) {
                document.documentElement.dataset.theme = "dark";
              }
            `,
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
