#!/usr/bin/env python3
"""Checks Shared/Localizable.xcstrings against the Swift source.

Run from the repo root: python3 Tools/Localization/check.py

Fails (exit 1) when
  * a localizable literal in the source has no catalog key,
  * a catalog key is missing a language or has no en value,
  * a catalog key has no source literal,
  * an App Shortcut phrase has no key in Posture/AppShortcuts.xcstrings,
  * a value's format specifiers do not match its key, or
  * plain copy can reach the screen without a key: a `return "..."`, a ternary
    or `??` of literals, a `case .x: "..."`, an assignment, a copy-named
    argument, a sentence-shaped literal anywhere, or a literal beside a String
    expression in a SwiftUI text API (SwiftUI shows that verbatim).

Literals count as localizable when they are the first argument of a SwiftUI
text API (Text, Button, Label, Section, navigationTitle, alert, ...) or of
String(localized:). Interpolations are compared loosely (%@ and %lld match
each other), because the type of an interpolated expression is not visible
without the compiler.
"""
import json
import os
import re
import sys

ROOT = os.getcwd()
DIRS = ['Posture', 'Shared', 'PostureWatch', 'PostureWidget', 'PostureWatchWidget']
LANGS = []
UI_FUNCS = {'Text', 'Button', 'Label', 'Section', 'Toggle', 'TextField', 'navigationTitle', 'accessibilityLabel',
            'alert', 'DatePicker', 'Stepper', 'Link', 'configurationDisplayName', 'description',
            'confirmationDialog', 'Picker', 'LocalizedStringKey', 'accessibilityHint', 'SecureField',
            'LabeledContent', 'widgetLabel', 'accessibilityValue', 'Menu', 'DisclosureGroup', 'NavigationLink'}
IGNORED = {'0'}

# Debug and analytics plumbing that never draws copy.
SKIP_FILES = {'AnalyticsService.swift', 'ConversionDiagnostics.swift', 'DuoScreenshotTour.swift',
              'ScreenshotSeed.swift', 'PaywallScreenshotHarness.swift', 'PaywallScreenshotMode.swift'}
# A literal anywhere inside these calls is not copy.
SAFE_FUNCS = {'Image', 'NSLog', 'Logger', 'notice', 'info', 'debug', 'error', 'warning', 'fault', 'print',
              'preconditionFailure', 'fatalError', 'assert', 'assertionFailure', 'URL', 'Name', 'track',
              'contains', 'hasPrefix', 'ModelConfiguration', 'appendingPathComponent', 'URLComponents',
              'setLocalizedDateFormatFromTemplate', 'UNNotificationRequest', 'argumentValue', 'value',
              'offering', 'Decimal', 'calibrateStarted', 'PaywallView', 'trackPaywallImpression',
              'string', 'bool', 'integer', 'set', 'removeObject', 'split'}
# Named arguments that hold an identifier, never copy.
SAFE_ARGS = {'systemImage', 'systemName', 'icon', 'id', 'identifier', 'forKey', 'paywallImpressionId',
             'subsystem', 'category', 'imageName', 'systemImageName', 'separator', 'with', 'of', 'kind',
             'verbatim'}
# Named arguments that hold copy in a plain String.
COPY_ARGS = {'label', 'title', 'subtitle', 'body', 'message', 'text', 'detail', 'headline', 'actionLabel',
             'primaryTitle', 'value', 'description'}
# Single words returned or compared in code that are not copy.
ALLOWED = {'IlloStanding', 'IlloSitting', 'IlloStandingSlouch', 'IlloSlouch', 'IlloStack',
           'Nunito-Bold', 'Nunito-SemiBold', 'Nunito-Medium', 'Nunito-Regular',
           'desktopcomputer', 'brain', 'checkmark', 'exclamationmark', 'rosette', 'lifetime',
           'monthly', 'yearly', 'unknown', 'true', 'false', 'walk', 'default', 'session', 'monitor',
           'today,progress,session,settings', 'today,history,progress,settings', 'Posture', 'PostureWidget',
           'PostureWatchWidget', 'applewatch', 'figure', 'history', 'progress', 'settings', 'quick', 'full',
           'skipped', 'CFBundleShortVersionString', 'funnel-probe-posture', 'posture_pro_tab', 'posture_sheet', 'posture_settings_sheet'}
