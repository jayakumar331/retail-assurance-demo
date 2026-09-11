#!/usr/bin/env python3
"""
Test data for the designed retail suite.

`kane-cli testrun` has no --variables flag; members read variables from
.testmuai/variables/*.json. That directory is gitignored (it holds the shopper
password locally), so on a runner it is empty unless this script fills it.

  provision   merge test-data/retail.json + shopper-account secrets + per-run
              unique values into .testmuai/variables/ci.json
  check       fail before any browser starts if a member uses a {{variable}}
              that nothing supplies — those tests cannot pass on any re-run

Values from the environment:
  APP_URL                   -> start_url
  RETAIL_SHOPPER_EMAIL      -> registered_email      (an existing account)
  RETAIL_SHOPPER_PASSWORD   -> registered_password   (secret)
  GITHUB_RUN_ID / _ATTEMPT  -> uniqueness tag for new_email / newsletter_email
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import secrets
import sys
import time
from collections import defaultdict
from pathlib import Path

DATA_FILE = Path("test-data/retail.json")
OUT_FILE = Path(".testmuai/variables/ci.json")
VARIABLE_DIRS = (Path.home() / ".testmuai/kaneai/variables", Path(".testmuai/variables"))

# Missing keys whose fix is a repository secret rather than an edit to DATA_FILE.
SECRET_HINTS = {
    "registered_email": "RETAIL_SHOPPER_EMAIL",
    "registered_password": "RETAIL_SHOPPER_PASSWORD",
    "existing_email": "RETAIL_SHOPPER_EMAIL",
    "existing_password": "RETAIL_SHOPPER_PASSWORD",
    "existing_shopper_email": "RETAIL_SHOPPER_EMAIL",
    "existing_shopper_password": "RETAIL_SHOPPER_PASSWORD",
}

PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)(?:\.[^}]*)?\s*\}\}")


def in_actions() -> bool:
    return os.environ.get("GITHUB_ACTIONS") == "true"


def provision() -> int:
    data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    variables = {k: v for k, v in data.items() if not k.startswith("_")}

    if os.environ.get("APP_URL"):
        variables["start_url"] = {"value": os.environ["APP_URL"]}
        # The storefront has no newsletter email field on any page (only a Yes/No radio
        # on registration), so there is no truer URL than the storefront itself: the
        # newsletter tests run and report the missing control instead of never running.
        variables["newsletter_page_url"] = {"value": os.environ["APP_URL"]}

    # Design names the one shopper account differently per use-case; every name is
    # the same account, so the values can never drift apart.
    email = os.environ.get("RETAIL_SHOPPER_EMAIL", "").strip()
    password = os.environ.get("RETAIL_SHOPPER_PASSWORD", "")
    if email and password:
        for prefix in ("registered", "existing", "existing_shopper"):
            variables[f"{prefix}_email"] = {"value": email}
            variables[f"{prefix}_password"] = {"value": password, "secret": True}
    else:
        print("::warning title=No shopper account::RETAIL_SHOPPER_EMAIL / RETAIL_SHOPPER_PASSWORD "
              "are not set; sign-in tests have no credentials.")

    # Registration and newsletter need an address the store has never seen, on every run
    # (re-runs of the same workflow run included).
    run_id = os.environ.get("GITHUB_RUN_ID") or time.strftime("%Y%m%d%H%M%S")
    tag = f"{run_id}-{os.environ.get('GITHUB_RUN_ATTEMPT', '1')}"
    new_password = "Rt!" + secrets.token_urlsafe(9)
    if in_actions():
        print(f"::add-mask::{new_password}")
    new_email = f"retail.ci.{tag}@example.com"
    newsletter_email = f"retail.news.{tag}@example.com"
    variables["new_email"] = {"value": new_email}
    variables["new_password"] = {"value": new_password, "secret": True}
    variables["newsletter_email"] = {"value": newsletter_email}
    variables["valid_newsletter_email"] = {"value": newsletter_email}
    # Never registered by anyone: the unknown-email sign-in test needs that guarantee.
    variables["unknown_email"] = {"value": f"retail.unknown.{tag}@example.com"}
    # Each registration test gets its own never-used address, so none collides with
    # another test's account in the same run.
    variables["success_unique_email"] = {"value": f"retail.success.{tag}@example.com"}
    variables["privacy_reject_unique_email"] = {"value": f"retail.privacy.{tag}@example.com"}
    # One variable standing for the whole form. No privacy-policy choice here: the
    # tests that use it decide that themselves. Secret because it carries the password.
    first, last, phone = (variables[k]["value"] for k in ("new_first_name", "new_last_name", "new_telephone"))
    form = f"First Name: {first}; Last Name: {last}; Telephone: {phone}; " \
           f"Password: {new_password}; Password Confirm: {new_password}"
    variables["valid_registration_details"] = {"value": f"{form}; E-Mail: {new_email}", "secret": True}
    # The same form for tests that supply their own email variable.
    variables["valid_registration_details_except_email"] = {"value": form, "secret": True}

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(json.dumps(variables, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(variables)} variables to {OUT_FILE}: {', '.join(sorted(variables))}")
    return 0


def supplied_keys() -> set[str]:
    keys: set[str] = set()
    for directory in VARIABLE_DIRS:
        for path in sorted(glob.glob(str(directory / "*.json"))):
            try:
                keys.update(k for k in json.loads(Path(path).read_text(encoding="utf-8")) if not k.startswith("_"))
            except (OSError, json.JSONDecodeError) as exc:
                print(f"::warning::Could not read {path}: {exc}")
    return keys


def frontmatter_keys(text: str) -> set[str]:
    """Keys under a root `variables:` block in the test's own frontmatter."""
    match = re.match(r"---\n(.*?)\n---", text, re.S)
    if not match:
        return set()
    keys, inside = set(), False
    for line in match.group(1).splitlines():
        if re.match(r"variables:\s*$", line):
            inside = True
        elif inside and (m := re.match(r"  ([A-Za-z_][A-Za-z0-9_]*):", line)):
            keys.add(m.group(1))
        elif inside and line and not line.startswith(" "):
            inside = False
    return keys


