#!/usr/bin/env python3
"""Tick, untick or toggle checkboxes in TODO.md by line number.

Usage (run from anywhere):
  scripts/todo_check.py list [open|done|all] [text]   # show checkboxes with line numbers
  scripts/todo_check.py check  N [N ...]              # mark [x]
  scripts/todo_check.py uncheck N [N ...]             # mark [ ]
  scripts/todo_check.py toggle N [N ...]              # flip

Only the `[ ]` / `[x]` marker on the given line changes; nothing else is touched.
Use --file PATH to edit a different markdown file.
"""
import argparse
import os
import re
import sys

BOX = re.compile(r'^(\s*[-*+]\s*\[)([ xX])(\].*)$')
DEFAULT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'TODO.md')


def load(path):
    with open(path, encoding='utf-8', newline='') as f:
        return f.read().split('\n')


def save(path, lines):
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write('\n'.join(lines))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--file', default=DEFAULT)
    ap.add_argument('cmd', choices=['list', 'check', 'uncheck', 'toggle'])
    ap.add_argument('args', nargs='*')
    a = ap.parse_args()
    lines = load(a.file)

    if a.cmd == 'list':
        state = a.args[0] if a.args and a.args[0] in ('open', 'done', 'all') else 'open'
        text = ' '.join(a.args[1:] if a.args and a.args[0] in ('open', 'done', 'all') else a.args).lower()
        for i, ln in enumerate(lines, 1):
            m = BOX.match(ln)
            if not m:
                continue
            done = m.group(2) in 'xX'
            if (state == 'open' and done) or (state == 'done' and not done):
                continue
            if text and text not in ln.lower():
                continue
            indent = '  ' if ln.startswith((' ', '\t')) else ''
            body = ln.strip()[6:].strip()
            print(f"{i:>4} [{'x' if done else ' '}] {indent}{body[:100]}")
        return 0

    if not a.args:
        ap.error('give at least one line number')
    rc = 0
    for raw in a.args:
        try:
            n = int(raw)
            m = BOX.match(lines[n - 1])
        except (ValueError, IndexError):
            m = None
        if not m:
            print(f'line {raw}: not a checkbox line, skipped', file=sys.stderr)
            rc = 1
            continue
        cur = m.group(2) in 'xX'
        new = {'check': True, 'uncheck': False, 'toggle': not cur}[a.cmd]
        lines[n - 1] = m.group(1) + ('x' if new else ' ') + m.group(3)
        print(f'line {n}: [{"x" if new else " "}] {m.group(3)[2:62].strip()}')
    save(a.file, lines)
    return rc


if __name__ == '__main__':
    sys.exit(main())
