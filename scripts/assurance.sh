#!/usr/bin/env bash
#
# Assurance stage: requirements -> context graph -> committed use-cases -> designed tests.
#
# The assurance commands are conversational by design. In CI there is nobody to
# answer, so every call passes `--mode ci`, which is the "never ask me anything"
# policy. Two exit codes matter here and they are NOT the usual ones:
#
#   0  done
#   3  paused and resumable  (the agent had a question it could not assume past)
#   2  refused before doing work — usage error, a design gate (e.g. an unreviewed
#      use-case), or auth/infra. setup-kane has already proved the credentials,
#      so the refusal message in the log is the thing to read.
#
# Exit 3 is not a crash. The session id is preserved under .context/sessions/ and
# a human resumes it locally with:
#   kane-cli context extract --resume <sid> --message "..."
#   kane-cli design tests    --resume <sid> --message "..."
#
set -euo pipefail

REQ_GLOB="${REQ_GLOB:-requirements/*.md}"
MAX_PAIRS="${MAX_PAIRS:-12}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"
FORCE_DESIGN="${FORCE_DESIGN:-false}"

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

# Runs one assurance command, annotates its outcome, and returns its exit code.
# It never exits the script (an `exit` here used to end the whole run from inside
# a loop): each stage decides what a non-zero code means for it. Call it as
# `run_assurance ... || code=$?` so `set -e` does not fire on a paused/failed run.
run_assurance() {
  local label="$1"; shift
  local code=0
  "$@" || code=$?
  case "$code" in
    0) ;;
    3)
      echo "::warning title=Assurance paused::${label} paused with an open question."
      echo "PAUSED_STAGE=${label}" >> "${GITHUB_ENV:-/dev/null}"
      kane-cli context sessions || true
      ;;
    2)
      echo "::error title=Assurance refused::${label} exited 2 — a usage error, a design gate, or auth/infra. The refusal and its next step are in the log above."
      ;;
    *)
      echo "::error title=Assurance failed::${label} exited ${code}."
      ;;
  esac
  return "$code"
}

# ---------------------------------------------------------------------------
step "1/5  Ingest requirement sources into the context graph"
# --mode ci lands the sources without pulling us into the extract chat.
# shellcheck disable=SC2086
kane-cli context ingest $REQ_GLOB --mode ci

# ---------------------------------------------------------------------------
step "2/5  Extract use-cases from the ingested sources"
EXTRACT_CODE=0
run_assurance "context extract" kane-cli context extract --mode ci || EXTRACT_CODE=$?
# Paused is fine — what was committed before the question is still designable.
# Anything else stops here: without use-cases there is nothing to design.
if [ "$EXTRACT_CODE" -ne 0 ] && [ "$EXTRACT_CODE" -ne 3 ]; then
  exit "$EXTRACT_CODE"
fi

# ---------------------------------------------------------------------------
step "3/5  Approve derived use-cases (the human gate)"
# `context list --json` emits one JSON object per line: {id,cid,label,title,trust,fresh}
mapfile -t INFERRED < <(kane-cli context list --type usecase --inferred --json 2>/dev/null | jq -r '.id' || true)

if [ "${#INFERRED[@]}" -gt 0 ] && [ "$AUTO_APPROVE" = "true" ]; then
  echo "Approving ${#INFERRED[@]} derived use-case(s): ${INFERRED[*]}"
  kane-cli context review --approve "${INFERRED[@]}" --mode agent
elif [ "${#INFERRED[@]}" -gt 0 ]; then
  echo "::notice::${#INFERRED[@]} use-case(s) awaiting review. Run 'kane-cli context review' locally and commit .context/."
else
  echo "Nothing new in the review queue."
fi

mapfile -t USECASES < <(kane-cli context list --type usecase --json 2>/dev/null | jq -r '.id' || true)
if [ "${#USECASES[@]}" -eq 0 ]; then
  echo "::error title=No use-cases::Extraction produced nothing to design against."
  exit 1
fi
echo "Live use-cases: ${USECASES[*]}"
printf '%s\n' "${USECASES[@]}" > usecases.txt

# ---------------------------------------------------------------------------
step "4/5  Design acceptance criteria, scenarios and 1:1 tests per use-case"
DESIGN_ARGS=(--mode ci --max "$MAX_PAIRS")
[ "$FORCE_DESIGN" = "true" ] && DESIGN_ARGS+=(--force)

