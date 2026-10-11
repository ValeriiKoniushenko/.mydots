#!/usr/bin/env python3
"""
Generate a git commit message with a local Ollama model.

stdout  -> ONLY the commit message (safe to use in hooks / pipes)
stderr  -> progress, live token stream stats, resource report

Context strategy:
  * ONE fixed num_ctx (NUM_CTX / --ctx) for every request -> the model is loaded
    once and the KV cache size never changes.
  * The whole file diff goes into one request if it fits the token budget.
  * Too big? 1) retry with fewer diff context lines (-U1)
             2) split by hunks into chunks, summarize each (map),
                then merge the chunk summaries (reduce).
  * The final step also reduces in groups if the summaries don't fit.

Optional: `pip install psutil` for CPU/RAM sampling of the ollama process.
"""

import argparse
import fnmatch
import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field

try:
    import psutil
except ImportError:
    psutil = None

OLLAMA_URL = "http://localhost:11434"
MODEL = "qwen2.5-coder:7b"
NUM_CTX = 1024 * 16        # one context for ALL calls (override with --ctx)
MAX_OUT_RESERVED = 1024    # tokens kept free for the answer when budgeting input
PROMPT_OVERHEAD = 400      # tokens reserved for template text + chat template
SAFETY = 1.15              # token estimate safety margin
CHARS_PER_FILE = 200
TEMPERATURE = 0.4
KEEP_ALIVE = "5m"
UNIFIED = "auto"           # git diff context lines: "auto" or a number (--unified)
UNIFIED_STEPS = [1000, 400, 200, 100, 50, 25, 10, 5, 3]  # tried in this order by "auto"

IS_TTY = sys.stderr.isatty()


# --------------------------------------------------------------------------
# Output helpers (everything except the final message goes to stderr)
# --------------------------------------------------------------------------

def log(msg="", end="\n"):
    print(msg, file=sys.stderr, end=end, flush=True)


def fmt_dur(seconds):
    if seconds < 60:
        return f"{seconds:.1f}s"
    m, s = divmod(seconds, 60)
    return f"{int(m)}m{s:04.1f}s"


def fmt_bytes(n):
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024


def bar(frac, width=20):
    frac = max(0.0, min(1.0, frac))
    filled = int(round(frac * width))
    return "[" + "#" * filled + "." * (width - filled) + "]"


# --------------------------------------------------------------------------
# Token estimation (self-calibrating from real Ollama token counts)
# --------------------------------------------------------------------------

class TokenEstimator:
    def __init__(self):
        self.cpt = 3.0  # chars per token; conservative start for code

    def update(self, chars, tokens):
        if tokens > 0 and chars > 0:
            ratio = chars / tokens
            self.cpt = max(1.5, 0.5 * self.cpt + 0.5 * ratio)


EST = TokenEstimator()


def max_input_chars():
    tokens = NUM_CTX - MAX_OUT_RESERVED - PROMPT_OVERHEAD
    return max(1000, int(tokens * EST.cpt / SAFETY))


# --------------------------------------------------------------------------
# Stats
# --------------------------------------------------------------------------

@dataclass
class CallStats:
    label: str
    num_ctx: int
    prompt_chars: int = 0
    prompt_tokens: int = 0
    gen_tokens: int = 0
    load_s: float = 0.0
    prompt_s: float = 0.0
    gen_s: float = 0.0
    total_s: float = 0.0
    wall_s: float = 0.0
    truncated: bool = False

    @property
    def used_tokens(self):
        return self.prompt_tokens + self.gen_tokens

    @property
    def ctx_frac(self):
        return self.used_tokens / self.num_ctx if self.num_ctx else 0.0

    @property
    def gen_tps(self):
        return self.gen_tokens / self.gen_s if self.gen_s > 0 else 0.0

    @property
    def prompt_tps(self):
        return self.prompt_tokens / self.prompt_s if self.prompt_s > 0 else 0.0


@dataclass
class Session:
    calls: list = field(default_factory=list)


SESSION = Session()


