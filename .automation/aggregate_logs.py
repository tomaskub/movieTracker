#!/usr/bin/env python3

import argparse
import csv
import re
import subprocess
import sys
from pathlib import Path

VALID_ACCEPTANCE_DECISIONS = {"Accepted as-is", "Minor edit", "Structural rewrite", "Rejected"}
VALID_CORRECTION_TYPES = {"Annotation only", "Logic correction", "Structural rewrite", "N/A"}
VALID_CONCURRENCY_MODELS = {"async/await", "Combine", "callback", "framework-managed", "synchronous"}
VALID_AUTHORSHIPS = {"AI unprompted", "AI prompted", "Manual"}
VALID_AI_ASSERTION_QUALITIES = {"Correct", "Shallow", "Incorrect", "N/A"}

PROMPT_LOG_FIELDS = [
    "arch", "feature", "session_number", "date", "prompt_number",
    "component_targeted", "acceptance_decision", "correction_type",
    "lines_generated", "lines_retained",
]
CONCURRENCY_FIELDS = [
    "arch", "feature", "session_number", "date",
    "site", "covered", "model_first_pass", "notes",
]
TEST_AUTHORSHIP_FIELDS = [
    "arch", "feature", "session_number", "date",
    "scenario_number", "scenario_description", "authorship", "ai_assertion_quality",
]
SESSION_SUMMARY_FIELDS = [
    "arch", "feature", "session_number", "date", "session_type",
    "total_prompts", "accepted_as_is", "minor_edits", "structural_rewrites",
    "rejected", "lines_generated", "lines_retained", "acceptance_rate",
]


def is_separator_row(line: str) -> bool:
    return bool(re.match(r"^\|[-:\s|]+\|$", line.strip()))


def parse_table_rows(text: str) -> list[list[str]]:
    rows = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("|") and not is_separator_row(stripped):
            cells = [c.strip() for c in stripped.strip("|").split("|")]
            rows.append(cells)
    return rows


def parse_key_value_table(text: str) -> dict[str, str]:
    result = {}
    for row in parse_table_rows(text):
        if len(row) >= 2:
            result[row[0]] = row[1]
    return result


def extract_section(content: str, header: str) -> str | None:
    pattern = re.compile(r"^## " + re.escape(header) + r"\s*$", re.MULTILINE)
    match = pattern.search(content)
    if not match:
        return None
    rest = content[match.end():]
    next_h2 = re.search(r"^## ", rest, re.MULTILINE)
    return rest[: next_h2.start()] if next_h2 else rest


def validate_enum(value: str, valid_set: set, filename: str, section: str, context: str) -> str | None:
    if value and value not in valid_set:
        return f"{filename}: {section}: invalid value '{value}' in {context}"
    return None


def validate_integer(value: str, filename: str, section: str, field: str) -> str | None:
    if value and not re.match(r"^\d+$", value):
        return f"{filename}: {section}: '{field}' must be an integer, got '{value}'"
    return None


