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
#   2  auth / infra problem
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

# Wrapper that treats exit 3 as "paused", not "failed".
run_assurance() {
  local label="$1"; shift
  set +e
  "$@"
  local code=$?
  set -e
  case "$code" in
    0) return 0 ;;
    3)
      echo "::warning title=Assurance paused::${label} paused with an open question."
      echo "PAUSED_STAGE=${label}" >> "${GITHUB_ENV:-/dev/null}"
      kane-cli context sessions || true
      return 3
      ;;
    2)
      echo "::error title=Auth/infra::${label} could not reach TestMu AI. Check LT_USERNAME / LT_ACCESS_KEY."
      exit 2
      ;;
    *)
      echo "::error title=Assurance failed::${label} exited ${code}."
      exit "$code"
      ;;
  esac
}

# ---------------------------------------------------------------------------
step "1/5  Ingest requirement sources into the context graph"
# --mode ci lands the sources without pulling us into the extract chat.
# shellcheck disable=SC2086
kane-cli context ingest $REQ_GLOB --mode ci

# ---------------------------------------------------------------------------
step "2/5  Extract use-cases from the ingested sources"
run_assurance "context extract" kane-cli context extract --mode ci || true

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

for uc in "${USECASES[@]}"; do
  step "    designing ${uc}"
  run_assurance "design tests (${uc})" \
    kane-cli design tests --use-case "$uc" "${DESIGN_ARGS[@]}" || true
done

# ---------------------------------------------------------------------------
step "5/5  Verify the commit chain and report what was produced"
# fsck proves the graph is internally consistent — the audit story for the buyer.
kane-cli context fsck || echo "::warning::context fsck reported drift; see the log."

TEST_COUNT=$(find .testmuai/tests -name '*_test.md' 2>/dev/null | wc -l | tr -d ' ')
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