class ResourceSampler(threading.Thread):
    """Samples CPU/RAM of all processes with 'ollama' in the name."""

    def __init__(self, interval=0.5):
        super().__init__(daemon=True)
        self.interval = interval
        self.stop_evt = threading.Event()
        self.procs = {}
        self.peak_rss = 0
        self.peak_cpu = 0.0
        self.cpu_sum = 0.0
        self.samples = 0

    def _refresh(self):
        for p in psutil.process_iter(["name"]):
            try:
                if "ollama" in (p.info["name"] or "").lower() and p.pid not in self.procs:
                    p.cpu_percent(None)  # prime
                    self.procs[p.pid] = p
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

    def run(self):
        while not self.stop_evt.wait(self.interval):
            self._refresh()
            rss, cpu = 0, 0.0
            for pid, p in list(self.procs.items()):
                try:
                    rss += p.memory_info().rss
                    cpu += p.cpu_percent(None)
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    self.procs.pop(pid, None)
            self.peak_rss = max(self.peak_rss, rss)
            self.peak_cpu = max(self.peak_cpu, cpu)
            self.cpu_sum += cpu
            self.samples += 1

    def stop(self):
        self.stop_evt.set()

    @property
    def avg_cpu(self):
        return self.cpu_sum / self.samples if self.samples else 0.0


# --------------------------------------------------------------------------
# Git / .aiignore
# --------------------------------------------------------------------------

def get_repo_root():
    return subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], stderr=subprocess.DEVNULL
    ).decode().strip()


def load_aiignore(root):
    """
    Load patterns from <repo_root>/.aiignore.
    Lines starting with '#' and empty lines are ignored. A leading '!'
    negates the pattern (gitignore-like).
    """
    path = os.path.join(root, ".aiignore")
    if not os.path.exists(path):
        return []
    patterns = []
    with open(path) as f:
        for line in f:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            patterns.append(line.rstrip())
    return patterns


def is_ignored(filepath, patterns):
    """Last matching pattern wins; '!' re-includes; no '/' => basename match."""
    result = False
    for raw in patterns:
        negate = raw.startswith("!")
        pattern = (raw[1:] if negate else raw).lstrip("/")

        if "/" in pattern:
            matched = fnmatch.fnmatch(filepath, pattern) or \
                      fnmatch.fnmatch(filepath, "**/" + pattern)
        else:
            matched = fnmatch.fnmatch(os.path.basename(filepath), pattern)

        if matched:
            result = not negate
    return result


def get_diff(files=None, unified=None):
    root = get_repo_root()
    extra = [f"-U{unified}"] if unified is not None else []

    cmd = ["git", "diff", "--cached", "--diff-filter=ACMRT"] + extra
    if files:
        cmd += ["--"] + files
    diff = subprocess.check_output(cmd, cwd=root).decode(errors="replace")
    if not diff:
        cmd = ["git", "diff", "--diff-filter=ACMRT"] + extra
        if files:
            cmd += ["--"] + files
        diff = subprocess.check_output(cmd, cwd=root).decode(errors="replace")
    return diff


def get_changed_files():
    root = get_repo_root()
    files = subprocess.check_output(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMRT"], cwd=root
    ).decode().splitlines()
    if not files:
        files = subprocess.check_output(
            ["git", "diff", "--name-only", "--diff-filter=ACMRT"], cwd=root
        ).decode().splitlines()
    return files


# --------------------------------------------------------------------------
# Diff splitting (map step)
# --------------------------------------------------------------------------

def split_text(text, budget):
    """Split text into pieces <= budget chars, on line boundaries when possible."""
    pieces, cur, size = [], [], 0
    for line in text.splitlines(keepends=True):
        while len(line) > budget:  # one absurdly long line (minified file etc.)
            if cur:
                pieces.append("".join(cur))
                cur, size = [], 0
            pieces.append(line[:budget])
            line = line[budget:]
        if cur and size + len(line) > budget:
            pieces.append("".join(cur))
            cur, size = [], 0
        cur.append(line)
        size += len(line)
    if cur:
        pieces.append("".join(cur))
    return pieces


def split_diff(diff, max_chars):
    """
    Split a single-file diff into chunks <= max_chars. Each chunk starts with the
    file header (diff --git / index / ---/+++), hunks are kept whole where possible.
    """
    if len(diff) <= max_chars:
        return [diff]

    lines = diff.splitlines(keepends=True)
    first_hunk = next((i for i, l in enumerate(lines) if l.startswith("@@")), None)

    if first_hunk is None:  # binary / mode change / odd diff: split blindly
        return split_text(diff, max_chars)

    header = "".join(lines[:first_hunk])
    hunks, cur = [], []
    for l in lines[first_hunk:]:
        if l.startswith("@@") and cur:
            hunks.append("".join(cur))
            cur = []
        cur.append(l)
    if cur:
        hunks.append("".join(cur))

    budget = max(500, max_chars - len(header))
    pieces = []
    for h in hunks:
        pieces.extend(split_text(h, budget) if len(h) > budget else [h])

    chunks, cur, size = [], [], 0
    for p in pieces:
        if cur and size + len(p) > budget:
            chunks.append(header + "".join(cur))
            cur, size = [], 0
        cur.append(p)
        size += len(p)
    if cur:
        chunks.append(header + "".join(cur))
    return chunks


