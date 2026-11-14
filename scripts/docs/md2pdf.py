# Autores: Alanna Santos e Apolonio Neto. Projeto da dupla na residência CI Expert,
# polo UFCG (trilha de Physical Design), 2026.
import re
import sys
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.fonts import addMapping
from reportlab.platypus import (HRFlowable, ListFlowable, ListItem, Paragraph,
                                Preformatted, SimpleDocTemplate, Spacer, Table,
                                TableStyle, KeepTogether)

SRC, OUT, FOOT = sys.argv[1], sys.argv[2], sys.argv[3]
F = "C:/Windows/Fonts/"
pdfmetrics.registerFont(TTFont("Arial", F + "arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", F + "arialbd.ttf"))
pdfmetrics.registerFont(TTFont("Consolas", F + "consola.ttf"))
pdfmetrics.registerFont(TTFont("Consolas-Bold", F + "consolab.ttf"))
addMapping("Arial", 0, 0, "Arial"); addMapping("Arial", 1, 0, "Arial-Bold")
addMapping("Arial", 0, 1, "Arial"); addMapping("Arial", 1, 1, "Arial-Bold")
addMapping("Consolas", 0, 0, "Consolas"); addMapping("Consolas", 1, 0, "Consolas-Bold")

ACCENT = colors.HexColor("#1f4e79")
body = ParagraphStyle("body", fontName="Arial", fontSize=10, leading=14, spaceAfter=4, alignment=TA_LEFT)
h1 = ParagraphStyle("h1", parent=body, fontName="Arial-Bold", fontSize=18, leading=22, spaceAfter=8, textColor=ACCENT)
h2 = ParagraphStyle("h2", parent=body, fontName="Arial-Bold", fontSize=14, leading=18, spaceBefore=10, spaceAfter=6, textColor=ACCENT, keepWithNext=1)
h3 = ParagraphStyle("h3", parent=body, fontName="Arial-Bold", fontSize=11.5, leading=15, spaceBefore=8, spaceAfter=4)
h4 = ParagraphStyle("h4", parent=body, fontName="Arial-Bold", fontSize=10.5, leading=14, spaceBefore=6, spaceAfter=3,
                    textColor=colors.HexColor("#333333"), keepWithNext=1)
code = ParagraphStyle("code", fontName="Consolas", fontSize=8.6, leading=11.2,

                      spaceBefore=0, spaceAfter=0)
cell = ParagraphStyle("cell", parent=body, fontSize=8.8, leading=11.5, spaceAfter=0)
cellh = ParagraphStyle("cellh", parent=cell, fontName="Arial-Bold", textColor=colors.white)


def inline(t):
    codes = []

    def keep(m):
        codes.append(m.group(1).strip() if m.group(1) is not None else m.group(2))
        return "\x00%d\x00" % (len(codes) - 1)

    t = re.sub(r"``(.+?)``|`([^`]+)`", keep, t)
    s = escape(t)
    s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"(https?://[^\s)<]+)", r'<link href="\1" color="#1f4e79">\1</link>', s)
    return re.sub(r"\x00(\d+)\x00",
                  lambda m: '<font name="Consolas" backColor="#eeeeee">%s</font>' % escape(codes[int(m.group(1))]), s)


def codeblock(text):
    # uma linha de código por linha de tabela, para o bloco poder quebrar
    # entre páginas sem estourar a altura
    rows = [[Preformatted(ln if ln else " ", code)] for ln in text.split("\n")]
    t = Table(rows, colWidths=[A4[0] - 36 * mm - 20], splitByRow=1)
    t.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#f2f2f2")),
                           ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#d0d0d0")),
                           ("LEFTPADDING", (0, 0), (-1, -1), 6),
                           ("TOPPADDING", (0, 0), (-1, -1), 0), ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
                           ("TOPPADDING", (0, 0), (-1, 0), 5), ("BOTTOMPADDING", (0, -1), (-1, -1), 5)]))
    t.hAlign = "LEFT"
    return t


