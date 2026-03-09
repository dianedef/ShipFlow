#!/usr/bin/env python3
"""
Codebase MCP Server — Project knowledge + token-saving context management
Features: context memory, smart retrieval, symbol-level reading, token counter, auto-compact recovery
Usage: python3 server.py /path/to/project
"""

import sys
import os
import re
import json
import asyncio
from pathlib import Path
from datetime import datetime, timezone

import mcp.types as types
from mcp.server import Server
from mcp.server.stdio import stdio_server

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

IGNORE_DIRS = {
    "node_modules", ".git", "dist", ".astro", "build", ".next",
    "coverage", "__pycache__", ".cache", "out", ".output", ".vercel",
    ".dual-graph", ".codebase-mcp",
}

TEXT_EXTS = {
    ".astro", ".vue", ".tsx", ".ts", ".jsx", ".js", ".mjs", ".cjs",
    ".md", ".mdx", ".json", ".css", ".scss", ".html", ".py", ".sh",
}

IMPORT_RE = re.compile(
    r"""(?:import\s+.*?\s+from\s+['"]([^'"]+)['"])|"""
    r"""(?:import\s+['"]([^'"]+)['"])|"""
    r"""(?:require\s*\(\s*['"]([^'"]+)['"]\s*\))""",
    re.MULTILINE,
)

STOP_WORDS = {
    "a", "an", "the", "and", "or", "to", "for", "with", "in", "on", "by", "of",
    "please", "can", "could", "would", "should", "will", "use", "update", "fix",
    "make", "show", "this", "that", "it", "is", "are", "was", "be", "do", "how",
}

# Token budget
TURN_READ_BUDGET = 18000
HARD_MAX_READ_CHARS = 4000

# USD per 1M tokens (input pricing — update if Anthropic changes pricing)
MODEL_COSTS = {
    "opus":    {"input": 15.00, "output": 75.00},
    "sonnet":  {"input":  3.00, "output": 15.00},
    "haiku":   {"input":  0.80, "output":  4.00},
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def detect_framework(root: Path) -> str:
    if any((root / f).exists() for f in ["astro.config.mjs", "astro.config.ts", "astro.config.js"]):
        return "astro"
    if any((root / f).exists() for f in ["next.config.js", "next.config.ts", "next.config.mjs"]):
        return "nextjs"
    return "generic"


def walk_files(root: Path, exts: set = None) -> list:
    results = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS]
        for f in filenames:
            p = Path(dirpath) / f
            if exts is None or p.suffix in exts:
                results.append(p)
    return results


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def query_terms(query: str) -> list:
    words = re.findall(r"[A-Za-z0-9_]+", query.lower())
    seen, out = set(), []
    for w in words:
        if len(w) < 3 or w in STOP_WORDS or w in seen:
            continue
        seen.add(w)
        out.append(w)
    return out[:8]


