import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";
import { ActionFeedbackProvider } from "@/components/action-feedback";
import { ConnectivityStatus } from "@/components/connectivity-status";

const poppins = localFont({
  src: [
    { path: "./fonts/Poppins-Regular.ttf", weight: "400" },
    { path: "./fonts/Poppins-Medium.ttf", weight: "500" },
    { path: "./fonts/Poppins-SemiBold.ttf", weight: "600" },
    { path: "./fonts/Poppins-Bold.ttf", weight: "700" },
  ],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "SeedRover",
    template: "%s - SeedRover",
  },
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