# --------------------------------------------------------------------------
# Ollama
# --------------------------------------------------------------------------

def ollama(prompt, label, max_out, silent=False):
    """Streams the response, shows live progress, records stats."""
    payload = json.dumps({
        "model": MODEL,
        "keep_alive": KEEP_ALIVE,
        "stream": True,
        "options": {
            "num_ctx": NUM_CTX,
            "num_predict": max_out,
            "temperature": TEMPERATURE,
        },
        "prompt": prompt,
    }).encode()

    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )

    stats = CallStats(label=label, num_ctx=NUM_CTX, prompt_chars=len(prompt))
    parts = []
    gen_chunks = 0
    t0 = time.monotonic()
    first_token_at = None

    def progress_line():
        now = time.monotonic()
        if first_token_at is None:
            return f"    waiting for first token (load + prompt processing)... {fmt_dur(now - t0)}"
        dt = now - first_token_at
        tps = gen_chunks / dt if dt > 0 else 0.0
        return f"    generating: ~{gen_chunks} tok | {tps:.1f} tok/s | {fmt_dur(now - t0)}"

    last_draw = 0.0
    with urllib.request.urlopen(req) as r:
        for raw in r:
            if not raw.strip():
                continue
            chunk = json.loads(raw)
            piece = chunk.get("response", "")
            if piece:
                if first_token_at is None:
                    first_token_at = time.monotonic()
                parts.append(piece)
                gen_chunks += 1

            if not silent and IS_TTY:
                now = time.monotonic()
                if now - last_draw > 0.1:
                    log("\r" + progress_line() + "\033[K", end="")
                    last_draw = now

            if chunk.get("done"):
                stats.prompt_tokens = chunk.get("prompt_eval_count", 0)
                stats.gen_tokens = chunk.get("eval_count", 0)
                stats.load_s = chunk.get("load_duration", 0) / 1e9
                stats.prompt_s = chunk.get("prompt_eval_duration", 0) / 1e9
                stats.gen_s = chunk.get("eval_duration", 0) / 1e9
                stats.total_s = chunk.get("total_duration", 0) / 1e9

    stats.wall_s = time.monotonic() - t0
    # When the prompt doesn't fit, Ollama silently truncates it.
    stats.truncated = stats.prompt_tokens >= NUM_CTX - 1
    if not stats.truncated:
        EST.update(len(prompt), stats.prompt_tokens)

    if not silent and IS_TTY:
        log("\r\033[K", end="")

    SESSION.calls.append(stats)
    return "".join(parts).strip(), stats


def call_llm(prompt, label, max_out, silent):
    text, st = ollama(prompt, label, max_out, silent)
    if not silent:
        print_call_line(st)
    return text


def get_model_runtime_info():
    """Ask Ollama what is currently loaded (size, VRAM share, ctx)."""
    try:
        with urllib.request.urlopen(f"{OLLAMA_URL}/api/ps", timeout=3) as r:
            data = json.loads(r.read())
        for m in data.get("models", []):
            if m.get("name", "").startswith(MODEL.split(":")[0]):
                return m
    except Exception:
        pass
    return None


# --------------------------------------------------------------------------
# Prompts + map/reduce
# --------------------------------------------------------------------------

def summary_prompt(filepath, diff, part=None):
    part_note = f" (part {part[0]} of {part[1]} of a large diff)" if part else ""
    return f"""Summarize what changed in this file diff in 2-3 sentences.
Plain text only, no markdown, no bullet points.
Be specific: mention function/class names that changed and why.
Only lines starting with + or - are changes. Other lines are unchanged
surrounding code, given only to help you understand the changes.

File: {filepath}{part_note}

Diff:
{diff}"""


