#!/bin/bash

# Script para push a bitbucket

set -euo pipefail

source_branch="feature/karibu-mirror"
target_branch="master"
source_repo_dir="${SOURCE_REPO_DIR}"
mirror_subdir="${MIRROR_SUBDIR}"

commit_message=$( git -C "$source_repo_dir" log -1 --pretty=%s 2>/dev/null || git log -1 --pretty=%s )

# Actualizar referencias remotas primero
git fetch --prune --tags origin

# Verificar si la rama existe remotamente usando ls-remote (más confiable)
if git ls-remote --exit-code --heads origin "$source_branch" >/dev/null 2>&1; then
    echo "Branch $source_branch exists remotely"
    # Cambiar a la rama existente
    git checkout "$source_branch"
    # Hacer pull para obtener los últimos cambios
    git pull --ff-only origin "$source_branch" || true
else
    echo "Branch $source_branch does not exist remotely, creating it"
    # Crear la rama desde master (los archivos ya están en staging)
    git checkout -b "$source_branch"
fi

# Sincronizar contenido del repo de GitHub al subdirectorio espejo
mkdir -p "$mirror_subdir"
echo "Sincronizando contenido del repo de GitHub desde $source_repo_dir al subdirectorio espejo $mirror_subdir"
rsync -av --delete \
  --exclude='.git' \
  --exclude='bitbucket-repo' \
  --exclude='.github' \
  --exclude='scripts/push_to_mirror.sh' \
  --exclude='test' \
  --exclude='.env' \
  --exclude='.terraform' \
  --exclude='.terraform.lock.hcl' \
  --exclude='.terraform.tfstate' \
  --exclude='.terraform.tfstate.backup' \
  --exclude='terraform.tfstate' \
  --exclude='terraform.tfstate.backup' \
  --exclude='terraform.tfvars' \
  "$source_repo_dir"/ "$mirror_subdir"/

git add --all "$mirror_subdir"

created_commit=false
# Commit changes
if ! git diff --cached --quiet; then
    git commit -m "feat: Mirror from GitHub: $commit_message"
    created_commit=true
else
    echo "No staged changes to commit"
fi
# Push to bitbucket (usar -u para crear la rama remota si no existe)
git push -u origin "$source_branch"

# Espejar tags de GitHub en Bitbucket (mismo nombre, sin kli semver).
git -C "$source_repo_dir" fetch --tags origin 2>/dev/null || git -C "$source_repo_dir" fetch --tags 2>/dev/null || true
source_sha=$(git -C "$source_repo_dir" rev-parse HEAD)
mapfile -t github_tags < <(git -C "$source_repo_dir" tag -l 'v*' --points-at "$source_sha" | sort -V)

if [ "${#github_tags[@]}" -eq 0 ]; then
    echo "No GitHub tags point at synced commit $source_sha; skipping tag mirror"
else
    for github_tag in "${github_tags[@]}"; do
        if git ls-remote --exit-code --tags origin "refs/tags/${github_tag}" >/dev/null 2>&1; then
            echo "Tag $github_tag already exists on Bitbucket, skipping"
            continue
        fi
        echo "Mirroring GitHub tag $github_tag to Bitbucket at current commit"
        git tag "$github_tag"
        git push origin "refs/tags/$github_tag"
    done
fi
# Create a pull request to Bitbucket
if [ "$created_commit" = true ]; then
    pr_payload=$(COMMIT_MESSAGE="$commit_message" SOURCE_BRANCH="$source_branch" TARGET_BRANCH="$target_branch" python3 -c 'import json, os; print(json.dumps({"title": "Mirror from GitHub", "description": "Mirror from GitHub: " + os.environ["COMMIT_MESSAGE"], "source": {"branch": {"name": os.environ["SOURCE_BRANCH"]}}, "destination": {"branch": {"name": os.environ["TARGET_BRANCH"]}}, "close_source_branch": True}))')
    curl -i -X POST \
      -u "$BITBUCKET_USER_EMAIL:$BITBUCKET_API_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$pr_payload" \
      "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE_CLARO/$BITBUCKET_REPO_NAME_CLARO/pullrequests"
else
    echo "No new commit was created, skipping pull request creation"
fi
