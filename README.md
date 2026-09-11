# Retail · Agentic Assurance & Evidence in GitHub Actions

A GitHub Actions pipeline that takes a **retail requirements document** and ends with a
**sealed evidence pack** and a **requirement-level coverage gate** — every stage driven by
`kane-cli`, nothing hand-authored.

App under test: `https://ecommerce-playground.lambdatest.io/`

---

## The story in one line

Most QA pipelines can tell you *tests passed*. This one tells you **which requirements are
proven, by which run, with the screenshots to back it**.

```
requirements/retail-storefront.md
        │  kane-cli context ingest + extract
        ▼
   context graph  (use-cases, reviewed, commit-chained)
        │  kane-cli design tests
        ▼
   designed *_test.md  (ACs → scenarios → 1:1 tests)
        │  kane-cli testrun run
        ▼
   ONE sealed .evidence pack  ──  kane-cli evidence validate --profile L1
        │  kane-cli cover gaps
        ▼
   designed × proven ribbon  →  PR comment + build gate
```

## What's in the repo

| Path | What it does |
|---|---|
| `requirements/retail-storefront.md` | The single source of truth. Seven requirement areas with acceptance criteria. Edit this and the graph re-opens. |
| `.github/workflows/retail-assurance-evidence.yml` | The three-stage pipeline. |
| `.github/actions/setup-kane/action.yml` | Installs kane-cli, does non-interactive auth, points at the runner's Chrome. |
| `scripts/assurance.sh` | Ingest → extract → review → design, with correct handling of exit code 3. |
| `scripts/coverage_gate.py` | Turns the coverage ribbon into a job summary and a pass/fail gate. |
| `scripts/test_data.py`, `test-data/retail.json` | Supplies the tests' `{{variables}}` on the runner and refuses to run a suite that is missing any. |

## Setup

Add four repository secrets (Settings → Secrets and variables → Actions):

| Secret | Where to get it |
|---|---|
| `LT_USERNAME` | TestMu AI / LambdaTest profile |
| `LT_ACCESS_KEY` | TestMu AI / LambdaTest profile |
| `TESTMUAI_PROJECT_ID` | `kane-cli projects list` |
| `TESTMUAI_FOLDER_ID` | `kane-cli folders list` |
| `RETAIL_SHOPPER_EMAIL` | An account you registered once on the storefront — sign-in and signed-in checkout tests use it |
| `RETAIL_SHOPPER_PASSWORD` | That account's password |

Then push, open a PR against `requirements/`, or run it manually from the Actions tab.

### Test data

Designed tests carry `{{variables}}` for data the requirements never pinned. `testrun` reads them
from `.testmuai/variables/*.json`, which is gitignored, so the evidence job builds
`.testmuai/variables/ci.json` with `scripts/test_data.py provision` from:

- `test-data/retail.json` — non-secret values (product, quantity, currency, search term, …)
- the two shopper-account secrets above
- per-run unique `new_email` / `newsletter_email` / `new_password`, so registration and
  subscribe never collide with a previous run

Preflight then runs `scripts/test_data.py check`: if any member uses a variable nothing supplies,
the job stops with the variable name and the tests that need it, before a browser starts.
`.testmuai/context.md` maps prose like "valid existing credentials" onto the same variables.

## The three stages

### 1 · Assurance — requirements to designed tests

```bash
kane-cli context ingest requirements/*.md --mode ci   # land the sources
kane-cli context extract --mode ci                    # sources → use-cases
kane-cli context review --approve <ids> --mode agent  # the human gate
kane-cli design tests --use-case uc-... --mode ci --max 12
kane-cli context fsck                                 # prove the chain is intact
```

Three things worth pointing at during a demo:

- **`--mode ci` is the "never ask me" policy.** The assurance commands are conversational by
  design; in a pipeline nobody can answer, so `ci` makes the agent assume documented defaults
  instead of hanging.
- **Exit code 3 is not a failure.** It means the agent paused on a question it could not assume
  past, and the session is resumable — `kane-cli context extract --resume <sid> --message "..."`.
  `scripts/assurance.sh` surfaces that as a GitHub warning with the session id rather than a red X.
- **The graph is cached on the requirements hash.** Unchanged requirements are not re-extracted
  and not re-billed. Change one line in the PRD and only that source re-extracts.
