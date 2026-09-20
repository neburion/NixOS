"""Align parameter columns across consecutive function prototypes.

clang-format aligns the return type and the function name, then stops -- its
AlignConsecutiveDeclarations only ever reaches as far as the name. Nothing in
clang-format or uncrustify aligns the parameters of one prototype against the
parameters of the next, so this runs after clang-format and does that one job.

The opening paren is deliberately left tight against the name. Aligning it too
would let the first parameter share a column as well, but only by padding
between the name and its paren -- `bit_isolation (bool *out_bit` -- which
reads as a typo and contradicts the brace style this config otherwise keeps.
The first parameter therefore starts wherever the name ends; every parameter
after it is aligned.

Everything here is deliberately conservative, because this rewrites source
files on every save. A line is only ever touched when it is unambiguously a
top-level prototype, and any group whose aligned form would exceed the column
budget is left exactly as clang-format wrote it.
"""

import re
import sys

# Column 0 only. A prototype lives at file scope; anything indented is inside a
# function body, where `r = foo(a, b);` would otherwise look identical to this.
PROTO = re.compile(r"^(\S.*?[ *])([A-Za-z_][A-Za-z_0-9]*)\((.+)\);[ \t]*$")

# Prefixes that make a line a statement rather than a declaration.
NOT_A_DECL = re.compile(r"[=;{}]|\b(return|if|while|for|switch|do|else)\b")

# Passed in so the Nix module stays the single source of truth for the budget.
COLUMN_LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 120


def split_params(text):
    """Split on commas that are not nested inside (), [] or {}."""
    parts, depth, current = [], 0, ""
    for char in text:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += char
    if current.strip():
        parts.append(current.strip())
    return parts


def parse(line):
    match = PROTO.match(line)
    if not match:
        return None
    prefix, name, params = match.groups()
    if NOT_A_DECL.search(prefix):
        return None
    if depth_balanced(params) is False:
        return None
    return prefix, name, split_params(params)


def depth_balanced(text):
    depth = 0
    for char in text:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if depth < 0:
            return False
    return depth == 0


def align(group):
    parsed = [parse(line) for line in group]
    columns = max(len(p[2]) for p in parsed)

    bodies = ["" for _ in parsed]
    cursor = [len(p[0]) + len(p[1]) + 1 for p in parsed]

    for index in range(columns):
        live = [i for i, p in enumerate(parsed) if index < len(p[2])]
        if index == 0:
            for i in live:
                bodies[i] += parsed[i][2][0]
                cursor[i] += len(parsed[i][2][0])
            continue
        for i in live:
            bodies[i] += ","
            cursor[i] += 1
        target = max(cursor[i] + 1 for i in live)
        for i in live:
            bodies[i] += " " * (target - cursor[i]) + parsed[i][2][index]
            cursor[i] = target + len(parsed[i][2][index])

    result = [f"{p[0]}{p[1]}({body});" for p, body in zip(parsed, bodies)]

    # Padding costs columns. If that pushes any line past the budget, the
    # unaligned original is the better answer.
    if max(len(line) for line in result) > COLUMN_LIMIT:
        return list(group)
    return result


def run(lines):
    output, group = [], []

    def flush():
        if group:
            output.extend(align(group) if len(group) > 1 else group)
            group.clear()

    for line in lines:
        if parse(line):
            group.append(line)
        else:
            flush()
            output.append(line)
    flush()
    return output


def main():
    text = sys.stdin.read()
    sys.stdout.write("\n".join(run(text.split("\n"))))


if __name__ == "__main__":
    main()
