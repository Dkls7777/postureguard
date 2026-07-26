import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Emit a self-contained server bundle with only the dependencies actually
  // used at runtime. Keeps the container image small and its attack surface low.
  output: "standalone",
};

export default nextConfig;