def parse_session_file(filepath: Path, arch: str) -> tuple[dict | None, list[str]]:
    errors: list[str] = []
    filename = filepath.name

    name_match = re.match(r"(\d{4}-\d{2}-\d{2})_[^_]+_(.+)_session-(\d+)\.md$", filename)
    if not name_match:
        return None, [f"{filename}: filename does not match expected convention"]

    date = name_match.group(1)
    feature = name_match.group(2)
    session_number = int(name_match.group(3))

    content = filepath.read_text(encoding="utf-8")

    for section in ("Prompt Log", "Concurrency Snapshot", "Test Authorship Log", "Session Summary"):
        if not re.search(r"^## " + re.escape(section) + r"\s*$", content, re.MULTILINE):
            errors.append(f"{filename}: missing required section '## {section}'")

    meta_section = extract_section(content, "Session Metadata") or ""
    session_type = parse_key_value_table(meta_section).get("Session type", "")

    prompts: list[dict] = []
    prompt_log_section = extract_section(content, "Prompt Log") or ""
    prompt_headers = list(re.finditer(r"^### Prompt (\d+)", prompt_log_section, re.MULTILINE))
    for idx, header_match in enumerate(prompt_headers):
        prompt_num = int(header_match.group(1))
        block_start = header_match.end()
        block_end = prompt_headers[idx + 1].start() if idx + 1 < len(prompt_headers) else len(prompt_log_section)
        block = prompt_log_section[block_start:block_end]
        table = parse_key_value_table(block)

        comp = table.get("Component targeted", "")
        acceptance = table.get("Acceptance decision", "")
        correction = table.get("Correction type (if edited)", "")
        lines_gen = table.get("Lines generated (approx.)", "")
        lines_ret = table.get("Lines retained after edits (approx.)", "")

        for err in filter(None, [
            validate_enum(acceptance, VALID_ACCEPTANCE_DECISIONS, filename, "Prompt Log", f"prompt {prompt_num}"),
            validate_enum(correction, VALID_CORRECTION_TYPES, filename, "Prompt Log", f"prompt {prompt_num}"),
            validate_integer(lines_gen, filename, "Prompt Log", f"Lines generated (prompt {prompt_num})"),
            validate_integer(lines_ret, filename, "Prompt Log", f"Lines retained (prompt {prompt_num})"),
        ]):
            errors.append(err)

        prompts.append({
            "prompt_number": prompt_num,
            "component_targeted": comp,
            "acceptance_decision": acceptance,
            "correction_type": correction,
            "lines_generated": lines_gen,
            "lines_retained": lines_ret,
        })

    concurrency: list[dict] = []
    concurrency_section = extract_section(content, "Concurrency Snapshot") or ""
    rows = parse_table_rows(concurrency_section)
    seen_sites: set[str] = set()
    for row in rows[1:]:
        if len(row) < 4:
            continue
        site, covered, model, notes = row[0], row[1], row[2], row[3]
        if covered.strip() != "Y":
            continue
        err = validate_enum(model, VALID_CONCURRENCY_MODELS, filename, "Concurrency Snapshot", f"site '{site}'")
        if err:
            errors.append(err)
        if site in seen_sites:
            errors.append(f"{filename}: Concurrency Snapshot: duplicate site '{site}'")
        else:
            seen_sites.add(site)
        concurrency.append({"site": site, "covered": covered, "model_first_pass": model, "notes": notes})

    test_authorship: list[dict] = []
    test_section = extract_section(content, "Test Authorship Log") or ""
    test_rows = parse_table_rows(test_section)
    data_rows = [r for r in test_rows[1:] if r and r[0].strip() and not r[0].strip().startswith("<!--")]
    test_na = len(data_rows) == 0
    if not test_na:
        for i, row in enumerate(data_rows):
            if len(row) < 4:
                continue
            scenario_num, scenario_desc, authorship, quality = row[0], row[1], row[2], row[3]
            for err in filter(None, [
                validate_enum(authorship, VALID_AUTHORSHIPS, filename, "Test Authorship Log", f"scenario {i + 1}"),
                validate_enum(quality, VALID_AI_ASSERTION_QUALITIES, filename, "Test Authorship Log", f"scenario {i + 1}"),
            ]):
                errors.append(err)
            test_authorship.append({
                "scenario_number": scenario_num,
                "scenario_description": scenario_desc,
                "authorship": authorship,
                "ai_assertion_quality": quality,
            })

    summary_section = extract_section(content, "Session Summary") or ""
    summary = parse_key_value_table(summary_section)

    return {
        "date": date,
        "feature": feature,
        "session_number": session_number,
        "session_type": session_type,
        "prompts": prompts,
        "concurrency": concurrency,
        "test_na": test_na,
        "test_authorship": test_authorship,
        "summary": summary,
    }, errors


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def get_git_output(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True).stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description="Aggregate codegen session logs into CSV files.")
    parser.add_argument("--out", help="Output directory for CSV files")
    parser.add_argument("--validate", action="store_true", help="Parse and validate logs without writing CSVs")
    args = parser.parse_args()

    if not args.validate and not args.out:
        parser.error("--out is required unless --validate is specified")

    if subprocess.run(["git", "rev-parse", "--is-inside-work-tree"], capture_output=True).returncode != 0:
        print("Error: not inside a git repository.", file=sys.stderr)
        sys.exit(1)

    repo_root = get_git_output("rev-parse", "--show-toplevel")
    branch = get_git_output("rev-parse", "--abbrev-ref", "HEAD")

    arch_match = re.search(r"\b(mvvm|viper|tca)\b", branch, re.IGNORECASE)
    if not arch_match:
        print(f"Error: cannot determine architecture from branch name '{branch}'.", file=sys.stderr)
        print("Branch name must contain one of: mvvm, viper, tca.", file=sys.stderr)
        sys.exit(1)

    arch = arch_match.group(1).upper()

    obs_dir = Path(repo_root) / ".observation-logs"
    if not obs_dir.exists():
        print("Files parsed: 0, rows written: prompt_log=0, concurrency_snapshot=0, test_authorship=0, session_summary=0, validation errors: 0")
        sys.exit(0)

    session_files = sorted(obs_dir.glob("*_session-*.md"))

    all_errors: list[str] = []
    all_prompts: list[dict] = []
    all_concurrency: list[dict] = []
    all_test_authorship: list[dict] = []
    all_summaries: list[dict] = []

    for filepath in session_files:
        data, errors = parse_session_file(filepath, arch)
        all_errors.extend(errors)
        if data is None:
            continue

        base = {"arch": arch, "feature": data["feature"], "session_number": data["session_number"], "date": data["date"]}

        for prompt in data["prompts"]:
            all_prompts.append({**base, **prompt})

        for site in data["concurrency"]:
            all_concurrency.append({**base, **site})

        if not data["test_na"]:
            for scenario in data["test_authorship"]:
                all_test_authorship.append({**base, **scenario})

        summary = data["summary"]
        all_summaries.append({
            **base,
            "session_type": data["session_type"],
            "total_prompts": summary.get("Total prompts issued", ""),
            "accepted_as_is": summary.get("Accepted as-is", ""),
            "minor_edits": summary.get("Accepted with minor edits", ""),
            "structural_rewrites": summary.get("Structurally rewritten", ""),
            "rejected": summary.get("Rejected", ""),
            "lines_generated": summary.get("Approx. lines generated", ""),
            "lines_retained": summary.get("Approx. lines retained", ""),
            "acceptance_rate": summary.get("Acceptance rate (retained / generated)", ""),
        })

    for error in all_errors:
        print(f"Validation error: {error}", file=sys.stderr)

    if args.validate:
        print(f"Files parsed: {len(session_files)}, validation errors: {len(all_errors)}")
        sys.exit(1 if all_errors else 0)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    write_csv(out_dir / "prompt_log.csv", PROMPT_LOG_FIELDS, all_prompts)
    write_csv(out_dir / "concurrency_snapshot.csv", CONCURRENCY_FIELDS, all_concurrency)
    write_csv(out_dir / "test_authorship.csv", TEST_AUTHORSHIP_FIELDS, all_test_authorship)
    write_csv(out_dir / "session_summary.csv", SESSION_SUMMARY_FIELDS, all_summaries)

    print(f"Files parsed: {len(session_files)}")
    print(f"Rows written: prompt_log={len(all_prompts)}, concurrency_snapshot={len(all_concurrency)}, test_authorship={len(all_test_authorship)}, session_summary={len(all_summaries)}")
    print(f"Validation errors: {len(all_errors)}")

    if all_errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
