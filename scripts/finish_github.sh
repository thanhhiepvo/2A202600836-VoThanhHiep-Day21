#!/usr/bin/env bash
# Finish GitHub setup: push workflow + set secrets
# Usage: GITHUB_TOKEN=ghp_xxx ./scripts/finish_github.sh

set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: Set GITHUB_TOKEN with repo + workflow scopes"
  echo "Create at: https://github.com/settings/tokens/new?scopes=repo,workflow"
  exit 1
fi

export BUCKET="${BUCKET:-mlops-vothanhhiep-744815815163}"
export EC2_IP="${EC2_IP:-100.54.217.84}"
export AWS_KEY="$(aws configure get aws_access_key_id)"
export AWS_SECRET="$(aws configure get aws_secret_access_key)"
export REPO="thanhhiepvo/2A202600836-VoThanhHiep-Day21"

python3 << 'PYEOF'
import base64, json, os, subprocess, urllib.error, urllib.request

token = os.environ["GITHUB_TOKEN"]
repo = os.environ["REPO"]
owner, name = repo.split("/")
workflow_path = ".github/workflows/mlops.yml"

with open(workflow_path, "rb") as f:
    content_b64 = base64.b64encode(f.read()).decode()

sha = None
get_url = f"https://api.github.com/repos/{owner}/{name}/contents/{workflow_path}"
req = urllib.request.Request(
    get_url,
    headers={
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "mlops-lab",
    },
)
try:
    with urllib.request.urlopen(req) as resp:
        sha = json.load(resp).get("sha")
except urllib.error.HTTPError as e:
    if e.code != 404:
        raise

payload = {
    "message": "feat: add AWS CI/CD workflow",
    "content": content_b64,
    "branch": "master",
}
if sha:
    payload["sha"] = sha

put_req = urllib.request.Request(
    get_url,
    data=json.dumps(payload).encode(),
    headers={
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "mlops-lab",
    },
    method="PUT",
)
with urllib.request.urlopen(put_req) as resp:
    print(f"Workflow pushed (HTTP {resp.status}).")
PYEOF

if command -v gh >/dev/null; then
  echo "$GITHUB_TOKEN" | gh auth login --with-token
  CREDS=$(python3 -c "import json, os; print(json.dumps({'aws_access_key_id': os.environ['AWS_KEY'], 'aws_secret_access_key': os.environ['AWS_SECRET']}))")
  gh secret set CLOUD_CREDENTIALS --body "$CREDS" --repo "$REPO"
  gh secret set CLOUD_BUCKET --body "$BUCKET" --repo "$REPO"
  gh secret set VM_HOST --body "$EC2_IP" --repo "$REPO"
  gh secret set VM_USER --body "ubuntu" --repo "$REPO"
  gh secret set VM_SSH_KEY < ~/.ssh/mlops_deploy --repo "$REPO"
  echo "Secrets configured."
  gh workflow run mlops.yml --repo "$REPO"
  echo "Pipeline triggered. Check: https://github.com/$REPO/actions"
else
  echo "gh CLI not found. Set secrets manually in GitHub Settings > Secrets."
fi
