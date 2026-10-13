"""Bake original clue text into worn engraving depth masks, using bundled fonts.

These are scalar material maps, not screenshots or replacement scene artwork.
The stone shader shades their shallow grooves under the actual scene lights.
"""
import hashlib
import json
from pathlib import Path
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'game/assets/inscriptions'
FONT = ROOT / 'game/assets/NotoSerifSC.ttf'
SOURCE = ROOT / 'game/scripts/puzzle_world.gd'
WIDTH, HEIGHT = 1024, 1014
PPM = WIDTH / 1.04


def decode(value):
    return json.loads('"' + value + '"')


def font(size):
    result = ImageFont.truetype(str(FONT), size)
    result.set_variation_by_axes([600])
    return result


def row(canvas, text, size, y, rng, left=None):
    face = font(round(size * .0018 * PPM))
    advances = [face.getlength(char) for char in text]
    x = (WIDTH - sum(advances)) / 2 if left is None else (left + .52) * PPM
    cy = (1.77 - y) * PPM
    assert sum(advances) / PPM <= .98, text
    for char, advance in zip(text, advances):
        tile = Image.new('L', (90, 100))
        ImageDraw.Draw(tile).text((45, 50), char, font=face, fill=255, anchor='mm')
        # Sub-millimetre cutting differences break the typeset baseline.
        tile = tile.rotate(float(rng.uniform(-1.6, 1.6)), Image.Resampling.BICUBIC)
        px = round(x + advance / 2 - 45 + rng.uniform(-.6, .6))
        py = round(cy - 50 + rng.uniform(-1.1, 1.1))
        canvas.paste(tile, (px, py), tile)
        x += advance


def main():
    OUT.mkdir(exist_ok=True)
    source = SOURCE.read_text()
    faces_block = source.split('const RECORD_FACES = {', 1)[1].split('}', 1)[0]
    notes_block = source.split('const NOTES = {', 1)[1].split('}', 1)[0]
    string = r'((?:[^"\\]|\\.)*)'
    faces = {key: (decode(code), decode(body)) for key, code, body in
             re.findall(r'"(\w+)":\["' + string + r'","' + string + r'"\]', faces_block)}
    titles = {key: decode(note).split('\n')[0] for key, note in
              re.findall(r'"(\w+)":"' + string + '"', notes_block)}
    assert len(faces) == len(titles) == 6
    assets = {}
    for index, (key, (code, body)) in enumerate(faces.items()):
        rng = np.random.default_rng(11300 + index)
        canvas = Image.new('L', (WIDTH, HEIGHT))
        row(canvas, code, 21, 1.66, rng)
        row(canvas, titles[key], 27, 1.52, rng)
        lines = body.split('\n')
        for i, line in enumerate(lines):
            row(canvas, line, 38, 1.25 + ((len(lines) - 1) / 2 - i) * .0846, rng, -.47)
        row(canvas, '……余文漫漶……', 18, .91, rng)
        # Shallow, uneven cutting plus small missing fragments in old strokes.
        grain = Image.fromarray(rng.integers(0, 256, (170, 170), dtype=np.uint8))
        grain = np.asarray(grain.resize((WIDTH, HEIGHT), Image.Resampling.BILINEAR), dtype=float) / 255
        losses = Image.new('L', (WIDTH, HEIGHT), 255)
        draw = ImageDraw.Draw(losses)
        for _ in range(2100):
            x, y = rng.integers(0, WIDTH), rng.integers(0, HEIGHT)
            rx, ry = float(rng.uniform(.5, 2.5)), float(rng.uniform(.5, 2.2))
            draw.ellipse((x-rx, y-ry, x+rx, y+ry), fill=int(rng.uniform(0, 65)))
        losses = np.asarray(losses.filter(ImageFilter.GaussianBlur(.25)), dtype=float) / 255
        original = np.asarray(canvas, dtype=float) / 255
        worn = np.clip(original * (.66 + .34 * grain) * losses, 0, 1)
        mask = Image.fromarray((worn * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.35))
        output = OUT / f'{key}_depth.png'
        mask.save(output)
        assets[key] = {'code': code, 'title': titles[key], 'body': body,
                       'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
                       'remaining_stroke_mass': float(worn.sum() / original.sum()),
                       'dimensions': [WIDTH, HEIGHT]}
    report = {'version': '1.13.1', 'font': 'Noto Serif SC, weight 600, bundled OFL font',
              'font_sha256': hashlib.sha256(FONT.read_bytes()).hexdigest(),
              'method': 'Original text rasterization; cutting variation, erosion, scalar engraving depth',
              'assets': assets}
    (OUT / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('STELE_INSCRIPTIONS_OK', len(assets))


if __name__ == '__main__':
    main()
