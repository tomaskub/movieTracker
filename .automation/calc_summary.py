#!/usr/bin/env python3

import re
import sys
import argparse
from pathlib import Path

VALID_DECISIONS = {"Accepted as-is", "Minor edit", "Structural rewrite", "Rejected"}

SUMMARY_FIELD_VALUES = {
    "Total prompts issued",
    "Accepted as-is",
    "Accepted with minor edits",
    "Structurally rewritten",
    "Rejected",
    "Approx. lines generated",
    "Approx. lines retained",
    "Acceptance rate (retained / generated)",
}


def extract_section(content: str, header: str) -> str | None:
    pattern = re.compile(r"^" + re.escape(header) + r"\s*$", re.MULTILINE)
    match = pattern.search(content)
    if not match:
        return None
    rest = content[match.end():]
    next_h2 = re.search(r"^##\s", rest, re.MULTILINE)
    return rest[: next_h2.start()] if next_h2 else rest


def parse_table_row(line: str) -> tuple[str, str] | None:
    parts = line.split("|")
    if len(parts) < 4:
        return None
    field = parts[1].strip()
    value = parts[2].strip()
    if not field or field.startswith("-"):
        return None
    return field, value


def parse_prompts(prompt_section: str) -> list[dict]:
    entries = []
    headers = list(re.finditer(r"^### Prompt (\d+)", prompt_section, re.MULTILINE))

    for i, header_match in enumerate(headers):
        prompt_num = int(header_match.group(1))
        start = header_match.start()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(prompt_section)
        block = prompt_section[start:end]

        entry = {
            "prompt_num": prompt_num,
            "acceptance_decision": None,
            "lines_generated": None,
            "lines_retained": None,
        }

        for line in block.splitlines():
            if not line.strip().startswith("|"):
                continue
            row = parse_table_row(line)
            if row is None:
                continue
            field, value = row
            if field == "Acceptance decision":
                entry["acceptance_decision"] = value or None
            elif field == "Lines generated (approx.)":
                if re.match(r"^\d+$", value):
                    entry["lines_generated"] = int(value)
            elif field == "Lines retained after edits (approx.)":
                if re.match(r"^\d+$", value):
                    entry["lines_retained"] = int(value)

        entries.append(entry)

    return entries


def update_summary_table(content: str, values: dict[str, str]) -> str:
    lines = content.splitlines(keepends=True)
    in_summary = False
    result = []

    for line in lines:
        stripped = line.rstrip("\n")

        if re.match(r"^## Session Summary\s*$", stripped):
            in_summary = True
            result.append(line)
            continue

        if in_summary and re.match(r"^##\s", stripped):
            in_summary = False

        if in_summary and stripped.startswith("|"):
            parts = stripped.split("|")
            if len(parts) >= 4:
                field = parts[1].strip()
                if field in values:
                    new_value = values[field]
                    parts[2] = f" {new_value} " if new_value else " "
                    eol = "\n" if line.endswith("\n") else ""
                    result.append("|".join(parts) + eol)
                    continue

        result.append(line)

    return "".join(result)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Calculate and write session summary from prompt log entries."
    )
    parser.add_argument("session_log", help="Path to the session log .md file to update")
    args = parser.parse_args()

    log_path = Path(args.session_log)

    if not log_path.exists():
        print(f"Error: file not found: {log_path}", file=sys.stderr)
        sys.exit(1)

    content = log_path.read_text(encoding="utf-8")

    if "## Prompt Log" not in content:
        print("Error: missing '## Prompt Log' section.", file=sys.stderr)
        sys.exit(1)
    if "## Session Summary" not in content:
        print("Error: missing '## Session Summary' section.", file=sys.stderr)
        sys.exit(1)

    prompt_section = extract_section(content, "## Prompt Log")
    if prompt_section is None:
        print("Error: could not parse '## Prompt Log' section.", file=sys.stderr)
        sys.exit(1)

    entries = parse_prompts(prompt_section)

    accepted_as_is = 0
    minor_edits = 0
    structural_rewrites = 0
    rejected = 0
    lines_generated_total = 0
    lines_retained_total = 0
    has_line_data = False

    for entry in entries:
        decision = entry["acceptance_decision"]
        if decision is not None and decision not in VALID_DECISIONS:
            print(
                f"Warning: prompt {entry['prompt_num']}: invalid acceptance decision '{decision}'",
                file=sys.stderr,
            )
            decision = None

        if decision == "Accepted as-is":
            accepted_as_is += 1
        elif decision == "Minor edit":
            minor_edits += 1
        elif decision == "Structural rewrite":
            structural_rewrites += 1
        elif decision == "Rejected":
            rejected += 1

        if entry["lines_generated"] is not None and entry["lines_retained"] is not None:
            lines_generated_total += entry["lines_generated"]
            lines_retained_total += entry["lines_retained"]
            has_line_data = True

    if has_line_data and lines_generated_total > 0:
        acceptance_rate = f"{lines_retained_total / lines_generated_total * 100:.1f}%"
    else:
        acceptance_rate = "N/A"

    values = {
        "Total prompts issued": str(len(entries)),
        "Accepted as-is": str(accepted_as_is),
        "Accepted with minor edits": str(minor_edits),
        "Structurally rewritten": str(structural_rewrites),
        "Rejected": str(rejected),
        "Approx. lines generated": str(lines_generated_total) if has_line_data else "",
        "Approx. lines retained": str(lines_retained_total) if has_line_data else "",
        "Acceptance rate (retained / generated)": acceptance_rate,
    }

    updated = update_summary_table(content, values)
    log_path.write_text(updated, encoding="utf-8")

    print(
        f"Session summary updated: {len(entries)} prompts processed, acceptance rate {acceptance_rate}."
    )


if __name__ == "__main__":
    main()
