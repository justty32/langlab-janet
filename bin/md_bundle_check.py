"""md_bundle_check：`python3 bin/md-bundle.py --check` 的實作——掃閱讀器收錄的每支 md 裡的相對連結。

檢查兩件事：(1) 目標檔／目錄存在；(2) 帶 #錨點 的連結，錨點在目標 md（依 wf/tools/check_anchors.py
的 github_heading_slug，跟閱讀器 app.js 的 slugify 是同一套規則）或目標 html（id=／name=）裡找得到。
另外掃 html/app.js 首頁固定路線卡片 HOME_CARDS 的 md: '…'（首頁其餘篇目是 manifest 產生的，不會壞）。
跟 wf-lint 互補：wf-lint 不掃 reference/。壞的每條印一行 BROKEN-LINK／BROKEN-ANCHOR，有壞就回 1。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

LINK_RE = re.compile(r"(?<!!)\[[^\]\n]*\]\(([^)\n]+)\)")
IMG_RE = re.compile(r"!\[[^\]\n]*\]\(([^)\n]+)\)")
ID_RE = re.compile(r"""\b(?:id|name)\s*=\s*(['"])(.*?)\1""", re.I)
HOME_MD_RE = re.compile(r"md: '([^']+)'")


def _anchors_tools(root: Path):
    sys.path.insert(0, str(root / "wf" / "tools"))
    import check_anchors  # noqa: E402  wf/tools/check_anchors.py

    return check_anchors


def _links(text: str, ca) -> list[tuple[int, str]]:
    """(行號, 目標) 清單；跳過 fence 與 code span，去掉 "title"。"""
    out, fence = [], None
    for n, line in enumerate(text.splitlines(), 1):
        m = ca.FENCE_RE.match(line)
        if m:
            fence = None if fence == m.group(1) else (fence or m.group(1))
            continue
        if fence:
            continue
        clean = ca.without_code_spans(line)
        for rx in (LINK_RE, IMG_RE):
            for match in rx.finditer(clean):
                target = re.sub(r'\s+"[^"]*"\s*$', "", match.group(1).strip())
                if target and not target.startswith("<"):
                    out.append((n, target))
    return out


def _html_ids(path: Path) -> set[str]:
    return {m.group(2) for m in ID_RE.finditer(path.read_text(encoding="utf-8", errors="replace"))}


def check(root: Path, paths: list[str]) -> int:
    ca = _anchors_tools(root)
    anchors: dict[Path, set[str]] = {}
    bad = 0
    for rel in paths:
        src = root / rel
        for line, target in _links(src.read_text(encoding="utf-8"), ca):
            low = target.lower()
            if low.startswith(("http://", "https://", "mailto:")):
                continue
            path, _, frag = target.partition("#")
            frag = ca.unquote(frag)
            dest = src if not path else (src.parent / ca.unquote(path)).resolve()
            if not dest.exists():
                print(f"BROKEN-LINK {rel}:{line} -> {target}")
                bad += 1
                continue
            if not frag or not dest.is_file():
                continue
            if dest.suffix.lower() == ".md":
                ids = anchors.setdefault(dest, ca.markdown_anchors(dest))
            elif dest.suffix.lower() in (".html", ".htm"):
                ids = anchors.setdefault(dest, _html_ids(dest))
            else:
                continue
            if frag not in ids:
                print(f"BROKEN-ANCHOR {rel}:{line} -> {target}")
                bad += 1
    app = root / "html" / "app.js"
    for md in HOME_MD_RE.findall(app.read_text(encoding="utf-8")) if app.exists() else []:
        if md not in paths:
            print(f"BROKEN-LINK html/app.js HOME_CARDS -> {md}（不在 bundle 裡）")
            bad += 1
    print(f"--check：{len(paths)} 篇，{bad} 條壞連結")
    return 1 if bad else 0