def merge_prompt(parts):
    text = "\n".join(f"- {p}" for p in parts)
    return f"""Below are partial notes about code changes (same file or related files).
Combine them into 2-4 sentences of plain text. Plain text only, no markdown,
no bullet points. Keep file names and function/class names. Do not invent anything.

Notes:
{text}"""


def shrink(parts, label, silent, reserve_chars=0):
    """
    Reduce a list of text parts until their joined size fits the input budget.
    Parts are grouped greedily, each group is merged by the LLM into one part.
    """
    limit = max_input_chars() - reserve_chars
    level = 0
    while sum(len(p) + 3 for p in parts) > limit and len(parts) > 1:
        level += 1
        groups, cur, size = [], [], 0
        for p in parts:
            if cur and size + len(p) + 3 > limit:
                groups.append(cur)
                cur, size = [], 0
            cur.append(p)
            size += len(p) + 3
        if cur:
            groups.append(cur)
        if len(groups) >= len(parts):  # no progress possible
            break

        if not silent:
            log(f"  {label}: parts too large, merging {len(parts)} -> {len(groups)} (level {level})")
        merged = []
        for gi, g in enumerate(groups, 1):
            if len(g) == 1:
                merged.append(g[0])
            else:
                merged.append(call_llm(merge_prompt(g), f"{label} L{level} g{gi}/{len(groups)}", 400, silent))
        parts = merged
    return parts


def fit_diff(filepath, limit, silent):
    """
    Pick the diff with the most surrounding context that still fits `limit` chars.
    "auto": try the largest -U<N> first (U1000 is basically the whole file) and
    go down until it fits. If even -U3 is too big, try -U1; if that is still too
    big the caller will chunk it.
    """
    if UNIFIED != "auto":
        return get_diff([filepath], unified=int(UNIFIED))

    base = get_diff([filepath], unified=3)
    if not base:
        return ""

    for u in UNIFIED_STEPS:
        d = get_diff([filepath], unified=u)
        if d and len(d) <= limit:
            if not silent:
                log(f"  diff context -U{u}: {len(d)} chars ({len(d) * 100 // limit}% of input budget)")
            return d

    small = get_diff([filepath], unified=1)
    best = small if small and len(small) < len(base) else base
    if not silent:
        log(f"  diff too big even with -U3 ({len(base)} > {limit} chars); "
            f"using {len(best)} chars and chunking if needed")
    return best


def summarize_file(filepath, silent):
    limit = max_input_chars()
    diff = fit_diff(filepath, limit, silent)
    if not diff:
        return None, 0
    n_chars = len(diff)

    chunks = split_diff(diff, limit)

    if len(chunks) == 1:
        return call_llm(summary_prompt(filepath, chunks[0]), f"summary:{filepath}", 400, silent), n_chars

    if not silent:
        log(f"  still {len(diff)} chars > {limit}: splitting into {len(chunks)} chunks (map-reduce)")
    partials = []
    for i, c in enumerate(chunks, 1):
        if not silent:
            log(f"  chunk {i}/{len(chunks)} ({len(c)} chars)")
        partials.append(call_llm(
            summary_prompt(filepath, c, part=(i, len(chunks))),
            f"chunk:{filepath} ({i}/{len(chunks)})", 400, silent))

    partials = shrink(partials, f"merge:{filepath}", silent)
    if len(partials) == 1:
        return partials[0], n_chars
    return call_llm(merge_prompt(partials), f"merge:{filepath}", 400, silent), n_chars


def generate_commit_message(summaries, number_files, silent):
    lines = [f"{f}: {s}" for f, s in summaries]
    reserve = 1500  # the template text of the final prompt
    lines = shrink(lines, "reduce", silent, reserve_chars=reserve)
    summary_text = "\n".join(f"- {l}" for l in lines)

    prompt = f"""You are an expert software engineer writing git commit messages.

Based on these per-file change summaries, write a single cohesive commit message.

FORMAT (follow exactly):
<type>(<scope>): <what changed and why, be specific>

<body>

RULES:
- NO markdown!
- Subject line: max {min(CHARS_PER_FILE * number_files, 600)} chars
- Body: 1 sentence: explain WHY not just WHAT. Bullet points.
- Mention actual function/class names involved
- Do NOT write 'This commit...'
- Output ONLY the commit message, zero extra text
- THE MOST IMPORTANT: be brief and clear

Per-file summaries:
{summary_text}"""
    return call_llm(prompt, "final", 1024, silent)


# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------

def validate():
    errors = []

    try:
        subprocess.check_output(["git", "--version"], stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        errors.append("git not found in PATH")

    try:
        subprocess.check_output(["git", "rev-parse", "--git-dir"], stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError):
        errors.append("Not inside a git repository")

    try:
        with urllib.request.urlopen(f"{OLLAMA_URL}/api/tags", timeout=5) as r:
            data = json.loads(r.read())
        names = [m["name"] for m in data.get("models", [])]
        if not any(n == MODEL or n.startswith(MODEL + ":") for n in names):
            errors.append(f"Model '{MODEL}' not found in ollama. Available: {', '.join(names) or 'none'}")
    except urllib.error.URLError as e:
        errors.append(f"Ollama not reachable at {OLLAMA_URL}: {e.reason}")
    except Exception as e:
        errors.append(f"Failed to query ollama models: {e}")

    if errors:
        log("Validation failed:")
        for e in errors:
            log(f"  - {e}")
        sys.exit(1)


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------

def print_call_line(s, prefix="    "):
    warn = "  !! PROMPT TRUNCATED (lower input or raise --ctx)" if s.truncated else ""
    reload = f" | model load {fmt_dur(s.load_s)}" if s.load_s > 0.5 else ""
    log(
        f"{prefix}ctx {s.used_tokens}/{s.num_ctx} {bar(s.ctx_frac)} {s.ctx_frac * 100:.0f}%"
        f" | in {s.prompt_tokens} tok ({s.prompt_tps:.0f} tok/s)"
        f" | out {s.gen_tokens} tok ({s.gen_tps:.1f} tok/s)"
        f" | {fmt_dur(s.wall_s)}{reload}{warn}"
    )


def print_report(sampler, total_wall):
    calls = SESSION.calls
    if not calls:
        return
    body_calls = [c for c in calls if c.label != "final"]
    final = next((c for c in calls if c.label == "final"), None)

    log("\n" + "=" * 78)
    log("RESOURCE REPORT")
    log("=" * 78)
    log(f"Model: {MODEL} | num_ctx {NUM_CTX} | temperature {TEMPERATURE} | keep_alive {KEEP_ALIVE}")
    log(f"Estimated chars/token (calibrated): {EST.cpt:.2f} | input budget: {max_input_chars()} chars")

    if body_calls:
        log(f"\nSummarization calls ({len(body_calls)}):")
        log(f"  {'call':<46} {'in tok':>7} {'out tok':>8} {'ctx%':>5} {'time':>8}")
        for c in body_calls:
            name = c.label
            if len(name) > 46:
                name = "..." + name[-43:]
            mark = " !" if c.truncated else ""
            log(f"  {name:<46} {c.prompt_tokens:>7} {c.gen_tokens:>8} "
                f"{c.ctx_frac * 100:>4.0f}% {fmt_dur(c.wall_s):>8}{mark}")
        peak = max(body_calls, key=lambda c: c.ctx_frac)
        log(f"  peak context: {peak.used_tokens}/{peak.num_ctx} ({peak.ctx_frac * 100:.0f}%) -> {peak.label}")

    if final:
        log("\nFinal commit message call:")
        print_call_line(final, prefix="  ")

    tot_in = sum(c.prompt_tokens for c in calls)
    tot_out = sum(c.gen_tokens for c in calls)
    tot_gen_s = sum(c.gen_s for c in calls)
    tot_prompt_s = sum(c.prompt_s for c in calls)
    tot_load_s = sum(c.load_s for c in calls)
    loads = sum(1 for c in calls if c.load_s > 0.5)

    log("\nTotals:")
    log(f"  LLM calls           : {len(calls)}")
    log(f"  Tokens in / out     : {tot_in} / {tot_out}  (sum {tot_in + tot_out})")
    if tot_gen_s and tot_prompt_s:
        log(f"  Avg speed           : prompt {tot_in / tot_prompt_s:.0f} tok/s, "
            f"generation {tot_out / tot_gen_s:.1f} tok/s")
    log(f"  Time split          : load {fmt_dur(tot_load_s)} | prompt {fmt_dur(tot_prompt_s)} "
        f"| generation {fmt_dur(tot_gen_s)}")
    log(f"  Wall time           : {fmt_dur(total_wall)}")
    if loads > 1:
        log(f"  Note: model was loaded {loads}x (expected 1 with a single num_ctx).")
    if any(c.truncated for c in calls):
        log("  WARNING: at least one prompt hit the context limit and was truncated.")

    info = get_model_runtime_info()
    if info:
        size = info.get("size", 0)
        vram = info.get("size_vram", 0)
        gpu_pct = (vram / size * 100) if size else 0
        log("\nModel in memory (ollama /api/ps):")
        log(f"  Total size          : {fmt_bytes(size)}")
        log(f"  On GPU / VRAM       : {fmt_bytes(vram)} ({gpu_pct:.0f}%)"
            f"{'  <- CPU-only' if vram == 0 else ''}")
        if "context_length" in info:
            log(f"  Context length      : {info['context_length']}")
        if size and vram and gpu_pct < 99:
            log(f"  Tip: not fully on GPU. Lower --ctx, or run ollama with "
                f"OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0 to fit a bigger context.")
        elif size and gpu_pct >= 99:
            log(f"  Tip: 100% on GPU; you may have room to raise --ctx (model max is usually 32768).")

    if sampler and sampler.samples:
        log("\nOllama process (psutil sampling):")
        log(f"  Peak RAM (RSS)      : {fmt_bytes(sampler.peak_rss)}")
        log(f"  CPU avg / peak      : {sampler.avg_cpu:.0f}% / {sampler.peak_cpu:.0f}% "
            f"(100% = one core)")
    elif psutil is None:
        log("\n(install psutil for CPU/RAM stats: pip install psutil)")

    log("=" * 78 + "\n")


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main():
    global NUM_CTX, UNIFIED

    parser = argparse.ArgumentParser(description="Generate a commit message with a local LLM.")
    parser.add_argument("--silent", action="store_true", help="no progress / report output")
    parser.add_argument("--no-report", action="store_true", help="skip the final resource report")
    parser.add_argument("--ctx", type=int, default=NUM_CTX,
                        help=f"context size used for every request (default {NUM_CTX})")
    parser.add_argument("--unified", default=UNIFIED, metavar="N|auto",
                        help="git diff context lines per hunk: a number, or 'auto' = the "
                             "largest that fits the input budget (default auto)")
    args = parser.parse_args()
    silent = args.silent
    NUM_CTX = args.ctx
    if str(args.unified).lower() != "auto" and not str(args.unified).isdigit():
        parser.error("--unified must be a number or 'auto'")
    UNIFIED = "auto" if str(args.unified).lower() == "auto" else int(args.unified)

    validate()

    started = time.monotonic()
    root = get_repo_root()
    patterns = load_aiignore(root)

    files = get_changed_files()
    if not files:
        if not silent:
            log("No staged changes.")
        sys.exit(1)

    if patterns:
        before = len(files)
        files = [f for f in files if not is_ignored(f, patterns)]
        skipped = before - len(files)
        if skipped and not silent:
            log(f"Skipped {skipped} file(s) matched by .aiignore\n")

    if not files:
        if not silent:
            log("All changed files are excluded by .aiignore.")
        sys.exit(1)

    if not silent:
        log(f"Summarizing {len(files)} file(s) with {MODEL} (num_ctx {NUM_CTX}, "
            f"input budget ~{max_input_chars()} chars)...\n")

    sampler = None
    if psutil and not silent:
        sampler = ResourceSampler()
        sampler.start()

    summaries = []
    file_times = []
    try:
        for i, f in enumerate(files, 1):
            t_file = time.monotonic()
            if not silent:
                pct = int((i - 1) / len(files) * 100)
                eta = ""
                if file_times:
                    avg = sum(file_times) / len(file_times)
                    eta = f" | ETA ~{fmt_dur(avg * (len(files) - i + 1))}"
                log(f"[{i}/{len(files)}] {pct}% {f}{eta}")

            summary, n_chars = summarize_file(f, silent)
            if summary is None:
                continue
            summaries.append((f, summary))
            file_times.append(time.monotonic() - t_file)

        if not summaries:
            if not silent:
                log("Nothing to summarize.")
            sys.exit(1)

        if not silent:
            log("\nGenerating final commit message...")
        message = generate_commit_message(summaries, len(files), silent)
    finally:
        if sampler:
            sampler.stop()

    if not silent and not args.no_report:
        print_report(sampler, time.monotonic() - started)

    print(message)  # the only thing on stdout


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("\nInterrupted.")
        sys.exit(130)