/** @type {import('next').NextConfig} */
const nextConfig = {
        eslint: {
          ignoreDuringBuilds: true,
        },
    output: process.env.BUILD_STANDALONE === "true" ? "standalone" : undefined,
}
  
module.exports = nextConfig