SYMBOL_OR_ID = re.compile(r'^[A-Za-z0-9_-]+([._][A-Za-z0-9_-]+)+$')
URLISH = re.compile(r'^[a-z]+://|^mailto:')


def strip_previews(src):
    """Blanks #Preview blocks, keeping line numbers."""
    while True:
        at = src.find('#Preview')
        if at < 0:
            return src
        i = src.find('{', at)
        depth = 0
        j = i
        while j < len(src):
            if src[j] == '"':
                j, _ = parse_literal(src, j)
                continue
            if src[j] == '{':
                depth += 1
            elif src[j] == '}':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        src = src[:at] + re.sub(r'[^\n]', ' ', src[at:j + 1]) + src[j + 1:]


def parse_literal(src, i):
    """src[i] == '"'. Returns (end_index_after, segments) where segments are ('lit', str) or ('interp', expr)."""
    assert src[i] == '"'
    if src.startswith('"""', i):
        j = src.index('"""', i + 3)
        return j + 3, None
    i += 1
    segs = []; buf = ''
    while True:
        c = src[i]
        if c == '"':
            if buf: segs.append(('lit', buf))
            return i + 1, segs
        if c == '\\':
            n = src[i + 1]
            if n == '(':
                if buf: segs.append(('lit', buf)); buf = ''
                depth = 1; j = i + 2; expr = ''
                while depth:
                    ch = src[j]
                    if ch == '"':
                        k, _ = parse_literal(src, j)
                        expr += src[j:k]; j = k; continue
                    if ch == '(': depth += 1
                    elif ch == ')':
                        depth -= 1
                        if depth == 0: break
                    expr += ch; j += 1
                segs.append(('interp', expr.strip()))
                i = j + 1; continue
            if n == 'u':
                j = src.index('}', i)
                buf += chr(int(src[i + 3:j], 16)); i = j + 1; continue
            buf += {'n': '\n', 't': '\t', '"': '"', '\\': '\\', "'": "'", '0': '\0'}[n]
            i += 2; continue
        buf += c; i += 1


def literal_text(segs):
    return ''.join(v for kind, v in segs if kind == 'lit')


def is_copy_shaped(text):
    if not re.search(r'[A-Za-z]', text) or text in ALLOWED:
        return False
    return not (SYMBOL_OR_ID.match(text) or URLISH.match(text))


def enclosing_ui(stack):
    """The SwiftUI text call whose first argument holds this literal, through bare parentheses."""
    for fn, argtxt, idx in reversed(stack):
        if fn:
            named = re.match(r'\s*([a-zA-Z_]+)\s*:(?!:)', argtxt)
            if fn in UI_FUNCS and idx == 0 and (not named or named.group(1) == 'titleKey'):
                return fn
            return None
    return None


def plain_copy_reason(src, i, segs, stack):
    """Why the plain literal at src[i] can reach the screen without a key, or None."""
    text = literal_text(segs)
    if not is_copy_shaped(text):
        return None
    if any(fn in SAFE_FUNCS for fn, _, _ in stack):
        return None
    arg = re.match(r'\s*([a-zA-Z_]+)\s*:(?!:)', stack[-1][1]) if stack else None
    if arg and arg.group(1) in SAFE_ARGS:
        return None
    before = src[max(0, i - 80):i]
    line = before[before.rfind('\n') + 1:]
    tail = line.rstrip()
    if re.search(r'\breturn$', tail):
        return 'return of a plain literal'
    if tail.endswith('?') or tail.endswith('??') or re.search(r'\s:$', tail):
        return 'ternary or ?? of plain literals'
    if re.search(r'\bcase\b.*:$', tail):
        return 'case with a plain literal'
    if re.search(r'^\s*[\w.\[\]"]+\s*\+?=$', tail):
        return 'assignment of a plain literal'
    if arg and arg.group(1) in COPY_ARGS:
        return f'plain literal in {arg.group(1)}:'
    if re.search(r'\s', text.strip()) and not line.lstrip().startswith(('@', '#')):
        return 'sentence in a plain String'
    return None