def stored_in_run(text: str) -> set[str]:
    """Names the test itself captures ("store X as name") — resolved at run time."""
    return set(re.findall(r"\bas\s+['\"`]?([A-Za-z_][A-Za-z0-9_]*)", text))


def check(members_file: str) -> int:
    members = [line.strip() for line in Path(members_file).read_text(encoding="utf-8").splitlines() if line.strip()]
    supplied = supplied_keys()
    missing: dict[str, list[str]] = defaultdict(list)

    for member in members:
        text = Path(member).read_text(encoding="utf-8")
        known = supplied | frontmatter_keys(text) | stored_in_run(text)
        for name in sorted(set(PLACEHOLDER.findall(text)) - known):
            missing[name].append(member)

    if not missing:
        print(f"Test data OK: every variable used by {len(members)} member(s) is supplied.")
        return 0

    for name, tests in sorted(missing.items()):
        fix = (f"set the {SECRET_HINTS[name]} repository secret" if name in SECRET_HINTS
               else f"add \"{name}\" to {DATA_FILE}")
        print(f"::error title=Missing test data::{{{{{name}}}}} is used by {len(tests)} test(s) "
              f"but nothing supplies it — {fix}.")
        for test in tests:
            print(f"    {test}")
    print(f"{len(missing)} variable(s) unsupplied; stopping before any browser minute is spent.")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("provision")
    check_parser = sub.add_parser("check")
    check_parser.add_argument("members", help="file listing one *_test.md path per line")
    args = parser.parse_args()
    return provision() if args.command == "provision" else check(args.members)


if __name__ == "__main__":
    sys.exit(main())
