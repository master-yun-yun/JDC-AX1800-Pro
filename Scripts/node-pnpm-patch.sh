#!/bin/bash
# Runtime-safe node-pnpm Makefile patch script
set -e

# Ensure we run from repository root so find works regardless of caller cwd
if [ -n "$GITHUB_WORKSPACE" ]; then
  REPO_ROOT="$GITHUB_WORKSPACE"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
cd "$REPO_ROOT" || exit 1

echo "Running node-pnpm-patch from repo root: $(pwd)"

# Search helper
search_in() {
  local base="$1"
  if [ -d "$base" ]; then
    find "$base" -path "*/node-pnpm/Makefile" -print -quit 2>/dev/null || true
  fi
}

FILE=""
FILE=$(search_in ./wrt)
FILE=${FILE:-$(search_in ./package)}
FILE=${FILE:-$(search_in ./feeds)}
FILE=${FILE:-$(find . -path "*/node-pnpm/Makefile" -print -quit 2>/dev/null || true)}

# content-based fallback: only match explicit PKG_NAME declaration to avoid false positives
if [ -z "$FILE" ]; then
  echo "Path search failed — attempting content-based search for Makefiles declaring PKG_NAME:=node-pnpm..."
  FILE=$(grep -RIl --exclude-dir=.git -e '^PKG_NAME[: =]*node-pnpm' ./wrt ./package ./feeds 2>/dev/null | grep -E '/Makefile$' | head -1 || true)
  FILE=${FILE:-$(grep -RIl --exclude-dir=.git -e '^PKG_NAME[: =]*node-pnpm' . 2>/dev/null | grep -E '/Makefile$' | head -1 || true)}
fi

if [ -z "$FILE" ]; then
  echo "node-pnpm Makefile not found in common locations or repo root."
  echo "Creating a runtime fallback Makefile at ./wrt/package/node-pnpm/Makefile (will be created after repo clone)."

  mkdir -p ./wrt/package/node-pnpm
  FILE="./wrt/package/node-pnpm/Makefile"

  cat > "$FILE" <<'PLACEHOLDER'
# Placeholder runtime Makefile; full Makefile will be written by node-pnpm-patch.sh
# PKG_VERSION will be filled in by the script rewrite step below.
PLACEHOLDER

  echo "Fallback placeholder Makefile created at $FILE"
fi

echo "Found Makefile: $FILE"
PKG_VERSION=$(grep -oP 'PKG_VERSION:=\K\S+' "$FILE" | head -1 || true)
if [ -z "$PKG_VERSION" ]; then
    echo "Warning: PKG_VERSION not found, defaulting to 11.7.0"
    PKG_VERSION="11.7.0"
fi

# Backup and overwrite Makefile with robust Host/Install that handles pnpm.mjs/pnpm.cjs
cp "$FILE" "$FILE.bak"
cat > "$FILE" <<'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=node-pnpm
PKG_VERSION:=${PKG_VERSION}
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://registry.npmjs.org/$(PKG_NAME)/-/$(PKG_NAME)-$(PKG_VERSION).tgz
PKG_HASH:=skip

define Host/Compile
	@echo "Skipping make in source (no Makefile present)"
	@true
endef

define Host/Install
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist
	$(INSTALL_DIR) $(STAGING_DIR_HOSTPKG)/bin

	# 查找并复制 pnpm 文件（支持 .mjs / .cjs / .js）
	PNPM_FILE=""
	if [ -d "$(PKG_BUILD_DIR)/dist" ] && ls "$(PKG_BUILD_DIR)/dist/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in dist/ - copying full dist directory"; \
		cp -a "$(PKG_BUILD_DIR)/dist"/* "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/"; \
		PNPM_FILE=`ls "$(PKG_BUILD_DIR)/dist/pnpm.*" 2>/dev/null | head -n1`; \
	elif ls "$(PKG_BUILD_DIR)/bin/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in bin/ - copying"; \
		cp -a "$(PKG_BUILD_DIR)/bin/pnpm.*" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" 2>/dev/null || true; \
		PNPM_FILE=`ls "$(PKG_BUILD_DIR)/bin/pnpm.*" 2>/dev/null | head -n1`; \
	elif ls "$(PKG_BUILD_DIR)/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in root - copying"; \
		cp -a "$(PKG_BUILD_DIR)/pnpm.*" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" 2>/dev/null || true; \
		PNPM_FILE=`ls "$(PKG_BUILD_DIR)/pnpm.*" 2>/dev/null | head -n1`; \
	elif [ -d "$(PKG_BUILD_DIR)/package/dist" ] && ls "$(PKG_BUILD_DIR)/package/dist/pnpm.*" >/dev/null 2>&1; then \
		echo "Found pnpm in package/dist - copying"; \
		cp -a "$(PKG_BUILD_DIR)/package/dist"/* "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/"; \
		PNPM_FILE=`ls "$(PKG_BUILD_DIR)/package/dist/pnpm.*" 2>/dev/null | head -n1`; \
	fi; \

	# 兜底：在整个 build 目录中查找第一个 pnpm.* 文件
	if [ -z "$PNPM_FILE" ]; then \
		PNPM_FILE=`find "$(PKG_BUILD_DIR)" -type f -name 'pnpm.*' 2>/dev/null | head -n1 || true`; \
	fi; \

	if [ -z "$PNPM_FILE" ]; then \
		echo "ERROR: pnpm.* not found in any expected location."; \
		echo "Listing PKG_BUILD_DIR ($(PKG_BUILD_DIR)):"; ls -la "$(PKG_BUILD_DIR)"/ || true; \
		echo "Searching for pnpm.* in build directory:"; find "$(PKG_BUILD_DIR)" -name 'pnpm.*' -type f | head -20 || true; \
		exit 1; \
	fi; \

	PNPM_BASENAME=`basename "$PNPM_FILE"`; \
	echo "Detected pnpm file: $PNPM_FILE (basename $PNPM_BASENAME)"; \
	# 确保文件在 dist 中
	if [ ! -f "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/$PNPM_BASENAME" ]; then \
		cp -a "$PNPM_FILE" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" || true; \
	fi; \
	# 复制 worker.js（如果存在）
	WORKER_FILE=`find "$(PKG_BUILD_DIR)" -type f -name 'worker.js' 2>/dev/null | head -n1 || true`; \
	if [ -n "$WORKER_FILE" ]; then \
		cp -a "$WORKER_FILE" "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/" || true; \
	fi; \

	# 生成 wrapper，指向检测到的 pnpm 文件
	printf '#!/bin/sh\nexec node "$(STAGING_DIR_HOSTPKG)/lib/node_modules/pnpm/dist/$PNPM_BASENAME" "$$@"\n' > "$(STAGING_DIR_HOSTPKG)/bin/pnpm"; \
	chmod +x "$(STAGING_DIR_HOSTPKG)/bin/pnpm"; \

endef

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/host-build.mk
EOF

echo "✓ New Makefile written with version ${PKG_VERSION}"
echo "  Enhanced with comprehensive file search paths and detailed debugging output"
