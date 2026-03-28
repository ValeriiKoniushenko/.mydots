#!/usr/bin/env python3

import subprocess
import json
import urllib.request
import sys
import argparse

MODEL = "qwen2.5-coder:7b"
FINAL_CONTEXT = 1024 * 48
PER_FILE_CONTEXT = 1024 * 16
CHARS_PER_FILE = 20
TEMPERATURE = 0.4
KEEP_ALIVE = "5m"

def get_repo_root():
    return subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], stderr=subprocess.DEVNULL
    ).decode().strip()

def get_diff(files=None):
    root = get_repo_root()
    cmd = ["git", "diff", "--cached", "--diff-filter=ACMRT"]
    if files:
        cmd += ["--"] + files
    diff = subprocess.check_output(cmd, cwd=root).decode()
    if not diff:
        cmd = ["git", "diff", "--diff-filter=ACMRT"]
        if files:
            cmd += ["--"] + files
        diff = subprocess.check_output(cmd, cwd=root).decode()
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

def ollama(prompt, num_ctx):
    payload = json.dumps({
        "model": MODEL,
        "keep_alive": KEEP_ALIVE,
        "stream": False,
        "options": {"num_ctx": num_ctx, "temperature": TEMPERATURE},
        "prompt": prompt
    }).encode()

    req = urllib.request.Request(
        "http://localhost:11434/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["response"]

def summarize_file(filepath, diff):
    prompt = f"""Summarize what changed in this file diff in 2-3 sentences.
Plain text only, no markdown, no bullet points.
Be specific: mention function/class names that changed and why.

File: {filepath}

Diff:
{diff}"""
    return ollama(prompt, PER_FILE_CONTEXT)

def generate_commit_message(summaries, number_files):
    summary_text = "\n".join(f"- {f}: {s}" for f, s in summaries)
    prompt = f"""You are an expert software engineer writing git commit messages.

Based on these per-file change summaries, write a single cohesive commit message.

FORMAT (follow exactly):
<type>(<scope>): <what changed and why, be specific>

<body>

RULES:
- NO markdown!
- Subject line: max {min(CHARS_PER_FILE*number_files, 1000)} chars
- Body: 1-2 sentences, explain WHY not just WHAT. Bullet points.
- Mention actual function/class names involved
- Do NOT write 'This commit...'
- Output ONLY the commit message, zero extra text

Per-file summaries:
{summary_text}"""
    return ollama(prompt, FINAL_CONTEXT)

def validate():
    errors = []

    # Python modules
    for module in ["subprocess", "json", "urllib.request", "argparse"]:
        try:
            __import__(module)
        except ImportError:
            errors.append(f"Missing module: {module}")

    # git available
    try:
        subprocess.check_output(["git", "--version"], stderr=subprocess.DEVNULL)
    except FileNotFoundError:
        errors.append("git not found in PATH")

    # inside a git repo
    try:
        subprocess.check_output(["git", "rev-parse", "--git-dir"], stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        errors.append("Not inside a git repository")

    # ollama port reachable
    try:
        urllib.request.urlopen("http://localhost:11434", timeout=3)
    except urllib.error.URLError as e:
        errors.append(f"Ollama not reachable at localhost:11434: {e.reason}")

    # model available
    try:
        with urllib.request.urlopen("http://localhost:11434/api/tags", timeout=5) as r:
            data = json.loads(r.read())
            model_names = [m["name"] for m in data.get("models", [])]
            matches = [m for m in model_names if m == MODEL or m.startswith(MODEL + ":")]
            if not matches:
                errors.append(f"Model '{MODEL}' not found in ollama. Available: {', '.join(model_names) or 'none'}")
    except Exception as e:
        errors.append(f"Failed to query ollama models: {e}")

    if errors:
        print("Validation failed:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)

if __name__ == "__main__":
    validate()

    parser = argparse.ArgumentParser()
    parser.add_argument("--silent", action="store_true")
    args = parser.parse_args()

    files = get_changed_files()
    if not files:
        if not args.silent:
            print("No staged changes.")
        sys.exit(1)

    if not args.silent:
        print(f"Summarizing {len(files)} file(s)...\n")

    summaries = []
    for i, f in enumerate(files):
        diff = get_diff([f])
        if not diff:
            continue
        if not args.silent:
            pct = int((i + 1) / len(files) * 100)
            print(f"  [{pct}%]: {f}")
        summary = summarize_file(f, diff)
        summaries.append((f, summary))

    if not summaries:
        if not args.silent:
            print("Nothing to summarize.")
        sys.exit(1)

    if not args.silent:
        print("\nGenerating commit message...\n")
    print(generate_commit_message(summaries, len(files)))
