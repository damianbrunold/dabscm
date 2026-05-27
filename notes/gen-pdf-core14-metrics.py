#!/usr/bin/env python3
"""
Generate scm-lib/libraries/scm-pdf-core14-metrics.scm from Adobe Core14 AFMs.

For each of the 12 Latin standard PDF base fonts, emits a 256-element width
vector indexed by WinAnsiEncoding byte (widths in 1/1000 em units, 0 for
undefined codes). For Symbol and ZapfDingbats, emits a 256-element vector
indexed by the font's native encoding code. Also emits per-font metrics
(FontBBox, Ascender, Descender, CapHeight, ItalicAngle, IsFixedPitch flag).

This is a one-time build tool. The generated file is checked in; the AFMs
are not a runtime dependency.

Usage:
    python3 notes/gen-pdf-core14-metrics.py > scm-lib/libraries/scm-pdf-core14-metrics.scm
"""

import os
import re
import sys

AFM_DIR = "/usr/share/matplotlib/mpl-data/fonts/pdfcorefonts"

# (font-name-symbol, AFM filename, base-font in PDF, encoding kind)
LATIN_FONTS = [
    ("helvetica",              "Helvetica.afm",            "Helvetica",             "winansi"),
    ("helvetica-bold",         "Helvetica-Bold.afm",       "Helvetica-Bold",        "winansi"),
    ("helvetica-oblique",      "Helvetica-Oblique.afm",    "Helvetica-Oblique",     "winansi"),
    ("helvetica-bold-oblique", "Helvetica-BoldOblique.afm","Helvetica-BoldOblique", "winansi"),
    ("times-roman",            "Times-Roman.afm",          "Times-Roman",           "winansi"),
    ("times-bold",             "Times-Bold.afm",           "Times-Bold",            "winansi"),
    ("times-italic",           "Times-Italic.afm",         "Times-Italic",          "winansi"),
    ("times-bold-italic",      "Times-BoldItalic.afm",     "Times-BoldItalic",      "winansi"),
    ("courier",                "Courier.afm",              "Courier",               "winansi"),
    ("courier-bold",           "Courier-Bold.afm",         "Courier-Bold",          "winansi"),
    ("courier-oblique",        "Courier-Oblique.afm",      "Courier-Oblique",       "winansi"),
    ("courier-bold-oblique",   "Courier-BoldOblique.afm",  "Courier-BoldOblique",   "winansi"),
]
NATIVE_FONTS = [
    ("symbol",        "Symbol.afm",       "Symbol",       "symbol"),
    ("zapf-dingbats", "ZapfDingbats.afm", "ZapfDingbats", "zapfdingbats"),
]

