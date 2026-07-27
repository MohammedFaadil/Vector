#!/usr/bin/env bash
# =============================================================================
#  VECTOR: SHADOW RUNNER — one-shot setup for the gaming PC (Windows, Git Bash)
#  Downloads Godot 4.3, opens the project. Run from the project folder:
#      ./setup.sh            # download engine + launch the game (F5 in editor)
#      ./setup.sh play       # skip editor, run the game directly
#      ./setup.sh export     # build a standalone Windows .exe into build/
# =============================================================================
set -euo pipefail

GODOT_VERSION="4.3-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_win64.exe.zip"
GODOT_EXE="Godot_v${GODOT_VERSION}_win64.exe"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE_DIR="${PROJECT_DIR}/engine"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- get engine
if [ ! -f "${ENGINE_DIR}/${GODOT_EXE}" ]; then
    log "Downloading Godot ${GODOT_VERSION} (~55 MB)..."
    mkdir -p "${ENGINE_DIR}"
    curl -L --fail -o "${ENGINE_DIR}/${GODOT_ZIP}" "${GODOT_URL}"
    log "Extracting..."
    if command -v unzip >/dev/null 2>&1; then
        unzip -o "${ENGINE_DIR}/${GODOT_ZIP}" -d "${ENGINE_DIR}"
    else
        powershell.exe -NoProfile -Command \
            "Expand-Archive -Force '$(cygpath -w "${ENGINE_DIR}/${GODOT_ZIP}")' '$(cygpath -w "${ENGINE_DIR}")'"
    fi
    rm -f "${ENGINE_DIR}/${GODOT_ZIP}"
    log "Godot installed at engine/${GODOT_EXE}"
else
    log "Godot ${GODOT_VERSION} already present — skipping download."
fi

GODOT="${ENGINE_DIR}/${GODOT_EXE}"

# ------------------------------------------------------------------- actions
MODE="${1:-editor}"

case "${MODE}" in
play)
    log "Importing resources (first run only)..."
    "${GODOT}" --headless --path "${PROJECT_DIR}" --import || true
    log "Launching VECTOR: SHADOW RUNNER..."
    exec "${GODOT}" --path "${PROJECT_DIR}"
    ;;
export)
    log "Fetching export templates (~1 GB, once)..."
    TPL_DIR="${APPDATA}/Godot/export_templates/${GODOT_VERSION/-stable/.stable}"
    if [ ! -d "${TPL_DIR}" ]; then
        curl -L --fail -o "${ENGINE_DIR}/templates.tpz" "${TEMPLATES_URL}"
        mkdir -p "${TPL_DIR}"
        # A .tpz is a zip; templates live under templates/ inside it.
        if command -v unzip >/dev/null 2>&1; then
            unzip -o -j "${ENGINE_DIR}/templates.tpz" 'templates/*' -d "${TPL_DIR}"
        else
            powershell.exe -NoProfile -Command \
                "Expand-Archive -Force '$(cygpath -w "${ENGINE_DIR}/templates.tpz")' '$(cygpath -w "${ENGINE_DIR}/tpl_tmp")'"
            cp -r "${ENGINE_DIR}/tpl_tmp/templates/." "${TPL_DIR}/"
            rm -rf "${ENGINE_DIR}/tpl_tmp"
        fi
        rm -f "${ENGINE_DIR}/templates.tpz"
    fi
    log "Writing export preset..."
    cat > "${PROJECT_DIR}/export_presets.cfg" <<'EOF'
[preset.0]
name="Windows"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
export_path="build/VectorShadowRunner.exe"

[preset.0.options]
binary_format/embed_pck=true
EOF
    mkdir -p "${PROJECT_DIR}/build"
    log "Importing + exporting release build..."
    "${GODOT}" --headless --path "${PROJECT_DIR}" --import || true
    "${GODOT}" --headless --path "${PROJECT_DIR}" --export-release "Windows" "build/VectorShadowRunner.exe"
    log "Done → build/VectorShadowRunner.exe"
    ;;
editor|*)
    log "Importing resources (first run only)..."
    "${GODOT}" --headless --path "${PROJECT_DIR}" --import || true
    log "Opening the Godot editor — press F5 inside to play."
    exec "${GODOT}" --editor --path "${PROJECT_DIR}"
    ;;
esac
