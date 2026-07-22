#!/bin/bash
set -e

# gallery-dl package build + install script
#
# Builds a source distribution (sdist) and wheel using 'python -m build',
# then installs the resulting wheel (or sdist) from dist/.
#
# This verifies that the packaged distribution installs and works correctly,
# unlike 'pip install .' which installs directly from the source tree.
#
# Usage:
#   ./scripts/package-build+install.sh                 # build + install wheel for current user
#   ./scripts/package-build+install.sh --user          # same as above
#   ./scripts/package-build+install.sh --system        # system-wide install (may need sudo)
#   ./scripts/package-build+install.sh --sdist         # install the sdist instead of the wheel
#   ./scripts/package-build+install.sh --clean         # remove dist/ and build/ before building
#   ./scripts/package-build+install.sh --help          # show this help
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
        /^# gallery-dl package build/ { printing=1 }
        printing && /^$/ { exit }
        printing && /^#/ { sub(/^# ?/, ""); print }
    ' "$0"
    exit 0
}

# Parse arguments
INSTALL_SDIST=0
DO_CLEAN=0
PIP_ARGS=()
USER_INSTALL=1   # default to --user for safety

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sdist)
            INSTALL_SDIST=1
            shift
            ;;
        --clean)
            DO_CLEAN=1
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

# Optional clean
if [[ $DO_CLEAN -eq 1 ]]; then
    echo "Cleaning dist/ and build/ ..."
    rm -rf dist/ build/
fi

# Ensure build frontend is available
if ! "$PYTHON" -c "import build" >/dev/null 2>&1; then
    echo "Installing 'build' package (required for python -m build)..."
    if [[ $USING_UV -eq 1 ]]; then
        $PIP install --python "$PYTHON" build || {
            echo "Error: Failed to install the 'build' package." >&2
            exit 1
        }
    else
        $PIP install --upgrade build || {
            echo "Error: Failed to install the 'build' package." >&2
            exit 1
        }
    fi
fi

echo "Building sdist and wheel..."
"$PYTHON" -m build

# Select artifact to install
if [[ $INSTALL_SDIST -eq 1 ]]; then
    # Find the newest sdist (.tar.gz)
    ARTIFACT="$(ls -1t dist/gallery_dl-*.tar.gz 2>/dev/null | head -n 1 || true)"
    ARTIFACT_TYPE="sdist"
else
    # Prefer wheel
    ARTIFACT="$(ls -1t dist/gallery_dl-*.whl 2>/dev/null | head -n 1 || true)"
    ARTIFACT_TYPE="wheel"
fi

if [[ -z "$ARTIFACT" ]]; then
    echo "Error: No $ARTIFACT_TYPE found in dist/ after build." >&2
    echo "Contents of dist/:" >&2
    ls -la dist/ 2>/dev/null || echo "(dist/ is empty or missing)" >&2
    exit 1
fi

echo "Installing $ARTIFACT_TYPE: $ARTIFACT"

if [[ $USING_UV -eq 1 ]]; then
    $PIP install --python "$PYTHON" --force-reinstall "${PIP_ARGS[@]}" "$ARTIFACT" || {
        echo "Error: Installation failed." >&2
        exit 1
    }
else
    $PIP install --force-reinstall "${PIP_ARGS[@]}" "$ARTIFACT" || {
        echo "Error: Installation failed." >&2
        exit 1
    }
fi

echo
echo "Package build + install complete."
echo "Installed: $(basename "$ARTIFACT")"
echo "Verify with: gallery-dl --version"
