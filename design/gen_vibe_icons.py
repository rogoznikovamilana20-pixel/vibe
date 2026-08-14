# -*- coding: utf-8 -*-
"""VibeIcons: сборка фирменного шрифта иконок Vibe.
Пути глифов — 24px-грид (Material-нотация, y ВНИЗ). Конвейер готов
для расширения набора: добавь запись в ICONS и пересобери.

ВАЖНО: SVG-пути заданы в системе координат y-down (origin сверху-слева).
Шрифтовое пространство — y-up (origin снизу-слева). Поэтому при переносе
точек применяется отражение по Y: (scale, 0, 0, -scale, 0, UPEM),
чтобы глиф не оказался перевёрнутым."""
import sys

from fontTools.cu2qu import curve_to_quadratic
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.transformPen import TransformPointPen
from fontTools.pens.ttGlyphPen import TTGlyphPointPen
from fontTools.svgLib.path import parse_path

UPEM = 2048
SCALE = UPEM / 24.0
CURVE_TO_QUAD_MAX_ERR = 0.9


ICONS = {
    "vib_send": "M2.01 3.5 20.2 12 2.01 20.5c-.72.33-1.5-.19-1.5-.97v-4.8c0-.47.33-.87.79-.96l5.94-1.77-5.94-1.77c-.46-.09-.79-.49-.79-.96V4.47c0-.78.78-1.3 1.5-.97Z",
    "vib_back": "M9.6 12 20 2.3c.4-.4.4-1 .1-1.4-.4-.4-1-.4-1.4-.1L7.5 11.3c-.4.4-.4 1 0 1.4l11.2 10.5c.4.4 1 .3 1.4-.1.3-.4.3-1-.1-1.4L9.6 12Z",
    "vib_forward": "M14.4 12 4 2.3c-.4-.4-.4-1-.1-1.4.4-.4 1-.4 1.4-.1l11.2 10.5c.4.4.4 1 0 1.4L5.3 23.2c-.4.4-1 .3-1.4-.1-.3-.4-.3-1 .1-1.4l10.4-9.7Z",
    "vib_check": "M10.1 13.9 5.9 9.7c-.4-.4-1.1-.4-1.5 0-.4.4-.4 1 0 1.4l5.1 5.1c.4.4 1.1.4 1.5 0L20.6 5.7c.4-.4.4-1 0-1.4-.4-.4-1.1-.4-1.5 0l-9 9.6Z",
    "vib_check_all": "M7.5 15.4 4 11.9c-.4-.4-1-.4-1.4 0-.4.4-.4 1 0 1.4l4.5 4.5c.4.4 1 .4 1.4 0l10-10c.4-.4.4-1 0-1.4-.4-.4-1-.4-1.4 0L7.5 15.4Zm-3.9-6 1-1c.4-.4.4-1 0-1.4l-1-1c-.4-.4-1-.4-1.4 0l-1 1c-.4.4-.4 1 0 1.4l1 1c.4.4 1 .4 1.4 0Zm12.9 1.4 6.1 6.1c.4.4.4 1 0 1.4l-1 1c-.4.4-1 .4-1.4 0l-10-10c-.4-.4-.4-1 0-1.4l1-1c.4.4-1 .4-1.4 0l3.9 3.9Z",
    "vib_edit": "M3 17.25V21h3.75L17.8 9.94l-3.75-3.75L3 17.25Zm17.72-10.21a.99.99 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83Z",
    "vib_trash": "M6.5 5h11l-.9 14.1c-.1 1.05-.93 1.9-2 1.9H9.4c-1.07 0-1.9-.85-2-1.9L6.5 5Zm3-.5c0-.83.67-1.5 1.5-1.5h2c.83 0 1.5.67 1.5 1.5V5h-5V4.5ZM10 8h1v10h-1V8Zm3 0h1v10h-1V8Z",
    "vib_pin": "M12 2c-3.87 0-7 3.13-7 7 0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7Zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5Z",
    "vib_star": "M12 17.3 18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21l6.18-3.7Z",
    "vib_heart": "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35Z",
    "vib_bolt": "M13.2 2.5 5.5 13.5h4.7l-1.4 8 7.7-11h-4.7l1.4-8Z",
    "vib_home": "M12 3.5 20 11v9.1c0 .8-.65 1.4-1.44 1.4h-4.06v-5.5h-5V21.5H5.44c-.79 0-1.44-.6-1.44-1.4V11l8-7.5Z",
    "vib_phone": "M6.62 10.79c1.44 2.83 3.76 5.14 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1-9.39 0-17-7.61-17-17 0-.55.45-1 1-1h3.5c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.25 1.02l-2.2 2.2Z",
    "vib_video": "M4 5.5h10.5c1.4 0 2.5 1.1 2.5 2.5v8c0 1.4-1.1 2.5-2.5 2.5H4c-1.4 0-2.4-1.1-2.4-2.5V8c0-1.4 1-2.5 2.4-2.5Zm14.2 2.4 3.3-2.2c.6-.4 1.5 0 1.5.7v10.8c0 .7-.9 1.1-1.5.7l-3.3-2.2V8.4c0-.3.1-.6 0-.5Z",
    "vib_camera": "M4 5.5h15.2c1.5 0 2.8 1.15 2.8 2.7v8.1c0 1.55-1.3 2.7-2.8 2.7H4c-1.5 0-3-1.15-3-2.7V8.2c0-1.55 1.5-2.7 3-2.7Zm4.2 6.2a3.8 3.8 0 1 0 7.6 0 3.8 3.8 0 0 0-7.6 0Z",
    "vib_more_vert": "M12 8.75a2.25 2.25 0 1 1 0-4.5 2.25 2.25 0 0 1 0 4.5Zm0 5.5a2.25 2.25 0 1 1-.01-4.49A2.25 2.25 0 0 1 12 14.25Zm0 5.5a2.25 2.25 0 1 1-.01-4.49A2.25 2.25 0 0 1 12 19.75Z",
    "vib_more_hor": "M6 10.25a1.75 1.75 0 1 1-.01 3.49A1.75 1.75 0 0 1 6 10.25Zm6 0a1.75 1.75 0 1 1-.01 3.49A1.75 1.75 0 0 1 12 10.25Zm6 0a1.75 1.75 0 1 1-.01 3.49A1.75 1.75 0 0 1 18 10.25Z",
    "vib_plus": "M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6V5Z",
    "vib_close": "M18.3 5.71 12 12l6.3 6.29a.996.996 0 1 1-1.41 1.41L10.59 13.41 4.3 19.7a.996.996 0 1 1-1.41-1.41L9.18 12 2.89 5.71A.996.996 0 1 1 4.3 4.3l6.29 6.3 6.3-6.3a.996.996 0 0 1 1.41 1.41Z",
    "vib_search": "M9.7 5.8a5.2 5.2 0 0 1 5.2 5.2 5.2 5.2 0 0 1-5.2 5.2 5.2 5.2 0 0 1-5.2-5.2 5.2 5.2 0 0 1 5.2-5.2Zm7.2 9.9 5.3 5.3c.5.5.5 1.3 0 1.8-.5.5-1.3.5-1.8 0l-5.3-5.3c-.5-.5-.5-1.3 0-1.8.5-.5 1.3-.5 1.8 0Z",
    "vib_mic": "M8.5 4.5v6c0 1.93 1.57 3.5 3.5 3.5s3.5-1.57 3.5-3.5v-6c0-1.93-1.57-3.5-3.5-3.5s-3.5 1.57-3.5 3.5Zm10.7 6.2c0 3.7-3 6.7-6.7 6.7h-.8c0 1.8 0 3.1.1 4.1h2.3v2.5H9.9v-2.5h2.1c-.2-1-.3-2.4-.3-4.1h-.4c-3.7 0-6.7-3-6.7-6.7h2c0 2.9 2.4 5.2 5.4 5.2s5.4-2.3 5.4-5.2h2Z",
    "vib_lock": "M12 4a4.5 4.5 0 0 0-4.5 4.5V10h-2.2A1.3 1.3 0 0 0 4 11.3v8.4c0 .72.58 1.3 1.3 1.3h13.4c.72 0 1.3-.58 1.3-1.3v-8.4c0-.72-.58-1.3-1.3-1.3h-2.2V8.5A4.5 4.5 0 0 0 12 4Zm0 9.3c.7 0 1.3.4 1.3 1 0 .5-.3.9-.8 1.1v1.4h-1v-1.4c-.5-.2-.8-.6-.8-1.1 0-.6.6-1 1.3-1Z",
    "vib_folder": "M10.4 5 12.4 7.5H20c1.1 0 2 .9 2 2V18c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V7c0-1.1.9-2 2-2h6.4Z",
    "vib_archive": "M4 4h16c.55 0 1 .45 1 1v3c0 .55-.45 1-1 1H4c-.55 0-1-.45-1-1V5c0-.55.45-1 1-1Zm-1 7h18v7c0 2-1.5 3.5-3.5 3.5h-11C4.5 21.5 3 20 3 18v-7Zm9 1.3c.3 0 .5.1.7.3l2 2c.4.4.4 1 0 1.4-.4.4-1 .4-1.4 0l-.3-.3v3.1c0 .55-.45 1-1 1s-1-.45-1-1v-3.1l-.3.3c-.4.4-1 .4-1.4 0-.4-.4-.4-1 0-1.4l2-2c.2-.2.4-.3.7-.3Z",
    "vib_user": "M12 12a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9Zm0 2.2c-4.4 0-8 1.9-8 4.3v1.5h16v-1.5c0-2.4-3.6-4.3-8-4.3Z",
    "vib_group": "M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3Zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3Zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5C15 14.17 10.33 13 8 13Zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5Z",
    "vib_copy": "M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1Zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2Z",
    "vib_reply": "M10 9V5l-7 7 7 7v-4.1c5 0 8.5 1.6 11 5.1-1-5-4-10-11-11Z",
    "vib_download": "M19 9h-4V3H9v6H5l7 7 7-7Zm-14 9v2h14v-2H5Z",
    "vib_volume": "M3 9v6h4l5 5V4L7 9H3Zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02Z",
    "vib_play": "M8 5v14l11-7L8 5Z",
    "vib_pause": "M6 19h4V5H6v14Zm8-14v14h4V5h-4Z",
    "vib_eye": "M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5Zm0 12.5c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5Zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3Z",
    "vib_info": "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm1 15h-2v-6h2v6Zm0-8h-2V7h2v2Z",
    "vib_file": "M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6ZM13 9V3.5L18.5 9H13Z",
    "vib_clock": "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm5 11h-5c-.55 0-1-.45-1-1V7c0-.55.45-1 1-1s1 .45 1 1v4h4c.55 0 1 .45 1 1s-.45 1-1 1Z",
    "vib_bubble": "M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2Z",
    "vib_smile": "M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm-3.6 7.6c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5-1.5-.67-1.5-1.5.67-1.5 1.5-1.5Zm7.2 0c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5-1.5-.67-1.5-1.5.67-1.5 1.5-1.5ZM12 17.3c-2.33 0-4.31-1.46-5.11-3.5h10.22c-.8 2.04-2.78 3.5-5.11 3.5Z",
    "vib_settings": "M19.14 12.94c.04-.3.06-.61.06-.94s-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58ZM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6Z",
    "vib_attach": "M14 3.5c1.66 0 3 1.34 3 3V15c0 2.76-2.24 5-5 5s-5-2.24-5-5V7h1.5v8c0 1.93 1.57 3.5 3.5 3.5s3.5-1.57 3.5-3.5V6.5c0-1.1-.9-2-2-2s-2 .9-2 2V15c0 .55.45 1 1 1s1-.45 1-1V7H15v8c0 1.38-1.12 2.5-2.5 2.5S10 16.38 10 15V6.5c0-1.66 1.34-3 3-3Z",
}


