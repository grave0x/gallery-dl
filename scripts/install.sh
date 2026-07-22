#!/bin/bash
set -e

# gallery-dl install script
#
# Installs gallery-dl from the local source tree.
#
# Usage:
#   ./scripts/install.sh                 # install for current user
#   ./scripts/install.sh --user          # same as above
#   ./scripts/install.sh --system        # system-wide install (may need sudo)
#   ./scripts/install.sh -e, --editable  # development install (editable)
#   ./scripts/install.sh --help          # show this help
#
# Environment variables:
#   PYTHON   python interpreter to use (default: python3)
#   PIP      pip command (default: auto-detected)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

PYTHON="${PYTHON:-python3}"

# Resolve a working pip / installer command for the selected PYTHON.
# Prefers:
#   1. Explicit $PIP
#   2. $PYTHON -m pip (if available)
#   3. uv pip (if uv is installed and python lacks pip)
#   4. pip3 / pip on PATH
resolve_pip() {
    local py="$1"

    # 1. Respect explicit PIP override
    if [ -n "${PIP:-}" ]; then
        echo "$PIP"
        return 0
    fi

    # 2. Standard python -m pip
    if "$py" -m pip --version >/dev/null 2>&1; then
        echo "$py -m pip"
        return 0
    fi

    # 3. uv (common in environments where python has no pip module)
    if command -v uv >/dev/null 2>&1; then
        echo "uv pip"
        return 0
    fi

    # 4. Fallback to pip3/pip on PATH
    if command -v pip3 >/dev/null 2>&1; then
        echo "pip3"
        return 0
    fi
    if command -v pip >/dev/null 2>&1; then
        echo "pip"
        return 0
    fi

    return 1
}

PIP="$(resolve_pip "$PYTHON")"
if [ -z "$PIP" ]; then
    echo "Error: Could not find a working pip for $PYTHON" >&2
    echo "Set the PIP or PYTHON environment variable, or install pip/uv." >&2
    echo "Examples:" >&2
    echo "  PIP='uv pip' $0" >&2
    echo "  PYTHON=/usr/bin/python3 $0" >&2
    echo "  uv pip install -e ." >&2
    exit 1
fi

# Detect if we are using uv (affects flag handling)
case "$PIP" in
    uv\ pip*) USING_UV=1 ;;
    *)        USING_UV=0 ;;
esac

# Inform when falling back to uv because the python lacks pip
if [[ $USING_UV -eq 1 ]] && ! "$PYTHON" -m pip --version >/dev/null 2>&1; then
    echo "Note: $PYTHON has no pip module; using 'uv pip' instead."
fi

cd "$ROOT_DIR"

show_help() {
    awk '
        /^# gallery-dl/ { printing=1 }
        printing && /^$/ { exit }
        printing && /^#/ { sub(/^# ?/, ""); print }
    ' "$0"
    exit 0
}

# Parse arguments
EDITABLE=""
PIP_ARGS=()
USER_INSTALL=1   # default to --user for safety

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--editable)
            EDITABLE="-e"
            shift
            ;;
        --user)
            USER_INSTALL=1
            shift
            ;;
        --system)
            USER_INSTALL=0
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            PIP_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ $USER_INSTALL -eq 1 && $USING_UV -eq 0 ]]; then
    # --user is not valid / has different semantics with uv pip
    PIP_ARGS+=("--user")
fi

# Try to generate man pages and shell completions (best effort)
if command -v make >/dev/null 2>&1; then
    echo "Generating man pages and shell completions..."
    if ! make man completion >/dev/null 2>&1; then
        echo "Warning: Could not generate auxiliary files."
        echo "         Run 'make' manually before installing for full documentation."
    fi
else
    echo "Note: 'make' not found. Man pages and completions will not be installed."
    echo "      Install the package normally with pip if you need them."
fi

echo "Installing gallery-dl..."

if [[ $USING_UV -eq 1 ]]; then
    # uv manages its own pip/setuptools; do not attempt to upgrade them this way.
    # Target the selected python explicitly.
    $PIP install --python "$PYTHON" $EDITABLE "${PIP_ARGS[@]}" . || {
        echo "Error: Installation failed." >&2
        exit 1
    }
else
    # Best-effort upgrade of build tools (may be skipped or fail in managed envs)
    $PIP install --upgrade pip setuptools wheel 2>/dev/null || true
    $PIP install $EDITABLE "${PIP_ARGS[@]}" . || {
        echo "Error: Installation failed." >&2
        exit 1
    }
fi

echo
echo "Installation complete."
echo "Verify with: gallery-dl --version"