# WinAnsi (CP1252) byte -> Adobe glyph name. From PDF 1.7 Annex D.2.
# Undefined slots are left out and treated as width 0.
WINANSI = {
    32: "space",
    33: "exclam",      34: "quotedbl",   35: "numbersign", 36: "dollar",
    37: "percent",     38: "ampersand",  39: "quotesingle",40: "parenleft",
    41: "parenright",  42: "asterisk",   43: "plus",       44: "comma",
    45: "hyphen",      46: "period",     47: "slash",
    48: "zero", 49: "one", 50: "two", 51: "three", 52: "four",
    53: "five", 54: "six", 55: "seven", 56: "eight", 57: "nine",
    58: "colon",       59: "semicolon",  60: "less",       61: "equal",
    62: "greater",     63: "question",   64: "at",
    65: "A", 66: "B", 67: "C", 68: "D", 69: "E", 70: "F", 71: "G",
    72: "H", 73: "I", 74: "J", 75: "K", 76: "L", 77: "M", 78: "N",
    79: "O", 80: "P", 81: "Q", 82: "R", 83: "S", 84: "T", 85: "U",
    86: "V", 87: "W", 88: "X", 89: "Y", 90: "Z",
    91: "bracketleft", 92: "backslash", 93: "bracketright",
    94: "asciicircum", 95: "underscore", 96: "grave",
    97: "a", 98: "b", 99: "c", 100: "d", 101: "e", 102: "f", 103: "g",
    104: "h", 105: "i", 106: "j", 107: "k", 108: "l", 109: "m", 110: "n",
    111: "o", 112: "p", 113: "q", 114: "r", 115: "s", 116: "t", 117: "u",
    118: "v", 119: "w", 120: "x", 121: "y", 122: "z",
    123: "braceleft", 124: "bar", 125: "braceright", 126: "asciitilde",
    128: "Euro",
    130: "quotesinglbase", 131: "florin",      132: "quotedblbase",
    133: "ellipsis",       134: "dagger",      135: "daggerdbl",
    136: "circumflex",     137: "perthousand", 138: "Scaron",
    139: "guilsinglleft",  140: "OE",
    142: "Zcaron",
    145: "quoteleft",      146: "quoteright",  147: "quotedblleft",
    148: "quotedblright",  149: "bullet",      150: "endash",
    151: "emdash",         152: "tilde",       153: "trademark",
    154: "scaron",         155: "guilsinglright", 156: "oe",
    158: "zcaron",         159: "Ydieresis",
    160: "space",  # NBSP renders as space
    161: "exclamdown", 162: "cent", 163: "sterling", 164: "currency",
    165: "yen", 166: "brokenbar", 167: "section", 168: "dieresis",
    169: "copyright", 170: "ordfeminine", 171: "guillemotleft",
    172: "logicalnot", 173: "hyphen", 174: "registered", 175: "macron",
    176: "degree", 177: "plusminus", 178: "twosuperior", 179: "threesuperior",
    180: "acute", 181: "mu", 182: "paragraph", 183: "periodcentered",
    184: "cedilla", 185: "onesuperior", 186: "ordmasculine",
    187: "guillemotright", 188: "onequarter", 189: "onehalf",
    190: "threequarters", 191: "questiondown",
    192: "Agrave", 193: "Aacute", 194: "Acircumflex", 195: "Atilde",
    196: "Adieresis", 197: "Aring", 198: "AE", 199: "Ccedilla",
    200: "Egrave", 201: "Eacute", 202: "Ecircumflex", 203: "Edieresis",
    204: "Igrave", 205: "Iacute", 206: "Icircumflex", 207: "Idieresis",
    208: "Eth", 209: "Ntilde", 210: "Ograve", 211: "Oacute",
    212: "Ocircumflex", 213: "Otilde", 214: "Odieresis", 215: "multiply",
    216: "Oslash", 217: "Ugrave", 218: "Uacute", 219: "Ucircumflex",
    220: "Udieresis", 221: "Yacute", 222: "Thorn", 223: "germandbls",
    224: "agrave", 225: "aacute", 226: "acircumflex", 227: "atilde",
    228: "adieresis", 229: "aring", 230: "ae", 231: "ccedilla",
    232: "egrave", 233: "eacute", 234: "ecircumflex", 235: "edieresis",
    236: "igrave", 237: "iacute", 238: "icircumflex", 239: "idieresis",
    240: "eth", 241: "ntilde", 242: "ograve", 243: "oacute",
    244: "ocircumflex", 245: "otilde", 246: "odieresis", 247: "divide",
    248: "oslash", 249: "ugrave", 250: "uacute", 251: "ucircumflex",
    252: "udieresis", 253: "yacute", 254: "thorn", 255: "ydieresis",
}