def est_tokens(text: str) -> int:
    return max(1, len(text) // 4)


def excerpt_by_terms(text: str, terms: list, max_chars: int) -> str:
    if not terms:
        return text[:max_chars]
    lines = text.splitlines()
    picks, seen_blocks = [], set()
    for idx, line in enumerate(lines):
        if not any(t in line.lower() for t in terms):
            continue
        start = max(0, idx - 10)
        if start in seen_blocks:
            continue
        seen_blocks.add(start)
        block = "\n".join(lines[start:min(len(lines), idx + 11)])
        picks.append(block)
        if sum(len(x) for x in picks) >= max_chars:
            break
    out = "\n\n/* --- */\n\n".join(picks) if picks else text[:max_chars]
    return out[:max_chars]


# ---------------------------------------------------------------------------
# ① TOKEN COUNTER
# ---------------------------------------------------------------------------

class TokenCounter:
    def __init__(self, data_dir: Path):
        self.log_file = data_dir / "token_log.json"
        self.data_dir = data_dir
        # In-memory session totals
        self.session_input = 0
        self.session_output = 0
        self.session_log = []  # list of {desc, input, output, model, cost, ts}

    def _load_log(self) -> list:
        if not self.log_file.exists():
            return []
        try:
            return json.loads(self.log_file.read_text())
        except Exception:
            return []

    def _save_log(self, entries: list):
        self.data_dir.mkdir(parents=True, exist_ok=True)
        # Keep last 500 entries
        entries = entries[-500:]
        self.log_file.write_text(json.dumps(entries, indent=2))

    def count(self, text: str) -> dict:
        tokens = est_tokens(text)
        costs = {}
        for model, prices in MODEL_COSTS.items():
            costs[model] = f"${tokens / 1_000_000 * prices['input']:.5f}"
        return {
            "chars": len(text),
            "tokens_est": tokens,
            "cost_if_input": costs,
            "tip": "Use context_read instead of Read to get excerpts — much fewer chars/tokens.",
        }

    def log_usage(self, input_tokens: int, output_tokens: int, model: str, description: str) -> dict:
        model_key = model.lower()
        # Fuzzy match: "claude-sonnet-4-6" -> "sonnet"
        for key in MODEL_COSTS:
            if key in model_key:
                model_key = key
                break
        else:
            model_key = "sonnet"  # default

        prices = MODEL_COSTS[model_key]
        cost = (input_tokens / 1_000_000 * prices["input"]) + (output_tokens / 1_000_000 * prices["output"])

        entry = {
            "ts": int(datetime.now(timezone.utc).timestamp()),
            "description": description,
            "model": model_key,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cost_usd": round(cost, 5),
        }
        # Update session totals
        self.session_input += input_tokens
        self.session_output += output_tokens
        self.session_log.append(entry)
        # Persist
        all_entries = self._load_log()
        all_entries.append(entry)
        self._save_log(all_entries)

        return {
            "logged": True,
            "cost_usd": f"${cost:.5f}",
            "session_total_usd": f"${self._session_cost():.4f}",
        }

    def _session_cost(self) -> float:
        total = 0.0
        for e in self.session_log:
            total += e.get("cost_usd", 0)
        return total

    def get_stats(self) -> dict:
        all_entries = self._load_log()
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        today_cost = sum(
            e.get("cost_usd", 0) for e in all_entries
            if datetime.fromtimestamp(e.get("ts", 0), tz=timezone.utc).strftime("%Y-%m-%d") == today
        )
        total_cost = sum(e.get("cost_usd", 0) for e in all_entries)
        by_model = {}
        for e in all_entries:
            m = e.get("model", "?")
            by_model[m] = by_model.get(m, 0) + e.get("cost_usd", 0)

        lines = [
            f"Session: ${self._session_cost():.4f}  ({self.session_input:,} in / {self.session_output:,} out tokens)",
            f"Today:   ${today_cost:.4f}",
            f"All-time: ${total_cost:.4f}  ({len(all_entries)} tasks logged)",
            "",
            "By model:",
        ]
        for model, cost in sorted(by_model.items(), key=lambda x: -x[1]):
            lines.append(f"  {model}: ${cost:.4f}")
        if self.session_log:
            lines.append("\nThis session:")
            for e in self.session_log[-5:]:
                lines.append(f"  ${e['cost_usd']:.5f}  [{e['model']}]  {e['description'][:60]}")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# ② SYMBOL INDEX (for file::symbol notation in context_read)
# ---------------------------------------------------------------------------

# Patterns per language: (regex, group_name_index)
SYMBOL_PATTERNS = {
    "js_ts": [
        re.compile(r'^(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*[\(<]', re.MULTILINE),
        re.compile(r'^(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?(?:\([^)]*\)|[\w]+)\s*=>', re.MULTILINE),
        re.compile(r'^(?:export\s+)?(?:default\s+)?class\s+(\w+)', re.MULTILINE),
        re.compile(r'^\s{2,4}(?:async\s+)?(\w+)\s*\([^)]*\)\s*[:{]', re.MULTILINE),
    ],
    "python": [
        re.compile(r'^(?:async\s+)?def\s+(\w+)\s*\(', re.MULTILINE),
        re.compile(r'^class\s+(\w+)[:(]', re.MULTILINE),
    ],
}

JS_TS_EXTS = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".astro", ".vue"}
PY_EXTS = {".py"}


def extract_symbols(content: str, ext: str) -> dict:
    """Extract {symbol_name: (line_start, line_end)} from file content."""
    symbols = {}
    lines = content.splitlines()

    if ext in JS_TS_EXTS:
        patterns = SYMBOL_PATTERNS["js_ts"]
    elif ext in PY_EXTS:
        patterns = SYMBOL_PATTERNS["python"]
    else:
        return symbols

    # Collect all symbol positions first
    positions = []  # (line_idx, name)
    for pattern in patterns:
        for m in pattern.finditer(content):
            line_idx = content[:m.start()].count("\n")
            name = m.group(1)
            _reserved = {"if","for","while","switch","return","const","let","var","new","async"}
            if name and not name.startswith("_") and len(name) > 2 and name not in _reserved:
                positions.append((line_idx, name))

    positions.sort(key=lambda x: x[0])

    # Assign end lines: next symbol start - 1 (or EOF)
    for i, (line_idx, name) in enumerate(positions):
        end = positions[i + 1][0] - 1 if i + 1 < len(positions) else len(lines) - 1
        end = min(end, line_idx + 80)  # cap at 80 lines per symbol
        if name not in symbols:  # first occurrence wins
            symbols[name] = (line_idx, end)

    return symbols


