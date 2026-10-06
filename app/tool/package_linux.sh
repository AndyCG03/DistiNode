#!/usr/bin/env bash
# Empaqueta la compilación de Linux en un .deb instalable y un .tar.gz portable.
# Uso (desde app/, tras `flutter build linux --release`):  bash tool/package_linux.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
ARCH=amd64
BUNDLE=build/linux/x64/release/bundle
OUT=build/installer
[ -x "$BUNDLE/distinode" ] || { echo "Falta $BUNDLE: ejecuta flutter build linux --release"; exit 1; }
mkdir -p "$OUT"

# ── .tar.gz portable ─────────────────────────────────────────
TAR_DIR=$(mktemp -d)
cp -r "$BUNDLE" "$TAR_DIR/DistiNode"
cp assets/icon/app_icon.png "$TAR_DIR/DistiNode/distinode.png"
cp installer/linux/distinode.desktop "$TAR_DIR/DistiNode/"
cat > "$TAR_DIR/DistiNode/LEEME.txt" <<EOF
DistiNode $VERSION para Linux (x86_64)

Ejecutar sin instalar:   ./distinode
Requisitos: GTK 3 (viene en Ubuntu, Debian, Fedora, Mint… con escritorio).
Los proyectos se guardan en ~/Documents/DistiNode/Proyectos (o la carpeta de documentos de tu idioma).
EOF
tar -C "$TAR_DIR" -czf "$OUT/DistiNode-$VERSION-linux-x64.tar.gz" DistiNode
rm -rf "$TAR_DIR"

# ── .deb ─────────────────────────────────────────────────────
PKG=$(mktemp -d)/distinode_${VERSION}_${ARCH}
mkdir -p "$PKG/DEBIAN" "$PKG/opt/distinode" "$PKG/usr/bin" "$PKG/usr/share/applications" \
  "$PKG/usr/share/icons/hicolor/512x512/apps"
cp -r "$BUNDLE"/. "$PKG/opt/distinode/"
ln -s /opt/distinode/distinode "$PKG/usr/bin/distinode"
cp installer/linux/distinode.desktop "$PKG/usr/share/applications/cu.cujae.distinode.desktop"
cp assets/icon/app_icon.png "$PKG/usr/share/icons/hicolor/512x512/apps/distinode.png"
SIZE=$(du -sk "$PKG" | cut -f1)
cat > "$PKG/DEBIAN/control" <<EOF
Package: distinode
Version: $VERSION
Section: education
Priority: optional
Architecture: $ARCH
Installed-Size: $SIZE
Depends: libgtk-3-0 | libgtk-3-0t64, libglib2.0-0 | libglib2.0-0t64
Maintainer: DistiNode <noreply@github.com>
Homepage: https://github.com/AndyCG03/web-sistemas-distribuidos
Description: Diseña sistemas distribuidos y míralos funcionar
 Simulador educativo de sistemas distribuidos: balanceadores, servidores,
 cachés, colas y bases de datos sobre un mapa de metro donde cada petición
 es un tren. Funciona sin cuentas ni conexión; los proyectos se guardan
 en archivos locales.
EOF
cat > "$PKG/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q /usr/share/icons/hicolor || true
EOF
chmod 755 "$PKG/DEBIAN/postinst"
dpkg-deb --build --root-owner-group "$PKG" "$OUT/DistiNode-$VERSION-linux-amd64.deb"
ls -la "$OUT"
