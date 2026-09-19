#!/usr/bin/env python3
"""md-bundle：把 repo 的 markdown 打包成 html/content.js，給 html/ 的閱讀器用。

用法（只要 python3，Windows 的 PowerShell 也一樣）：
  python3 bin/md-bundle.py            # 打包全部 md → html/content.js
  python3 bin/md-bundle.py --check    # 掃 md 相對連結與 #錨點，壞的列出並 exit 1（見 md_bundle_check.py）

新增／改動 md 之後只要跑一次 `python3 bin/md-bundle.py`：閱讀器首頁 html/index.html 的分區清單、閱讀器側欄、
全文搜尋全部從 content.js 的 manifest 動態產生，**不用手改任何導航**；`--check` 掃壞連結。
（jpm 使用者可在 project.janet 加 `(phony "bundle" [] (shell "python3 bin/md-bundle.py"))` 變成 `jpm run bundle`。）

為什麼要打包：閱讀器要能用 file:// 直接開，而 Chrome 擋 file:// 的 fetch，執行期讀不到 .md，
所以把原文全塞進一支 JS 讓 <script src> 載入。輸出決定性（路徑排序、無時間戳），產物進 git。
收錄範圍：自動掃 wf/、html/、build/、.claude/ 以外的每支 .md，扣掉 AGENTS.md／CLAUDE.md（給 agent 看的），
不靠任何手寫清單。manifest 每篇：path／section（路徑第一段推）／title（H1）／summary／num（docs 篇號，
從檔名 `NN[a-z]?-` 抽）／readme（是不是 README.md）。排序：README → 沒篇號的索引類 → 篇號自然排序 → 其餘按名稱。
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "html" / "content.js"
SKIP_DIRS = {"wf", "html", "build", ".git", ".claude", "node_modules", "__pycache__"}
SKIP_FILES = {"AGENTS.md", "CLAUDE.md"}
# 區的順序與顯示名；不在表裡的第一層目錄用目錄名當區名
SECTIONS = [("cheatsheets", "cheatsheets 速查表"), ("docs", "docs 教學"), ("reference", "reference 內建全表"), ("reference/spork", "reference/spork"),
            ("modules", "modules 模組"), ("examples", "examples 範例"), ("snippets", "snippets 片段"),
            ("exercises", "exercises 練習"), ("try", "try 試作"), ("", "頂層")]
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})")
H1_RE = re.compile(r"^#\s+(.+?)\s*#*\s*$")
NUM_RE = re.compile(r"^(\d+)([a-z]?)")


def md_files() -> list[str]:
    """repo 相對路徑（/ 分段），排序過。"""
    found: list[str] = []
    for cur, dirs, files in os.walk(ROOT):
        rel = Path(cur).relative_to(ROOT).parts
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        found.extend("/".join(rel + (f,)) for f in files if f.endswith(".md") and f not in SKIP_FILES)
    return sorted(found)


def section_of(path: str) -> str:
    parts = path.split("/")
    if len(parts) == 1:
        return ""
    return "reference/spork" if parts[:2] == ["reference", "spork"] else parts[0]


def sort_key(path: str):
    """區的順序 → 目錄 → README 優先 → 檔名的數字自然排序（01, 01b, 02…）→ 其餘按名稱。"""
    sec = section_of(path)
    sec_idx = next((i for i, (k, _) in enumerate(SECTIONS) if k == sec), len(SECTIONS) - 1)
    parts = path.split("/")
    name = parts[-1]
    m = NUM_RE.match(name)
    num = (1, int(m.group(1)), m.group(2), name) if m else (0, 0, "", name)  # 沒篇號的（索引、路線圖）排篇號前
    return (sec_idx, parts[:-1], 0 if name == "README.md" else 1, num)


def strip_inline(text: str) -> str:
    text = re.sub(r"!?\[([^\]]*)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    return text.replace("`", "").replace("**", "").strip()


def title_and_summary(text: str) -> tuple[str, str]:
    """第一個 H1 當標題；H1 之後第一段像正文的段落（不是導航列／引用／表格／清單）取前 60 字當摘要。"""
    title, summary, fence, seen_h1 = "", "", None, False
    for line in text.splitlines():
        m = FENCE_RE.match(line)
        if m:
            fence = None if fence == m.group(1) else (fence or m.group(1))
            continue
        if fence:
            continue
        h1 = H1_RE.match(line)
        if h1 and not title:
            title, seen_h1 = strip_inline(h1.group(1)), True
            continue
        s = line.strip()
        if summary and s:  # 段落的續行接上去（中文行間不加空白）
            summary += s
        elif summary:
            break
        elif seen_h1 and s and s[0] not in "[>|#-*<" and not s[0].isdigit() and len(strip_inline(s)) >= 12:
            summary = s
    summary = strip_inline(summary)
    summary = summary if len(summary) <= 60 else summary[:60] + "…"
    return title, summary


def build() -> dict:
    files, manifest = {}, []
    for path in sorted(md_files(), key=sort_key):
        text = (ROOT / path).read_text(encoding="utf-8").replace("\r\n", "\n")
        title, summary = title_and_summary(text)
        files[path] = text
        m = NUM_RE.match(path.rsplit("/", 1)[-1])
        manifest.append({"path": path, "section": section_of(path), "title": title or path, "summary": summary,
                         "num": m.group(0) if m else "", "readme": path.endswith("README.md")})
    return {"sections": [{"key": k, "label": v} for k, v in SECTIONS], "manifest": manifest, "files": files}


def write_bundle() -> int:
    data = build()
    body = json.dumps(data, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    body = body.replace("</", "<\\/")  # 內文有 </script> 也不會把外層 <script> 關掉
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("// 由 bin/md-bundle.py 產生，不要手改；改了 md 之後重跑 `python3 bin/md-bundle.py`。\n"
                   f"window.JANET_LAB = {body};\n", encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(ROOT)}：{len(data['manifest'])} 篇，{OUT.stat().st_size:,} bytes")
    return 0


def main(argv: list[str]) -> int:
    if argv == ["--check"]:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from md_bundle_check import check  # noqa: E402
        return check(ROOT, md_files())
    if argv:
        print(__doc__, file=sys.stderr)
        return 2
    return write_bundle()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