def scan(path_or_src, is_src=False):
    """Returns (keyed literals, plain-copy problems, App Shortcut phrases)."""
    src = path_or_src if is_src else strip_previews(open(path_or_src).read())
    out = []; plain = []; phrases = []
    stack = []  # (funcname, argtext_since_last_comma, argindex)
    i = 0; n = len(src)
    line = 1
    while i < n:
        c = src[i]
        if c == '\n': line += 1
        if src.startswith('//', i):
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if src.startswith('/*', i):
            j = src.index('*/', i); line += src[i:j].count('\n'); i = j + 2; continue
        if c == '"':
            end, segs = parse_literal(src, i)
            if segs is not None:
                ctx = None
                if stack and stack[-1][0] == 'String' and stack[-1][1].strip().startswith('localized:'):
                    ctx = 'String'
                elif re.search(r'LocalizedStringResource\s*=\s*$', src[max(0, i - 60):i]):
                    ctx = 'LocalizedStringResource'
                elif any(fn == 'AppShortcut' for fn, _, _ in stack):
                    if stack[-1][1].strip().startswith('shortTitle:'):
                        ctx = 'shortTitle'
                    elif not re.search(r'systemImageName:\s*$', stack[-1][1]):
                        phrases.append((line, ''.join(v if kind == 'lit' else '${applicationName}' for kind, v in segs)))
                        i = end
                        continue
                else:
                    ctx = enclosing_ui(stack)
                if ctx:
                    out.append((line, ctx, segs))
                else:
                    reason = plain_copy_reason(src, i, segs, stack)
                    if reason:
                        plain.append((line, reason, literal_text(segs)))
                for kind, expr in segs:
                    if kind == 'interp' and '"' in expr:
                        inner_out, inner_plain, _ = scan(expr, is_src=True)
                        out += [(line, x, s) for _, x, s in inner_out]
                        plain += [(line, r, t) for _, r, t in inner_plain]
            line += src[i:end].count('\n')
            if stack:
                f, a, k = stack[-1]; stack[-1] = (f, a + src[i:end], k)
            i = end; continue
        if c == '(':
            m = re.search(r'([A-Za-z_][A-Za-z_0-9]*)\s*$', src[max(0, i - 60):i])
            stack.append((m.group(1) if m else '', '', 0)); i += 1; continue
        if c == ')':
            if stack:
                fn, argtxt, idx = stack.pop()
                if fn in UI_FUNCS and idx == 0:
                    plain += mixed_branches(line, argtxt)
            i += 1; continue
        if c == ',' and stack:
            f, a, k = stack[-1]
            if f in UI_FUNCS and k == 0:
                plain += mixed_branches(line, a)
            stack[-1] = (f, '', k + 1); i += 1; continue
        if stack:
            f, a, k = stack[-1]; stack[-1] = (f, a + c, k)
        i += 1
    return out, plain, phrases


def mixed_branches(line, argtxt):
    """`Text(flag ? "literal" : someString)` compiles to String, so the literal is never looked up."""
    masked = []
    def mask(m):
        masked.append(m.group(0))
        body = re.sub(r'\\\([^)]*\)', '', m.group(0)[1:-1])
        return '\u00a7' if re.search(r'[A-Za-z]', body) else '\u00a4'
    expr = re.sub(r'"(?:[^"\\]|\\.)*"', mask, argtxt)
    if '\u00a7' not in expr or '?' not in expr:
        return []
    parts = re.split(r'\?\?|\?|\s:(?:\s|$)', expr)
    branches = parts if '??' in expr and ' ? ' not in expr else parts[1:]
    if all(b.strip() in ('\u00a7', '') for b in branches):  # empty: a parenthesized ternary, checked on its own
        return []
    return [(line, 'literal beside a String expression is shown verbatim', argtxt.strip())]


