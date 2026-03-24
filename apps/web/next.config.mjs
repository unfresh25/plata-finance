/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ['@jojos/core', '@jojos/ui'],
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '**.supabase.co' },
    ],
  },
};

export default nextConfig;
