#!/bin/sh
trap 'rm -f "$0"' EXIT

FULL_NAME="$1"
AUTHOR="$2"

if [ -z "$FULL_NAME" ] || [ -z "$AUTHOR" ]; then
    echo "Usage: $0 \"Addon Name\" \"Author\"" >&2
    exit 1
fi

case "$FULL_NAME" in
    */*|*\\*)
        echo "Addon name must not contain path separators." >&2
        exit 1
        ;;
esac

INTERFACE_VERSION_REPLACE_STRING="INTERFACE_VERSION"
FULL_NAME_REPLACE_STRING="FULL_NAME"
CODE_NAME_REPLACE_STRING="CODE_NAME"
PACKAGE_NAME_REPLACE_STRING="PACKAGE_NAME"
AUTHOR_REPLACE_STRING="AUTHOR"

# Fetch the latest interface version from the provided URL
INTERFACE_PAGE=$(curl -fsSL --connect-timeout 10 --max-time 30 \
    "https://warcraft.wiki.gg/wiki/Template:API_LatestInterface") || {
    echo "Failed to fetch the interface version." >&2
    exit 1
}
INTERFACE_VERSION=$(printf '%s\n' "$INTERFACE_PAGE" |
    sed -n \
        -e 's/.*<meta name="description" content="\([0-9][0-9]*\).*/\1/p' \
        -e 's/.*<li><code>\([0-9][0-9]*\)<\/code>.*/\1/p' | head -1)

if [ -z "$INTERFACE_VERSION" ]; then
    echo "Failed to fetch the interface version."
    exit 1
fi

# Use to sanitize strings for use in sed replacement patterns.
sanitize() {
    printf '%s\n' "$1" | sed 's/[\/&]/\\&/g'
}

CODE_NAME=$(printf '%s\n' "$FULL_NAME" | tr -d " '")

PACKAGE_NAME=$(basename "$PWD")

# Replace the placeholder strings in the source files.
find ./src -type f -name "*.lua" -exec sed -i "s/$CODE_NAME_REPLACE_STRING/$(sanitize "$CODE_NAME")/g" {} +

# Update the .toc file with the new names and interface version.
if [ -f "TOC_FILE.toc" ]; then
    sed -i "s/$INTERFACE_VERSION_REPLACE_STRING/$(sanitize "$INTERFACE_VERSION")/g" "TOC_FILE.toc"
    sed -i "s/$FULL_NAME_REPLACE_STRING/$(sanitize "$FULL_NAME")/g" "TOC_FILE.toc"
    sed -i "s/$CODE_NAME_REPLACE_STRING/$(sanitize "$CODE_NAME")/g" "TOC_FILE.toc"
    sed -i "s/$PACKAGE_NAME_REPLACE_STRING/$(sanitize "$PACKAGE_NAME")/g" "TOC_FILE.toc"
    sed -i "s/$AUTHOR_REPLACE_STRING/$(sanitize "$AUTHOR")/g" "TOC_FILE.toc"
fi

# Rename the TOC file if it exists.
if [ -f "TOC_FILE.toc" ]; then
    mv "TOC_FILE.toc" "$PACKAGE_NAME.toc" || exit 1
fi

if [ -f ".pkgmeta" ]; then
    sed -i "s/^package-as:.*/package-as: $(sanitize "$PACKAGE_NAME")/" ".pkgmeta"
fi

mkdir -p libs

# Fetch every external listed in .pkgmeta, including commented-out ones.
if [ -f ".pkgmeta" ]; then
    if ! command -v svn >/dev/null 2>&1; then
        echo "svn is required to fetch the libraries but was not found." >&2
        exit 1
    fi
    sed -n 's/^[[:space:]]*#*[[:space:]]*\(\(libs\/\)\{0,1\}[A-Za-z0-9._-]*\):[[:space:]]*\(https\{0,1\}:\/\/[^[:space:]]*\).*/\1 \3/p' ".pkgmeta" |
    while read -r LIB_PATH LIB_URL; do
        LIB_DIR="libs/${LIB_PATH#libs/}"
        echo "Fetching $LIB_DIR from $LIB_URL"
        rm -rf "$LIB_DIR"
        svn export --force -q "$LIB_URL" "$LIB_DIR" || echo "Failed to fetch $LIB_DIR" >&2
    done
fi

echo "Auto boiler plate and libs fetching complete. Uncomment the workflows to enable CI/CD."
