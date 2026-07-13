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
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