def _cubic_to_points(cubic):
    """cubic -> точки TrueType-нотации: [(off, on), ...] (первая точка уже в контуре)."""
    p0, c1, c2, p3 = cubic
    if c1 == p0 and c2 == p3:
        return [(p3, False)]
    parts = curve_to_quadratic(
        (list(p0), list(c1), list(c2), list(p3)),
        max_err=CURVE_TO_QUAD_MAX_ERR,
    )
    return [(tuple(parts[i]), i % 2 == 1) for i in range(1, len(parts))]


class PointRecorder:
    def __init__(self):
        self.contours = []
        self._cur = None
        self._start = None
        self._last = None

    def moveTo(self, pt):
        self._cur = [(pt, False)]
        self._start = pt
        self._last = pt

    def lineTo(self, pt):
        self._cur.append((pt, False))
        self._last = pt

    def curveTo(self, *pts):
        for off, on in _cubic_to_points([self._last] + list(pts)):
            self._cur.append((off, on))
        self._last = pts[-1]

    def qCurveTo(self, *pts):
        for p in pts[:-1]:
            self._cur.append((p, True))
        self._cur.append((pts[-1], False))
        self._last = pts[-1]

    def closePath(self):
        if self._start == self._last:
            self._cur = self._cur[:-1]
        self.contours.append(self._cur)
        self._cur = None


