import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Imagen de Docker mínima: .next/standalone trae su propio server.js y solo las dependencias usadas.
  output: "standalone",
};

export default nextConfig;