lines = open(SRC, encoding="utf-8").read().splitlines()
story, i = [], 0
while i < len(lines):
    ln = lines[i]
    s = ln.strip()
    if s.startswith("```"):
        buf, i = [], i + 1
        while i < len(lines) and not lines[i].strip().startswith("```"):
            buf.append(lines[i]); i += 1
        ind = min((len(b) - len(b.lstrip()) for b in buf if b.strip()), default=0)
        story.append(codeblock("\n".join(b[ind:] for b in buf)))
        story.append(Spacer(1, 6))
        i += 1; continue
    if not s:
        i += 1; continue
    im = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)$", s)
    if im:
        import os
        from reportlab.platypus import Image as RLImage
        from reportlab.lib.utils import ImageReader
        p = os.path.join(os.path.dirname(os.path.abspath(SRC)), im.group(2))
        iw, ih = ImageReader(p).getSize()
        maxw, maxh = A4[0] - 36 * mm, 120 * mm
        sc = min(maxw / iw, maxh / ih)
        img = RLImage(p, width=iw * sc, height=ih * sc)
        img.hAlign = "LEFT"
        story.append(img)
        story.append(Paragraph("<i>" + escape(im.group(1)) + "</i>", body))
        story.append(Spacer(1, 6))
        i += 1; continue
    if s == "---":
        story.append(HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#bbbbbb"), spaceBefore=6, spaceAfter=6))
        i += 1; continue
    m = re.match(r"^(#{1,4}) (.*)", s)
    if m:
        story.append(Paragraph(inline(m.group(2)), {1: h1, 2: h2, 3: h3, 4: h4}[len(m.group(1))]))
        i += 1; continue
    if s.startswith(">"):
        buf = []
        while i < len(lines) and lines[i].strip().startswith(">"):
            buf.append(lines[i].strip()[1:].strip()); i += 1
        q = Table([[Paragraph(inline(" ".join(buf)), body)]], colWidths=[A4[0] - 36 * mm - 20])
        q.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#eef4fb")),
                               ("LINEBEFORE", (0, 0), (0, -1), 3, ACCENT),
                               ("LEFTPADDING", (0, 0), (-1, -1), 10), ("TOPPADDING", (0, 0), (-1, -1), 6),
                               ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
        q.hAlign = "LEFT"
        story.append(q); story.append(Spacer(1, 6))
        continue
    if s.startswith("|"):
        rows = []
        while i < len(lines) and lines[i].strip().startswith("|"):
            r = [c.strip() for c in lines[i].strip().strip("|").split("|")]
            if not all(re.fullmatch(r":?-{3,}:?", c) for c in r):
                rows.append(r)
            i += 1
        data = [[Paragraph(inline(c), cellh if k == 0 else cell) for c in r] for k, r in enumerate(rows)]
        width = A4[0] - 36 * mm
        ncol = len(rows[0])
        # largura proporcional ao texto médio de cada coluna, com mínimo de 15 %
        avg = [sum(len(r[c]) for r in rows if c < len(r)) / len(rows) + 8 for c in range(ncol)]
        fr = [max(a / sum(avg), 0.19) for a in avg]
        fr = [f / sum(fr) for f in fr]
        t = Table(data, colWidths=[width * f for f in fr], repeatRows=1)
        t.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), ACCENT),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f5f7fa")]),
            ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#c8c8c8")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("TOPPADDING", (0, 0), (-1, -1), 4), ("BOTTOMPADDING", (0, 0), (-1, -1), 4)]))
        story.append(t)
        continue
    lm = re.match(r"^(\d+)\. (.*)", s) or re.match(r"^- (.*)", s)
    if lm:
        numbered = bool(re.match(r"^\d+\. ", s))
        items = []
        while i < len(lines):
            cur = lines[i]
            cm = re.match(r"^(\d+)\. (.*)", cur.strip()) if numbered else re.match(r"^- (.*)", cur.strip())
            if cm and not cur.startswith("   "):
                text = cm.group(2) if numbered else cm.group(1)
                sub, i = [], i + 1
                while i < len(lines) and (lines[i].startswith("   ") or not lines[i].strip()):
                    if not lines[i].strip():
                        nxt = lines[i + 1] if i + 1 < len(lines) else ""
                        if not nxt.startswith("   "):
                            break
                    sub.append(lines[i]); i += 1
                flow = [Paragraph(inline(text), body)]
                j = 0
                while j < len(sub):
                    sl = sub[j].strip()
                    if sl.startswith("```"):
                        buf, j = [], j + 1
                        while j < len(sub) and not sub[j].strip().startswith("```"):
                            buf.append(sub[j]); j += 1
                        ind = min((len(b) - len(b.lstrip()) for b in buf if b.strip()), default=0)
                        flow.append(codeblock("\n".join(b[ind:] for b in buf)))
                        flow.append(Spacer(1, 4))
                    elif sl:
                        flow.append(Paragraph(inline(sl), body))
                    j += 1
                if numbered:
                    items.append(ListItem(flow, leftIndent=14, value=int(cm.group(1))))
                else:
                    items.append(ListItem(flow, leftIndent=14))
            else:
                break
        if numbered:
            lf = ListFlowable(items, bulletType="1", bulletFormat="%s.", leftIndent=16,
                              bulletFontName="Arial-Bold", bulletFontSize=10)
        else:
            lf = ListFlowable(items, bulletType="bullet", start="•", leftIndent=16,
                              bulletFontName="Arial", bulletFontSize=10)
        story.append(lf)
        continue
    para = [s]; i += 1
    while i < len(lines) and lines[i].strip() and not re.match(r"^(#|```|\||- |\d+\. |---)", lines[i].strip()):
        para.append(lines[i].strip()); i += 1
    story.append(Paragraph(inline(" ".join(para)), body))


def footer(c, d):
    c.saveState(); c.setFont("Arial", 8); c.setFillColor(colors.grey)
    c.drawString(18 * mm, 10 * mm, "cv32e40p-asic-flow — " + FOOT)
    c.drawRightString(A4[0] - 18 * mm, 10 * mm, "página %d" % d.page)
    c.restoreState()


doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=16 * mm, bottomMargin=18 * mm,
                        title=FOOT, author="Alanna Santos")
doc.build(story, onFirstPage=footer, onLaterPages=footer)
print("ok", OUT)