class SymbolIndex:
    def __init__(self, root: Path):
        self.root = root
        self._cache = {}  # rel_path -> {name: (start, end)}

    def get_symbols(self, file_path: str) -> dict:
        if file_path in self._cache:
            return self._cache[file_path]
        p = self.root / file_path
        if not p.exists():
            return {}
        try:
            content = p.read_text(encoding="utf-8", errors="ignore")
            syms = extract_symbols(content, p.suffix)
            self._cache[file_path] = syms
            return syms
        except Exception:
            return {}

    def list_symbols(self, file_path: str) -> str:
        syms = self.get_symbols(file_path)
        if not syms:
            return f"No symbols found in {file_path}"
        lines = [f"Symbols in {file_path}:"]
        for name, (start, end) in sorted(syms.items(), key=lambda x: x[1][0]):
            lines.append(f"  L{start+1}-{end+1}  {name}")
        lines.append(f"\nUse context_read with '{file_path}::{name}' to read just that symbol.")
        return "\n".join(lines)

    def read_symbol(self, file_path: str, symbol: str, content_lines: list) -> tuple:
        """Returns (excerpt, line_start, line_end) or (None, 0, 0)."""
        syms = self.get_symbols(file_path)
        if symbol not in syms:
            # Fuzzy: case-insensitive partial match
            for name in syms:
                if symbol.lower() in name.lower():
                    symbol = name
                    break
            else:
                return None, 0, 0
        start, end = syms[symbol]
        excerpt = "\n".join(content_lines[start:end + 1])
        return excerpt, start + 1, end + 1


# ---------------------------------------------------------------------------
# Session state
# ---------------------------------------------------------------------------

class SessionState:
    def __init__(self, root: Path):
        self.root = root
        self.data_dir = root / ".codebase-mcp"
        self.action_file = self.data_dir / "action_graph.json"
        self.summary_file = self.data_dir / "session-summary.md"
        # Per-turn
        self.turn_query = ""
        self.turn_used_chars = 0
        self.turn_seen_reads = {}
        self.turn_retrieved_files = []
        # Cross-turn
        self.file_cache = {}

    def reset_turn(self, query: str):
        self.turn_query = query
        self.turn_used_chars = 0
        self.turn_seen_reads = {}
        self.turn_retrieved_files = []

    def load_action_graph(self) -> dict:
        if not self.action_file.exists():
            return {"files": {}, "actions": [], "decisions": []}
        try:
            return json.loads(self.action_file.read_text(encoding="utf-8"))
        except Exception:
            return {"files": {}, "actions": [], "decisions": []}

    def save_action_graph(self, g: dict):
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.action_file.write_text(json.dumps(g, indent=2), encoding="utf-8")

    def record_action(self, kind: str, payload: dict):
        g = self.load_action_graph()
        actions = g.setdefault("actions", [])
        slim = {k: v for k, v in payload.items() if k in ("file", "query", "mode", "files")}
        actions.append({"ts": int(datetime.now(timezone.utc).timestamp()), "kind": kind, **slim})
        if len(actions) > 200:
            del actions[:-200]
        g["actions"] = actions
        self.save_action_graph(g)

    def record_file_read(self, file: str, terms: list, content: str):
        g = self.load_action_graph()
        g.setdefault("files", {})[file] = {
            "query_terms": terms,
            "cached_content": content[:300],
            "cached_chars": len(content),
            "last_action": "read",
            "last_ts": int(datetime.now(timezone.utc).timestamp()),
        }
        self.save_action_graph(g)
        self.file_cache[file] = g["files"][file]

    def record_file_edit(self, file: str):
        g = self.load_action_graph()
        meta = g.setdefault("files", {}).get(file, {})
        meta.update({
            "last_action": "edited",
            "last_ts": int(datetime.now(timezone.utc).timestamp()),
            "edited_count": int(meta.get("edited_count", 0)) + 1,
        })
        meta.pop("cached_content", None)
        g["files"][file] = meta
        self.save_action_graph(g)
        self.file_cache.pop(file, None)

    def record_decision(self, summary: str, files: list):
        g = self.load_action_graph()
        decisions = g.setdefault("decisions", [])
        decisions.append({"ts": int(datetime.now(timezone.utc).timestamp()), "summary": summary, "files": files})
        if len(decisions) > 20:
            del decisions[:-20]
        self.save_action_graph(g)

    # ③ AUTO-COMPACT RECOVERY
    def write_summary(self, task: str, decisions: list, next_steps: list):
        """Write session summary for recovery after /compact."""
        self.data_dir.mkdir(parents=True, exist_ok=True)
        g = self.load_action_graph()
        files_meta = g.get("files", {})
        edited = [f for f, m in files_meta.items() if m.get("last_action") == "edited"]
        read = [f for f, m in files_meta.items() if m.get("last_action") == "read"]

        edited_lines = [f"- {f}" for f in edited] if edited else ["- none"]
        read_lines = [f"- {f}" for f in read[:10]] if read else ["- none"]
        decision_lines = [f"- {d}" for d in decisions] if decisions else ["- none"]
        next_lines = [f"- {s}" for s in next_steps] if next_steps else ["- none"]
        lines = (
            [f"# Session Summary — {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}", "",
             "## Current task", task, "", "## Files edited"]
            + edited_lines
            + ["", "## Files read"]
            + read_lines
            + ["", "## Key decisions"]
            + decision_lines
            + ["", "## Next steps"]
            + next_lines
        )
        self.summary_file.write_text("\n".join(lines), encoding="utf-8")
        return f"Summary saved to {rel(self.summary_file, self.root)}"

    def read_summary(self) -> str:
        """Read session summary for auto-compact recovery."""
        if not self.summary_file.exists():
            return ""
        try:
            return self.summary_file.read_text(encoding="utf-8")
        except Exception:
            return ""


