import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Transit Admin",
  description: "Fleet, drivers and duty roster back office.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
