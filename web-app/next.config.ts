import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  experimental: {
    serverActions: {
      allowedOrigins: ['localhost:3000', 'meetneo.app', 'www.meetneo.app', '*.vercel.app']
    }
  },
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'lh3.googleusercontent.com',
      },
      {
        protocol: 'https',
        hostname: 'nfhlcsciwdmglhlfloms.supabase.co',
      }
    ],
  },
};

export default nextConfig;