- **A use-case that is already fully designed is skipped.** `kane-cli cover gaps --stage design`
  (local, no model call) says which use-cases are complete; designing one again would re-ground,
  commit nothing, and fail. Run with `force_design` to redesign on purpose. A design failure on
  one use-case no longer stops the others; the stage still fails at the end.

For a governed setup, flip `AUTO_APPROVE` to `false`: derived use-cases stay in the review queue,
a human runs `kane-cli context review` locally, and `.context/` gets committed to the repo. The
pipeline then designs only against approved facts.

### 2 · Evidence — one execution, one sealed pack

```bash
kane-cli testrun run .testmuai/tests/*_test.md --dry-run          # preflight
kane-cli testrun run .testmuai/tests/*_test.md \
  --name "Retail regression #42" --parallel 2 --on-failure continue --headless
kane-cli evidence validate .testmuai/evidence/<id>.evidence --profile L1 --json
```

`testrun` runs M tests as **one execution**, which means one sealed pack for the whole retail
suite rather than N loose artifacts.

The workflow picks `--parallel` itself: `1` while any member still has to be authored (authoring
holds the test's write lock, and a second worker authoring at the same time drops to readonly and
throws its work away), `2` once every member replays. Recorded steps are cached between runs so
later runs replay instead of re-authoring. The pack is uploaded with 90-day retention — that's the
thing you hand a prospect's QA lead or drop into an audit.

To open a downloaded pack:

```bash
kane-cli evidence serve retail-regression-42.evidence
```

Two packs from different runs (say web + mobile) merge into one buyer-facing artifact:

```bash
kane-cli evidence merge <pack-a> <pack-b> --run-id retail-peak-readiness --title "Peak readiness"
```

### 3 · Coverage — designed × proven

```bash
# --from is an option of `cover`, so it goes BEFORE the `gaps` subcommand
kane-cli cover --from <pack> gaps --rollup strict --json
```

Two axes: **completeness** owed by the live graph (did we design something for every AC?) and
**depth** proven by the pack (did a test actually run and pass?). A requirement with a designed
test and no passing evidence shows as a gap — which is exactly the number a release manager
wants and a green tick never gives them.

The gate fails the build below `COVERAGE_THRESHOLD` (default 80%) and posts the ribbon as a PR
comment.

## Running it locally first

Do this once before you demo — it's the fastest way to see the conversational stages properly:

```bash
npm install -g @testmuai/kane-cli
kane-cli login --oauth
kane-cli config set-url https://ecommerce-playground.lambdatest.io/

kane-cli context ingest requirements/retail-storefront.md   # TTY drops you into the extract chat
kane-cli context list --type usecase
kane-cli design tests --use-case <uc-id>                    # interactive design
kane-cli testrun run .testmuai/tests/*_test.md
kane-cli cover --from <pack> gaps
```

The interactive runs are also where you resolve anything the CI mode had to assume.

## Keeping it true as requirements change

When the PRD changes, the pipeline re-ingests it, but the honest workflow is:

```bash
kane-cli maintain reconcile      # every proposed change HOLDS as a review card
kane-cli maintain evolve <ref>   # re-design the affected use-case; untouched items preserved
```

Nothing commits without a verdict. That's the answer to "how do you stop the AI quietly
rewriting our test suite?" — a question you will get.

## Adapting it to a named account

Three edits:

1. Replace `requirements/retail-storefront.md` with the prospect's own PRD, epic, or acceptance
   notes. Any markdown works; `context ingest` takes several sources at once.
2. Change `APP_URL` in the workflow env to their environment.
3. Set `COVERAGE_THRESHOLD` to whatever their release gate actually is.

Everything else — the use-cases, the ACs, the scenarios, the tests, the evidence — is derived.
That derivation is the demo.

---

**Note on flags:** command surface verified against `@testmuai/kane-cli@0.8.10`; the commands
the design-skip logic reads (`cover gaps --stage design --json`, `context list --json`) were
re-checked on `0.8.11`.
CI installs the version pinned in `.github/actions/setup-kane/action.yml` (`version` input,
currently `0.8.11`); bump it deliberately and run `kane-cli changelog` first.
