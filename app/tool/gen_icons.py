"""Genera los iconos de la app a partir de los polígonos del logo (los mismos de Logo.tsx).

Uso: python tool/gen_icons.py   (desde app/)
"""
from PIL import Image, ImageDraw

VERDE = (11, 107, 79, 255)
GRIS = (166, 166, 166, 255)
BLANCO = (255, 255, 255, 255)

POLYLINES = [
    [97, 300, 97, 165, 205, 103],
    [375, 103, 483, 165, 483, 300],
    [188, 410, 290, 469, 392, 410],
]
LINES = [[290, 140, 290, 190], [160, 350, 215, 318]]
POLYS = [
    (GRIS, [290.0, 184.0, 366.2, 228.0, 290.0, 272.0, 213.8, 228.0]),
    (VERDE, [213.8, 228.0, 290.0, 272.0, 290.0, 360.0, 213.8, 316.0]),
    (BLANCO, [224.5, 246.5, 282.4, 276.4, 282.4, 346.8, 224.5, 309.8]),
    (VERDE, [290.0, 272.0, 366.2, 228.0, 366.2, 316.0, 290.0, 360.0]),
    (GRIS, [290.0, 4.0, 347.2, 37.0, 290.0, 70.0, 232.8, 37.0]),
    (VERDE, [232.8, 37.0, 290.0, 70.0, 290.0, 136.0, 232.8, 103.0]),
    (BLANCO, [240.8, 50.9, 284.3, 73.3, 284.3, 126.1, 240.8, 98.4]),
    (VERDE, [290.0, 70.0, 347.2, 37.0, 347.2, 103.0, 290.0, 136.0]),
    (GRIS, [110.0, 316.0, 167.2, 349.0, 110.0, 382.0, 52.8, 349.0]),
    (VERDE, [52.8, 349.0, 110.0, 382.0, 110.0, 448.0, 52.8, 415.0]),
    (BLANCO, [60.8, 362.9, 104.3, 385.3, 104.3, 438.1, 60.8, 410.4]),
    (VERDE, [110.0, 382.0, 167.2, 349.0, 167.2, 415.0, 110.0, 448.0]),
    (GRIS, [470.0, 316.0, 527.2, 349.0, 470.0, 382.0, 412.8, 349.0]),
    (VERDE, [412.8, 349.0, 470.0, 382.0, 470.0, 448.0, 412.8, 415.0]),
    (BLANCO, [420.8, 362.9, 464.3, 385.3, 464.3, 438.1, 420.8, 410.4]),
    (VERDE, [470.0, 382.0, 527.2, 349.0, 527.2, 415.0, 470.0, 448.0]),
]


def logo(size: int, pad: float, bg=None, radius: float = 0.22) -> Image.Image:
    ss = 4  # supermuestreo para bordes suaves
    S = size * ss
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * radius), fill=bg)
    inner = S * (1 - 2 * pad)
    k = inner / 540
    ox = S * pad + (inner - 540 * k) / 2
    oy = S * pad + (inner - 500 * k) / 2

    def P(x, y):
        return (ox + (x - 20) * k, oy + (y + 10) * k)

    for pl in POLYLINES:
        pts = [P(pl[i], pl[i + 1]) for i in range(0, len(pl), 2)]
        d.line(pts, fill=VERDE, width=max(1, int(24 * k)), joint="curve")
    for l in LINES:
        d.line([P(l[0], l[1]), P(l[2], l[3])], fill=VERDE, width=max(1, int(4 * k)))
    for color, pts in POLYS:
        d.polygon([P(pts[i], pts[i + 1]) for i in range(0, len(pts), 2)], fill=color)
    return img.resize((size, size), Image.LANCZOS)


def main():
    # Windows: .ico con varios tamaños, sobre fondo transparente.
    base = logo(256, 0.04)
    base.save("windows/runner/resources/app_icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    # PNG grande (Linux, README, instalador).
    logo(512, 0.06).save("assets/icon/app_icon.png")
    # Android: fondo blanco redondeado (icono clásico) en cada densidad.
    for folder, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        logo(px, 0.14, bg=BLANCO).save(f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png")
    print("ok")


if __name__ == "__main__":
    main()