def _seg_type(pts, i):
    if i == 0:
        return "move"
    if pts[i][1]:
        return None
    if pts[i - 1][1]:
        return "qcurve"
    return "line"


def make_glyph(d, scale):
    rec = PointRecorder()
    if d:
        parse_path(d, rec)
    pen = TTGlyphPointPen(None)
    # SVG y-down -> font y-up: отражаем по Y и сдвигаем на UPEM.
    tpp = TransformPointPen(pen, (scale, 0, 0, -scale, 0, UPEM))
    for c in rec.contours:
        tpp.beginPath()
        for i, (p, off) in enumerate(c):
            tpp.addPoint(p, segmentType=_seg_type(c, i))
        tpp.endPath()
    return pen.glyph()


def build(out):
    names = [".notdef"] + list(ICONS)
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({0xE000 + i: n for i, n in enumerate(ICONS)})
    glyf = {n: make_glyph(d, SCALE) for n, d in ICONS.items()}
    glyf[".notdef"] = make_glyph("", SCALE)
    fb.setupGlyf(glyf)
    # Корректные метрики: advance = em, lsb = реальный xMin глифа.
    hmtx = {}
    for n in names:
        g = glyf[n]
        xMin = g.xMin if g.numberOfContours > 0 else 0
        hmtx[n] = (UPEM, xMin)
    fb.setupHorizontalMetrics(hmtx)
    fb.setupHorizontalHeader(ascent=UPEM, descent=0)
    fb.setupNameTable({
        "familyName": "VibeIcons",
        "styleName": "Regular",
        "uniqueFontIdentifier": "VibeIcons 1.0",
        "fullName": "VibeIcons",
        "psName": "VibeIcons-Regular",
        "version": "Version 1.0",
    }, mac=False)
    fb.setupOS2(sTypoAscender=UPEM, sTypoDescender=0,
                usWeightClass=400, usWidthClass=5,
                fsSelection=0b1000000, usWinAscent=UPEM, usWinDescent=0)
    fb.setupPost()
    fb.save(out)
    print(f"OK: {len(ICONS)} глифов -> {out}")


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "vibe_icons.ttf")