# A use-case whose design is already complete has nothing left to design: the
# session re-grounds (spending credits), commits nothing, and exits non-zero.
# Skip those unless a redesign was asked for. `cover gaps` only reads the local
# graph — no model call. If it fails or its shape changes, COMPLETE stays empty
# and every use-case is designed exactly as before.
COMPLETE=()
if [ "$FORCE_DESIGN" != "true" ]; then
  mapfile -t COMPLETE < <(kane-cli cover gaps --stage design --json 2>/dev/null \
    | jq -r '.usecases[]? | select(.design_completeness.status == "complete" and (.stale_acs // 0) == 0) | .id' 2>/dev/null \
    || true)
fi

SKIPPED=(); PAUSED=(); FAILED=()
for uc in "${USECASES[@]}"; do
  if [[ " ${COMPLETE[*]} " == *" ${uc} "* ]]; then
    echo "Skipping ${uc}: its design is already complete (run with force_design to redesign)."
    SKIPPED+=("$uc")
    continue
  fi
  step "    designing ${uc}"
  code=0
  run_assurance "design tests (${uc})" \
    kane-cli design tests --use-case "$uc" "${DESIGN_ARGS[@]}" || code=$?
  case "$code" in
    0) ;;
    3) PAUSED+=("$uc") ;;
    *) FAILED+=("$uc") ;;
  esac
done
echo "Design: $(( ${#USECASES[@]} - ${#SKIPPED[@]} - ${#PAUSED[@]} - ${#FAILED[@]} )) designed," \
     "${#SKIPPED[@]} already complete, ${#PAUSED[@]} paused, ${#FAILED[@]} failed."

# ---------------------------------------------------------------------------
step "5/5  Verify the commit chain and report what was produced"
# fsck proves the graph is internally consistent — the audit story for the buyer.
kane-cli context fsck || echo "::warning::context fsck reported drift; see the log."

# A designed test lives twice: as a node in the graph and as a *_test.md file
# carrying `assurance: id:` in its frontmatter. The graph is cached between runs;
# the files are only there if committed. A use-case skipped above therefore runs
# its tests only if their files are in the repo — say so instead of quietly
# running a smaller suite.
mapfile -t GRAPH_TESTS < <(kane-cli context list --json 2>/dev/null \
  | jq -r 'select(.label == "test") | .id' 2>/dev/null || true)
ON_DISK=" $( { find .testmuai/tests -name '*_test.md' -exec awk '
    FNR == 1 { fm = 0; blk = "" }
    { sub(/\r$/, "") }
    /^---[[:space:]]*$/ { fm++; next }
    fm == 1 && /^[^[:space:]]/ { blk = $1 }
    fm == 1 && blk == "assurance:" && $1 == "id:" { print $2 }
  ' {} + 2>/dev/null || true; } | tr '\n' ' ') "
MISSING=()
for t in "${GRAPH_TESTS[@]}"; do
  [[ "$ON_DISK" == *" ${t} "* ]] || MISSING+=("$t")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "::warning title=Designed tests not on disk::${#MISSING[@]} test(s) in the graph have no *_test.md in this checkout and will not run: ${MISSING[*]}. Commit .testmuai/tests/ from the run that designed them, or redesign with force_design."
fi

# `|| true`: with pipefail a missing tests dir would otherwise abort here, before
# the outputs and the "No tests designed" error below.
TEST_COUNT=$( { find .testmuai/tests -name '*_test.md' 2>/dev/null || true; } | wc -l | tr -d ' ')
echo "Designed test files on disk: ${TEST_COUNT}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "usecase_count=${#USECASES[@]}"
    echo "test_count=${TEST_COUNT}"
  } >> "$GITHUB_OUTPUT"
fi

if [ "$TEST_COUNT" -eq 0 ]; then
  echo "::error title=No tests designed::Design produced no *_test.md files."
  exit 1
fi

# Every use-case has had its turn and the outputs above are written; a design
# failure still fails the stage, as it always has.
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "::error title=Design failed::${#FAILED[@]} use-case(s) failed to design: ${FAILED[*]}."
  exit 1
fi
