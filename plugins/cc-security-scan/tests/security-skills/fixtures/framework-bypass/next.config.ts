import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        source: "/v1/:path*",
        destination: "/api/:path*",
      },
    ];
  },
};

export default nextConfig;