def parse_afm(path):
    """Return (metrics_dict, name_to_width, code_to_width)."""
    info = {}
    name_w = {}
    code_w = {}
    with open(path) as fh:
        for raw in fh:
            line = raw.strip()
            if line.startswith("FontBBox"):
                parts = line.split()
                info["FontBBox"] = tuple(int(x) for x in parts[1:5])
            elif line.startswith("Ascender"):
                info["Ascender"] = int(line.split()[1])
            elif line.startswith("Descender"):
                info["Descender"] = int(line.split()[1])
            elif line.startswith("CapHeight"):
                info["CapHeight"] = int(line.split()[1])
            elif line.startswith("XHeight"):
                info["XHeight"] = int(line.split()[1])
            elif line.startswith("ItalicAngle"):
                info["ItalicAngle"] = float(line.split()[1])
            elif line.startswith("IsFixedPitch"):
                info["IsFixedPitch"] = line.split()[1].lower() == "true"
            elif line.startswith("C "):
                # C n ; WX w ; N name ; B x1 y1 x2 y2 ;
                m = re.match(r"C\s+(-?\d+)\s*;\s*WX\s+(-?\d+)\s*;\s*N\s+(\S+)", line)
                if not m:
                    continue
                code, wx, name = int(m.group(1)), int(m.group(2)), m.group(3)
                name_w[name] = wx
                if code >= 0:
                    code_w[code] = wx
                # Euro is conventionally encoded at 128 in WinAnsi but the
                # AFM may give it C -1.
                if name == "Euro":
                    code_w.setdefault(128, wx)
    return info, name_w, code_w


def widths_winansi(name_w):
    """Build a 256-element width vector keyed by WinAnsi byte."""
    out = [0] * 256
    for code, glyph in WINANSI.items():
        out[code] = name_w.get(glyph, 0)
    return out


def widths_native(code_w):
    """Build a 256-element width vector keyed by the font's native code."""
    out = [0] * 256
    for code, w in code_w.items():
        if 0 <= code < 256:
            out[code] = w
    return out


def emit_vector(name, widths):
    print(f"(define {name}")
    print(f"  (vector", end="")
    for i, w in enumerate(widths):
        if i % 16 == 0:
            print("\n   ", end=" ")
        print(f"{w:>4}", end=" ")
    print("))")
    print()


def main():
    print(";; Auto-generated by notes/gen-pdf-core14-metrics.py — do not edit.")
    print(";; Widths are in 1/1000 em units. Latin font vectors are indexed by")
    print(";; WinAnsiEncoding byte; Symbol/ZapfDingbats vectors are indexed by")
    print(";; the font's native encoding code.")
    print()

    all_fonts = []  # (sym, base, encoding, widths-var, metrics)

    for sym, afm, base, enc in LATIN_FONTS + NATIVE_FONTS:
        path = os.path.join(AFM_DIR, afm)
        info, name_w, code_w = parse_afm(path)
        widths = widths_winansi(name_w) if enc == "winansi" else widths_native(code_w)
        var = f"%core14-widths-{sym}"
        emit_vector(var, widths)
        all_fonts.append((sym, base, enc, var, info))

    # Per-font metrics record list: ((sym base-font encoding widths-vec . metrics-alist) ...)
    print("(define %core14-fonts")
    print("  (list")
    for sym, base, enc, var, info in all_fonts:
        bbox = info.get("FontBBox", (0, 0, 0, 0))
        asc = info.get("Ascender", 0)
        desc = info.get("Descender", 0)
        cap = info.get("CapHeight", 0)
        xh = info.get("XHeight", 0)
        ital = info.get("ItalicAngle", 0)
        fixed = "#t" if info.get("IsFixedPitch", False) else "#f"
        print(f"    (list '{sym} \"{base}\" '{enc} {var}")
        print(f"          '((font-bbox . #({bbox[0]} {bbox[1]} {bbox[2]} {bbox[3]}))")
        print(f"            (ascender . {asc})")
        print(f"            (descender . {desc})")
        print(f"            (cap-height . {cap})")
        print(f"            (x-height . {xh})")
        print(f"            (italic-angle . {ital})")
        print(f"            (fixed-pitch . {fixed})))")
    print("    ))")


if __name__ == "__main__":
    main()