def loose(key):
    return re.sub(r'%(\d+\$)?(lld|@)', '%*', key)


def specs(value, subs=None):
    found = []
    auto = 0
    for m in re.finditer(r'%(?:(\d+)\$)?(lld|@|%)|%#@(\w+)@', value):
        if m.group(2) == '%':
            continue
        if m.group(3):
            found.append((subs[m.group(3)]['argNum'], 'lld'))
            continue
        if m.group(1):
            pos = int(m.group(1))
        else:
            auto += 1
            pos = auto
        found.append((pos, m.group(2)))
    return sorted(set(found))


def main():
    catalog = json.load(open(os.path.join(ROOT, 'Shared', 'Localizable.xcstrings')))['strings']
    by_loose = {loose(k): k for k in catalog}
    shortcuts = json.load(open(os.path.join(ROOT, 'Posture', 'AppShortcuts.xcstrings')))['strings']
    used = set()
    problems = []
    for d in DIRS:
        for dirpath, _, files in os.walk(os.path.join(ROOT, d)):
            for name in files:
                if not name.endswith('.swift') or name in SKIP_FILES:
                    continue
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, ROOT)
                keyed, plain, phrases = scan(path)
                for line, phrase in phrases:
                    if phrase not in shortcuts:
                        problems.append(f'{rel}:{line}: no AppShortcuts.xcstrings key for "{phrase}"')
                for line, _, segs in keyed:
                    has_interp = any(kind == 'interp' for kind, _ in segs)
                    key = ''.join((v.replace('%', '%%') if has_interp else v) if kind == 'lit' else '%@'
                                  for kind, v in segs)
                    if not key.strip() or key in IGNORED:
                        continue
                    if loose(key) in by_loose:
                        used.add(by_loose[loose(key)])
                    else:
                        problems.append(f'{rel}:{line}: no catalog key for "{key}"')
                for line, reason, text in plain:
                    problems.append(f'{rel}:{line}: {reason}: "{text}"')
    for key in catalog:
        if key not in used:
            problems.append(f'"{key}": no source literal uses this key')
    for key, entry in catalog.items():
        if entry.get('extractionState') != 'manual':
            problems.append(f'"{key}": extractionState must be manual')
        locs = entry.get('localizations', {})
        for lang in ['en'] + LANGS:
            loc = locs.get(lang)
            if loc is None:
                problems.append(f'"{key}": missing {lang}')
                continue
            want = specs(key)
            if 'variations' in loc:
                values = [u['stringUnit']['value'] for u in loc['variations']['plural'].values()]
                bad = [v for v in values if specs(v) and specs(v) != want]
            else:
                bad = [] if specs(loc['stringUnit']['value'], loc.get('substitutions')) == want else [loc['stringUnit']['value']]
            for v in bad:
                problems.append(f'"{key}" [{lang}]: format specifiers differ in "{v}"')
    for key, entry in catalog.items():
        for lang, loc in entry.get('localizations', {}).items():
            units = [loc] + list(loc.get('variations', {}).get('plural', {}).values())
            for unit in units:
                value = unit.get('stringUnit', {}).get('value', '')
                for name in re.findall(r'%(?:\d+\$)?#@(\w+)@', value):
                    if name not in loc.get('substitutions', {}):
                        problems.append(f'"{key}" [{lang}]: plural token {name!r} has no substitution')
    for p in problems:
        print(p)
    print(f'{len(catalog)} keys, {len(LANGS)} languages, {len(problems)} problems')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
