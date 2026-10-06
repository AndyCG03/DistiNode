# Servidor de Liveblocks autoalojado (AGPL-3.0): el mismo núcleo que la nube de Liveblocks.
# Equivale a la imagen oficial ghcr.io/liveblocks/dev-server, pero construida desde npm.
FROM oven/bun:1-alpine
RUN mkdir -p /opt/lb && cd /opt/lb && bun add liveblocks@1.9.0
WORKDIR /data
EXPOSE 1153
# --persist guarda los diagramas en /data/.liveblocks (volumen).
CMD ["bun", "/opt/lb/node_modules/liveblocks/dist/index.js", "dev", "--host", "0.0.0.0", "--port", "1153", "--no-check", "--persist"]