# ---------------------------------------------------------------------------
# File index for smart retrieval
# ---------------------------------------------------------------------------

class FileIndex:
    def __init__(self, root: Path):
        self.root = root
        self.inverted = {}
        self.file_words = {}
        self._built = False

    def build(self):
        if self._built:
            return
        for f in walk_files(self.root, TEXT_EXTS):
            rp = rel(f, self.root)
            try:
                content = f.read_text(errors="ignore")
            except Exception:
                continue
            words = set()
            for part in re.findall(r"[A-Za-z0-9_]+", rp.lower()):
                if len(part) >= 3:
                    words.add(part)
            sample = content[:2000]
            for m in IMPORT_RE.finditer(content):
                imp = m.group(1) or m.group(2) or m.group(3)
                if imp:
                    sample += " " + imp
            for m in re.finditer(r"^#+\s+(.+)$", content, re.MULTILINE):
                sample += " " + m.group(1)
            fm = re.match(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
            if fm:
                sample += " " + fm.group(1)
            for w in re.findall(r"[A-Za-z0-9_]+", sample.lower()):
                if len(w) >= 3 and w not in STOP_WORDS:
                    words.add(w)
            self.file_words[rp] = words
            for w in words:
                self.inverted.setdefault(w, set()).add(rp)
        self._built = True

    def search(self, query: str, limit: int = 10) -> list:
        self.build()
        terms = query_terms(query)
        if not terms:
            return []
        scores = {}
        for term in terms:
            for f in self.inverted.get(term, set()):
                scores[f] = scores.get(f, 0) + 1
        ranked = sorted(scores.items(), key=lambda x: -x[1])
        return [{"file": f, "score": s, "max": len(terms)} for f, s in ranked[:limit]]


# ---------------------------------------------------------------------------
# Project knowledge tools
# ---------------------------------------------------------------------------

def tool_get_structure(root: Path, framework: str) -> str:
    all_files = walk_files(root, TEXT_EXTS)
    by_ext = {}
    for f in all_files:
        by_ext[f.suffix] = by_ext.get(f.suffix, 0) + 1
    lines = [f"Project: {root.name}  |  Framework: {framework}\n", "File counts by type:"]
    for ext, count in sorted(by_ext.items(), key=lambda x: -x[1]):
        lines.append(f"  {ext:8s} {count}")
    dirs = {"astro": ["src/pages","src/components","src/layouts","src/content","src/lib","src/styles","public"],
            "nextjs": ["src/app","app","src/pages","pages","src/components","components","lib","public"]}.get(framework, ["src","lib","components","pages","public"])
    lines.append("\nKey directories:")
    for d in dirs:
        dpath = root / d
        if dpath.exists():
            count = sum(1 for f in dpath.rglob("*") if f.is_file() and f.parent.name not in IGNORE_DIRS)
            lines.append(f"  {d}/  ({count} files)")
    return "\n".join(lines)


def tool_find_file(root: Path, name: str) -> str:
    matches = sorted(rel(f, root) for f in walk_files(root) if name.lower() in f.name.lower())
    return f"{len(matches)} match(es):\n" + "\n".join(matches) if matches else f"No files found matching '{name}'"


def tool_find_usages(root: Path, component: str) -> str:
    results, pattern = [], re.compile(re.escape(component), re.IGNORECASE)
    for f in walk_files(root, TEXT_EXTS):
        try:
            content = f.read_text(errors="ignore")
            if pattern.search(content):
                hits = [f"    L{i}: {l.strip()[:120]}" for i, l in enumerate(content.splitlines(), 1) if pattern.search(l)]
                if hits:
                    results.append(rel(f, root))
                    results.extend(hits[:3])
        except Exception:
            pass
    return f"Usages of '{component}':\n" + "\n".join(results) if results else f"No usages found for '{component}'"


def tool_get_imports(root: Path, file_path: str) -> str:
    p = root / file_path
    if not p.exists():
        matches = [f for f in walk_files(root, TEXT_EXTS) if file_path in str(f)]
        if not matches:
            return f"File not found: {file_path}"
        p = matches[0]
    try:
        content = p.read_text(errors="ignore")
    except Exception as e:
        return f"Error reading file: {e}"
    imports = sorted({m.group(1) or m.group(2) or m.group(3) for m in IMPORT_RE.finditer(content) if m.group(1) or m.group(2) or m.group(3)})
    return f"Imports in {rel(p, root)}:\n" + "\n".join(f"  {i}" for i in imports) if imports else f"No imports found in {file_path}"


def tool_list_pages(root: Path, framework: str) -> str:
    candidates = []
    if framework == "astro":
        d = root / "src" / "pages"
        if d.exists():
            candidates = [rel(f, root) for f in d.rglob("*") if f.is_file() and f.suffix in {".astro",".md",".mdx",".ts",".js"}]
    elif framework == "nextjs":
        for base in ["src/app","app","src/pages","pages"]:
            d = root / base
            if d.exists():
                candidates += [rel(f, root) for f in d.rglob("*") if f.is_file() and f.name in {"page.tsx","page.jsx","page.ts","page.js","index.tsx","index.jsx"}]
    return f"{len(candidates)} pages:\n" + "\n".join(sorted(candidates)) if candidates else "No pages found"


def tool_list_components(root: Path) -> str:
    components = []
    for cd in ["src/components","components","src/ui","ui","src/layouts","layouts"]:
        d = root / cd
        if d.exists():
            components += [rel(f, root) for f in d.rglob("*") if f.is_file() and f.suffix in {".astro",".vue",".tsx",".jsx"}]
    return f"{len(components)} components:\n" + "\n".join(sorted(components)) if components else "No components found"


def tool_list_content(root: Path) -> str:
    content_dir = root / "src" / "content"
    if not content_dir.exists():
        return "No content directory found"
    collections = {}
    for f in content_dir.rglob("*"):
        if f.is_file():
            col = f.parent.name if f.parent != content_dir else "_root"
            collections.setdefault(col, []).append(f.name)
    lines = [f"Content collections ({rel(content_dir, root)}):"]
    for col, files in sorted(collections.items()):
        lines.append(f"\n  {col}/  ({len(files)} files)")
        for fname in sorted(files)[:5]:
            lines.append(f"    {fname}")
        if len(files) > 5:
            lines.append(f"    ... and {len(files)-5} more")
    return "\n".join(lines)


def tool_search_content(root: Path, query: str) -> str:
    content_dir = root / "src" / "content"
    search_dirs = [content_dir] if content_dir.exists() else [root / "src", root / "pages"]
    results, pattern = [], re.compile(re.escape(query), re.IGNORECASE)
    for sd in search_dirs:
        if not sd.exists():
            continue
        for f in sd.rglob("*"):
            if f.is_file() and f.suffix in {".md",".mdx",".astro"}:
                try:
                    content = f.read_text(errors="ignore")
                    if pattern.search(content):
                        for i, line in enumerate(content.splitlines(), 1):
                            if pattern.search(line):
                                results.append(f"{rel(f,root)}  L{i}: {line.strip()[:100]}")
                                break
                except Exception:
                    pass
    return f"{len(results)} matches for '{query}':\n" + "\n".join(results[:50]) if results else f"No results for '{query}'"


# ---------------------------------------------------------------------------
# Context tools
# ---------------------------------------------------------------------------

def tool_context_continue(session: SessionState) -> str:
    terms = query_terms(session.turn_query)
    g = session.load_action_graph()
    files_meta = g.get("files", {})
    decisions = g.get("decisions", [])

    # ③ Auto-compact recovery: show summary if it exists and session seems fresh
    lines = []
    summary = session.read_summary()
    if summary and not files_meta:
        lines.append("⚡ AUTO-COMPACT RECOVERY — previous session context restored:")
        lines.append(summary)
        lines.append("")

    recommended = []
    for file, meta in files_meta.items():
        cached_terms = set(meta.get("query_terms", []))
        overlap = len(set(terms) & cached_terms) if terms else 1
        if terms and overlap <= 0:
            continue
        recommended.append({"file": file, "overlap": overlap,
                             "last_action": meta.get("last_action",""),
                             "cached_chars": meta.get("cached_chars", 0),
                             "preview": meta.get("cached_content","")[:100]})
    recommended.sort(key=lambda x: (-x["overlap"], x["file"]))

    if recommended:
        lines.append(f"Files in memory ({len(recommended)}):")
        for r in recommended[:8]:
            tag = "[EDITED]" if r["last_action"] == "edited" else "[read]"
            lines.append(f"  {tag} {r['file']}  ({r['cached_chars']} chars)")
            if r["preview"]:
                lines.append(f"        {r['preview'][:80]}")
        lines.append("")

    if decisions:
        lines.append(f"Decisions ({len(decisions)}):")
        for d in decisions[-5:]:
            lines.append(f"  - {d.get('summary','')}")
        lines.append("")

    lines.append(f"Turn budget: {TURN_READ_BUDGET - session.turn_used_chars:,} / {TURN_READ_BUDGET:,} chars remaining")

    if not recommended and not decisions and not summary:
        lines.append("Fresh session — use context_retrieve to find relevant files.")

    return "\n".join(lines)


def tool_context_retrieve(index: FileIndex, session: SessionState, query: str, limit: int) -> str:
    results = index.search(query, limit=limit)
    session.turn_retrieved_files = [r["file"] for r in results]
    session.record_action("retrieve", {"query": query})
    if not results:
        return f"No files matched '{query}'"
    lines = [f"Top {len(results)} files for '{query}':"]
    for r in results:
        pct = int(r["score"] / r["max"] * 100) if r["max"] > 0 else 0
        # Show symbol count hint for code files
        lines.append(f"  [{pct:3d}%] {r['file']}")
    lines.append(f"\nTip: use 'file.ts::symbolName' in context_read to read just one function.")
    lines.append(f"Budget remaining: {TURN_READ_BUDGET - session.turn_used_chars:,} chars")
    return "\n".join(lines)


def tool_context_read(root: Path, session: SessionState, sym_index: SymbolIndex,
                      file_ref: str, query: str, max_chars: int) -> str:
    max_chars = min(max_chars or HARD_MAX_READ_CHARS, HARD_MAX_READ_CHARS)
    terms = query_terms(query)

    # Budget
    remaining = TURN_READ_BUDGET - session.turn_used_chars
    if remaining <= 0:
        return f"Turn budget exhausted ({TURN_READ_BUDGET:,} chars). Ask a new question to reset."
    granted = min(max_chars, remaining)

    # Dedup
    dedupe_key = f"{file_ref}|{query}"
    if dedupe_key in session.turn_seen_reads:
        return f"[Already read this turn — preview]\n{session.turn_seen_reads[dedupe_key][:400]}"

    # ② SYMBOL NOTATION: file::symbol
    symbol = None
    file_path = file_ref
    if "::" in file_ref:
        file_path, symbol = file_ref.split("::", 1)

    # Cross-turn cache (only for full files, not symbol reads)
    if not symbol:
        g = session.load_action_graph()
        meta = g.get("files", {}).get(file_path, {})
        if meta and meta.get("cached_content") and set(meta.get("query_terms", [])) & set(terms):
            cached = meta["cached_content"][:granted]
            session.record_action("read_cache_hit", {"file": file_path, "query": query})
            return f"[Cached]\n{file_path}:\n{cached}\n\n({meta.get('cached_chars',0):,} chars total)"

    # Read file
    p = root / file_path
    if not p.exists():
        return f"File not found: {file_path}"
    try:
        text = p.read_text(encoding="utf-8", errors="ignore")
    except Exception as e:
        return f"Error reading {file_path}: {e}"

    content_lines = text.splitlines()

    # Symbol extraction
    if symbol:
        excerpt, line_start, line_end = sym_index.read_symbol(file_path, symbol, content_lines)
        if excerpt is None:
            # Symbol not found — list available symbols
            available = sym_index.list_symbols(file_path)
            return f"Symbol '{symbol}' not found in {file_path}.\n\n{available}"
        text = excerpt
        mode = f"symbol:{symbol} (L{line_start}-{line_end})"
    elif len(text) > granted:
        text = excerpt_by_terms(text, terms, granted) if terms else text[:granted]
        mode = "excerpt" if terms else "head"
    else:
        mode = "full"

    session.turn_used_chars += len(text)
    session.turn_seen_reads[dedupe_key] = text[:200]
    if not symbol:
        session.record_file_read(file_path, terms, text)
    session.record_action("read", {"file": file_ref, "query": query, "mode": mode})

    budget_left = TURN_READ_BUDGET - session.turn_used_chars
    return f"[{mode}] {file_ref} ({len(text):,} chars | budget left: {budget_left:,})\n\n{text}"


def tool_list_symbols(sym_index: SymbolIndex, file_path: str) -> str:
    return sym_index.list_symbols(file_path)


def tool_context_register_edit(session: SessionState, files: list, summary: str) -> str:
    for f in files:
        session.record_file_edit(f)
    if summary:
        session.record_decision(summary, files)
    session.record_action("edit", {"files": files, "summary": summary})
    return f"Registered edit: {', '.join(files)}\nDecision: {summary}\nCache invalidated."


def tool_context_decide(session: SessionState, decision: str, files: list) -> str:
    session.record_decision(decision, files)
    return f"Decision stored: {decision}"


def tool_context_invalidate(session: SessionState, files: list) -> str:
    g = session.load_action_graph()
    cleared = [f for f in files if f in g.get("files", {})]
    for f in cleared:
        g["files"].pop(f)
        session.file_cache.pop(f, None)
    session.save_action_graph(g)
    return f"Invalidated: {', '.join(cleared) if cleared else 'none found'}"


def tool_session_wrap(session: SessionState, task: str, decisions: list, next_steps: list) -> str:
    """③ Save session summary for auto-compact recovery."""
    return session.write_summary(task, decisions, next_steps)


# ---------------------------------------------------------------------------
# MCP tool definitions
# ---------------------------------------------------------------------------

CONTEXT_TOOLS = [
    types.Tool(name="context_continue", description="CALL THIS FIRST every turn. Returns files in memory, decisions, budget, and recovers context after /compact.", inputSchema={"type": "object", "properties": {}}),
    types.Tool(name="context_retrieve", description="Rank project files by relevance BEFORE reading. Use instead of Grep/Glob.", inputSchema={"type": "object", "properties": {"query": {"type": "string"}, "limit": {"type": "integer", "default": 10}}, "required": ["query"]}),
    types.Tool(name="context_read", description="Read a file or symbol with excerpting + budget tracking. Supports file::symbol notation to read just one function. Much cheaper than Read.", inputSchema={"type": "object", "properties": {"file": {"type": "string", "description": "Path or 'path/file.ts::functionName' for symbol-level read"}, "query": {"type": "string", "default": ""}, "max_chars": {"type": "integer", "default": 4000}}, "required": ["file"]}),
    types.Tool(name="list_symbols", description="List all functions/classes in a file. Use to discover symbol names for context_read file::symbol notation.", inputSchema={"type": "object", "properties": {"file_path": {"type": "string"}}, "required": ["file_path"]}),
    types.Tool(name="context_register_edit", description="Register edited files — invalidates cache, stores decision. Call after EVERY edit.", inputSchema={"type": "object", "properties": {"files": {"type": "array", "items": {"type": "string"}}, "summary": {"type": "string", "default": ""}}, "required": ["files"]}),
    types.Tool(name="context_decide", description="Store an architectural decision for cross-session memory.", inputSchema={"type": "object", "properties": {"decision": {"type": "string"}, "files": {"type": "array", "items": {"type": "string"}, "default": []}}, "required": ["decision"]}),
    types.Tool(name="context_invalidate", description="Clear cached context for files when assumptions change.", inputSchema={"type": "object", "properties": {"files": {"type": "array", "items": {"type": "string"}}}, "required": ["files"]}),
    types.Tool(name="session_wrap", description="Save session summary for auto-compact recovery. Call when user says 'done', 'bye', or at natural session end.", inputSchema={"type": "object", "properties": {"task": {"type": "string", "description": "One sentence on what was being worked on"}, "decisions": {"type": "array", "items": {"type": "string"}, "description": "Key decisions made (max 3)", "default": []}, "next_steps": {"type": "array", "items": {"type": "string"}, "description": "What to do next session (max 3)", "default": []}}, "required": ["task"]}),
]

TOKEN_TOOLS = [
    types.Tool(name="count_tokens", description="Estimate token count and USD cost of a text BEFORE reading it. Use to decide if a file is worth reading.", inputSchema={"type": "object", "properties": {"text": {"type": "string", "description": "Text to estimate (paste file content or a path preview)"}}, "required": ["text"]}),
    types.Tool(name="log_usage", description="Log actual token usage after completing a task. Builds running cost history.", inputSchema={"type": "object", "properties": {"input_tokens": {"type": "integer"}, "output_tokens": {"type": "integer"}, "model": {"type": "string", "description": "Model used (opus/sonnet/haiku)", "default": "sonnet"}, "description": {"type": "string", "description": "What was done"}}, "required": ["input_tokens", "output_tokens", "description"]}),
    types.Tool(name="get_session_stats", description="Show running token usage and USD cost for this session and all-time.", inputSchema={"type": "object", "properties": {}}),
]

PROJECT_TOOLS = [
    types.Tool(name="get_structure", description="High-level project structure: framework, file counts, key directories", inputSchema={"type": "object", "properties": {}}),
    types.Tool(name="find_file", description="Find files by name (partial, case-insensitive)", inputSchema={"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}),
    types.Tool(name="find_usages", description="Find all files importing or referencing a component/symbol", inputSchema={"type": "object", "properties": {"component": {"type": "string"}}, "required": ["component"]}),
    types.Tool(name="get_imports", description="List all imports in a file", inputSchema={"type": "object", "properties": {"file_path": {"type": "string"}}, "required": ["file_path"]}),
    types.Tool(name="list_pages", description="List all pages/routes", inputSchema={"type": "object", "properties": {}}),
    types.Tool(name="list_components", description="List all components (Astro, Vue, React)", inputSchema={"type": "object", "properties": {}}),
    types.Tool(name="list_content", description="List Astro content collections", inputSchema={"type": "object", "properties": {}}),
    types.Tool(name="search_content", description="Search text across content/markdown files", inputSchema={"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]}),
]


def main():
    if len(sys.argv) < 2:
        print("Usage: server.py /path/to/project", file=sys.stderr)
        sys.exit(1)

    root = Path(sys.argv[1]).resolve()
    if not root.exists():
        print(f"Project path not found: {root}", file=sys.stderr)
        sys.exit(1)

    framework = detect_framework(root)
    session = SessionState(root)
    index = FileIndex(root)
    sym_index = SymbolIndex(root)
    counter = TokenCounter(session.data_dir)
    app = Server("codebase")

    @app.list_tools()
    async def list_tools() -> list:
        return CONTEXT_TOOLS + TOKEN_TOOLS + PROJECT_TOOLS

    @app.call_tool()
    async def call_tool(name: str, arguments: dict) -> list:
        try:
            # Update turn query on any call if provided
            if arguments.get("query") and name not in ("search_content", "find_usages"):
                session.turn_query = arguments["query"]

            # Context tools
            if name == "context_continue":
                result = tool_context_continue(session)
            elif name == "context_retrieve":
                result = tool_context_retrieve(index, session, arguments["query"], arguments.get("limit", 10))
            elif name == "context_read":
                result = tool_context_read(root, session, sym_index, arguments["file"], arguments.get("query", ""), arguments.get("max_chars", HARD_MAX_READ_CHARS))
            elif name == "list_symbols":
                result = tool_list_symbols(sym_index, arguments["file_path"])
            elif name == "context_register_edit":
                result = tool_context_register_edit(session, arguments["files"], arguments.get("summary", ""))
            elif name == "context_decide":
                result = tool_context_decide(session, arguments["decision"], arguments.get("files", []))
            elif name == "context_invalidate":
                result = tool_context_invalidate(session, arguments["files"])
            elif name == "session_wrap":
                result = tool_session_wrap(session, arguments["task"], arguments.get("decisions", []), arguments.get("next_steps", []))
            # Token tools
            elif name == "count_tokens":
                result = json.dumps(counter.count(arguments["text"]), indent=2)
            elif name == "log_usage":
                result = json.dumps(counter.log_usage(arguments["input_tokens"], arguments["output_tokens"], arguments.get("model", "sonnet"), arguments["description"]), indent=2)
            elif name == "get_session_stats":
                result = counter.get_stats()
            # Project tools
            elif name == "get_structure":
                result = tool_get_structure(root, framework)
            elif name == "find_file":
                result = tool_find_file(root, arguments["name"])
            elif name == "find_usages":
                result = tool_find_usages(root, arguments["component"])
            elif name == "get_imports":
                result = tool_get_imports(root, arguments["file_path"])
            elif name == "list_pages":
                result = tool_list_pages(root, framework)
            elif name == "list_components":
                result = tool_list_components(root)
            elif name == "list_content":
                result = tool_list_content(root)
            elif name == "search_content":
                result = tool_search_content(root, arguments["query"])
            else:
                result = f"Unknown tool: {name}"
        except Exception as e:
            result = f"Error in {name}: {e}"

        return [types.TextContent(type="text", text=result)]

    async def run():
        async with stdio_server() as (read_stream, write_stream):
            await app.run(read_stream, write_stream, app.create_initialization_options())

    asyncio.run(run())


if __name__ == "__main__":
    main()
