"""Align parameter columns across consecutive function prototypes.

clang-format aligns the return type and the function name, then stops -- its
AlignConsecutiveDeclarations only ever reaches as far as the name. Nothing in
clang-format or uncrustify aligns the parameters of one prototype against the
parameters of the next, so this runs after clang-format and does that one job.

Every parameter column lines up, the first one included. That requires the
opening parens to line up, and the paren sits wherever the name ends, so the
difference in name length is absorbed between the name and its paren:

    Error execute_CLS      (Chip8 *chip8);
    Error execute_DRW_V_V_N(Chip8 *chip8, const u4 params[static 3]);

Chosen deliberately over right-aligning the names, which would have kept the
paren tight. The gap only ever appears inside a group of two or more
prototypes that are being aligned against each other.

Within a column each parameter is split into its type and its name, and the
two are padded separately -- the same shape clang-format gives a run of
variable declarations, where the types form one column and the names another:

    Error bit_isolation  (bool*  out_bit, size_t   position);
    Error nibbles_to_u8  (u8*    out_bits, const u4 nibbles[static 2]);

The split is the last space at bracket depth zero, which puts `const u4` and
`params[static 3]` on the correct sides and survives `[static 3]` containing a
space of its own. A parameter with no name at all is all type.

Column starts are absolute and shared by the whole group. A prototype that
runs out of parameters still counts toward the width of the column it stopped
in, so the next column begins past the widest cell in the group rather than
past whatever that one row happened to end with.

clang-format collapses this padding on the next run, and this pass puts it
back, so the chain as a whole still settles on a fixed point.

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

# Prefixes that make a line a statement rather than a declaration. `template`
# is here because a template header makes the prototype far wider than its
# neighbours, and one of them would otherwise set the paren column for a whole
# table of ordinary declarations.
NOT_A_DECL = re.compile(r"[=;{}]|\b(return|if|while|for|switch|do|else|template)\b")

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


def top_level_index(param, wanted):
    """Index of the first `wanted` char outside (), [] and {}, or -1."""
    depth = 0
    for index, char in enumerate(param):
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == wanted and depth == 0:
            return index
    return -1


def split_type_name(param):
    """Cut a parameter at its last top-level space: type before, name after.

    A C++ default argument is kept with the name. Splitting at the last space
    outright would cut `int width = 640` into `int width =` and `640`, and then
    pad the gap before the literal -- rewriting the default's own spacing.
    """
    default = ""
    equals = top_level_index(param, "=")
    if equals >= 0:
        default = " " + param[equals:].strip()
        param = param[:equals].rstrip()

    depth, cut = 0, -1
    for index, char in enumerate(param):
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == " " and depth == 0:
            cut = index
    if cut < 0:
        return param, default.strip()
    return param[:cut], param[cut + 1:] + default


def render_columns(parsed, columns):
    """Pad every parameter's type so the names line up inside each column."""
    cells = [[] for _ in parsed]
    for index in range(columns):
        live = [i for i, p in enumerate(parsed) if index < len(p[2])]
        split = {i: split_type_name(parsed[i][2][index]) for i in live}
        type_width = max(len(split[i][0]) for i in live)
        for i in live:
            kind, name = split[i]
            cells[i].append(f"{kind.ljust(type_width)} {name}".rstrip() if name else kind)
    return cells


def align(group):
    parsed = [parse(line) for line in group]
    columns = max(len(p[2]) for p in parsed)

    # Pad each `returntype name` to the widest in the group, so every paren --
    # and therefore every first parameter -- starts in the same column.
    heads = [p[0] + p[1] for p in parsed]
    head_width = max(len(head) for head in heads)

    cells = render_columns(parsed, columns)

    # Every column gets one absolute start, shared by every prototype in the
    # group. The width of a column is the widest cell anywhere in it -- a row
    # that stops here still votes on where the next column begins, which is
    # what keeps a three-parameter prototype lined up with the two-parameter
    # ones above it rather than closing up against its own second parameter.
    widths = [
        max(len(row[index]) for row in cells if index < len(row))
        for index in range(columns)
    ]
    starts = [head_width + 1]
    for index in range(columns - 1):
        starts.append(starts[index] + widths[index] + len(", "))

    result = []
    for head, row in zip(heads, cells):
        line = head.ljust(head_width) + "("
        cursor = head_width + 1
        for index, cell in enumerate(row):
            line += " " * (starts[index] - cursor) + cell
            cursor = starts[index] + len(cell)
            if index < len(row) - 1:
                line += ","
                cursor += 1
        result.append(line.rstrip() + ");")

    # Padding costs columns. If that pushes any line past the budget, the
    # unaligned original is the better answer.
    if max(len(line) for line in result) > COLUMN_LIMIT:
        return list(group)
    return result


# A case label conservative enough to be safe: `default`, or `case` plus a
# bare identifier or number. Anything else -- a character literal like
# `case ':':`, a GCC range, a constant expression -- is left alone rather than
# risk cutting it at the wrong colon.
CASE_LABEL = re.compile(
    r"^([ \t]*)((?:case[ \t]+(?:[A-Za-z_][A-Za-z_0-9]*|[0-9]+))|default):[ \t]+(?!\{)(\S.*)$"
)


def align_cases(lines):
    """Line up the bodies of consecutive one-line case labels.

    A case that opens a block is deliberately not part of any run. Its body is
    a brace, not a statement, and letting it widen the column spaces every
    neighbouring `return` out to clear a label it has nothing to do with.
    Because it does not match, it also breaks the run -- labels either side of
    a block are aligned separately, which is what reading them as two tables
    rather than one implies.
    """
    output, group = [], []

    def flush():
        if group:
            width = max(len(m.group(1)) + len(m.group(2)) + 1 for m in group)
            for match in group:
                indent, label, body = match.groups()
                head = f"{indent}{label}:"
                output.append(f"{head.ljust(width)} {body}")
            group.clear()

    for line in lines:
        match = CASE_LABEL.match(line)
        # An indent change means a different switch; do not align across them.
        if match and (not group or match.group(1) == group[0].group(1)):
            group.append(match)
        else:
            flush()
            if match:
                group.append(match)
            else:
                output.append(line)
    flush()
    return output


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
    sys.stdout.write("\n".join(align_cases(run(text.split("\n")))))


if __name__ == "__main__":
    main()
