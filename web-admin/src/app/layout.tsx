import type { Metadata } from "next";
import { Poppins } from "next/font/google";
import "./globals.css";
import { ActionFeedbackProvider } from "@/components/action-feedback";
import { ConnectivityStatus } from "@/components/connectivity-status";

const poppins = Poppins({
  variable: "--font-inter",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800", "900"],
  display: "swap",
});

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
                document.documentElement.dataset.theme = theme === "dark" ? "dark" : "light";
              } catch (_) {
                document.documentElement.dataset.theme = "light";
              }
            `,
          }}
        />
      </head>
      <body className={poppins.variable}><ActionFeedbackProvider><ConnectivityStatus>{children}</ConnectivityStatus></ActionFeedbackProvider></body>
    </html>
  );
}
