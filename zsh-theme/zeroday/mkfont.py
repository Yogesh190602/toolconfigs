#!/usr/bin/env python3
"""Build a CBDT/CBLC colour-bitmap font holding one image, sliced across N cells.

A terminal cell is about 1:2 (w:h), so a square picture needs two cells to keep
its aspect ratio. Each slice becomes its own glyph at a Private Use codepoint;
printing the codepoints consecutively reassembles the picture. Because they are
ordinary characters, zsh can measure the prompt and ZLE can redraw it safely --
which inline-image protocols cannot do.
"""
import sys
from io import BytesIO
from PIL import Image
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables.BitmapGlyphMetrics import SmallGlyphMetrics
from fontTools.ttLib.tables.C_B_D_T_ import cbdt_bitmap_format_17
from fontTools.ttLib.tables.E_B_L_C_ import Strike, SbitLineMetrics, eblc_index_sub_table_1

UPEM, PPEM = 1000, 128
ASC, DESC = 800, -200
START = 0xE900


def build(img_path, out_path, cells=2, family="ZeroDay Glyphs"):
    cell_w = PPEM // 2                      # monospace cell at this ppem
    img = Image.open(img_path).convert("RGBA").resize((cell_w * cells, PPEM), Image.LANCZOS)

    names = [".notdef"] + [f"zd{i}" for i in range(cells)]
    cmap = {START + i: f"zd{i}" for i in range(cells)}

    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap(cmap)
    # Empty outlines: the colour bitmap supplies all the pixels.
    pen = TTGlyphPen(None)
    fb.setupGlyf({n: pen.glyph() for n in names})
    adv = UPEM // 2
    fb.setupHorizontalMetrics({n: (adv, 0) for n in names})
    fb.setupHorizontalHeader(ascent=ASC, descent=DESC)
    fb.setupNameTable({"familyName": family, "styleName": "Regular",
                       "fullName": family, "psName": family.replace(" ", "")})
    fb.setupOS2(sTypoAscender=ASC, sTypoDescender=DESC, usWinAscent=ASC, usWinDescent=-DESC)
    fb.setupPost()
    font = fb.font

    # --- CBLC / CBDT -------------------------------------------------------
    strike = Strike()
    bst = strike.bitmapSizeTable
    bst.colorRef = bst.flags = 0
    bst.flags = 1                            # horizontal metrics
    bst.bitDepth = 32
    bst.ppemX = bst.ppemY = PPEM
    for d in ("hori", "vert"):
        m = SbitLineMetrics()
        m.ascender, m.descender = round(ASC / UPEM * PPEM), round(DESC / UPEM * PPEM)
        m.widthMax = cell_w
        m.caretSlopeNumerator, m.caretSlopeDenominator, m.caretOffset = 0, 1, 0
        m.minOriginSB = m.minAdvanceSB = m.maxBeforeBL = m.minAfterBL = 0
        m.pad1 = m.pad2 = 0
        setattr(bst, d, m)

    bitmaps = []
    for i in range(cells):
        buf = BytesIO()
        img.crop((i * cell_w, 0, (i + 1) * cell_w, PPEM)).save(buf, format="PNG")
        g = cbdt_bitmap_format_17(b"", None)
        g.metrics = SmallGlyphMetrics()
        g.metrics.height, g.metrics.width = PPEM, cell_w
        g.metrics.BearingX = 0
        g.metrics.BearingY = round(ASC / UPEM * PPEM)
        g.metrics.Advance = cell_w
        g.imageData = buf.getvalue()
        bitmaps.append(g)

    ist = eblc_index_sub_table_1(b"", None)
    ist.indexFormat, ist.imageFormat = 1, 17
    ist.imageSize = 0
    ist.names = [f"zd{i}" for i in range(cells)]
    strike.indexSubTables = [ist]

    font["CBLC"] = newTable("CBLC"); font["CBLC"].version = 3.0; font["CBLC"].strikes = [strike]
    font["CBDT"] = newTable("CBDT"); font["CBDT"].version = 3.0
    font["CBDT"].strikeData = [{f"zd{i}": bitmaps[i] for i in range(cells)}]

    font.save(out_path)
    return [chr(START + i) for i in range(cells)]


if __name__ == "__main__":
    chars = build(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 2)
    print("codepoints: " + " ".join("U+%04X" % ord(c) for c in chars))
    print("face: " + "".join(chars))
