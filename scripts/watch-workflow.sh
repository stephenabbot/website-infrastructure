#!/bin/bash
# scripts/watch-workflow.sh - Watch GitHub Actions workflow with timeout

set -euo pipefail

TIMEOUT=${1:-10}
RUN_ID=${2:-}

if [ -z "$RUN_ID" ]; then
  echo "Usage: $0 [timeout_seconds] [run_id]"
  echo "If run_id not provided, will use the latest run"
  exit 1
fi

echo "Watching workflow $RUN_ID for $TIMEOUT seconds..."

# Use gtimeout if available (macOS), otherwise timeout (Linux)
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
else
  echo "Warning: No timeout command available, watching indefinitely..."
  TIMEOUT_CMD=""
fi

if [ -n "$TIMEOUT_CMD" ]; then
  $TIMEOUT_CMD ${TIMEOUT}s gh run watch "$RUN_ID" 2>/dev/null || echo "Timed out after ${TIMEOUT}s"
else
  gh run watch "$RUN_ID"
fi

echo ""
echo "Current status:"
gh run view "$RUN_ID" --json status,conclusion,url --template '{{.status}} ({{.conclusion}}) - {{.url}}'
echo ""
