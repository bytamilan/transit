/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Phase 12: lets the Dockerfile ship a minimal self-contained server
  // (.next/standalone) instead of the full node_modules tree.
  output: "standalone",
};

export default nextConfig;
