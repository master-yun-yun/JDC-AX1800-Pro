#!/bin/sh
# Safe rstrip wrapper for OpenWrt packaging
# Only attempt to strip ELF executables. Skip shared objects and kernel modules.

: "${STRIP:=/usr/bin/strip}"

log() { printf '%s\n' "$*"; }

is_strippable() {
    local f="$1"
    [ -e "$f" ] || return 1

    # Name-based skip: shared libraries and kernel modules
    case "$f" in
        *.so|*.so.*|*.ko) return 1 ;;
    esac

    # Follow symlinks and inspect file type
    local ft
    ft=$(file -L "$f" 2>/dev/null) || return 1

    # Only strip ELF executables (not shared objects or relocatable)
    # Accept when file output contains "ELF" and "executable"
    printf '%s' "$ft" | grep -q 'ELF' || return 1
    printf '%s' "$ft" | grep -qi 'executable' || return 1

    return 0
}

process_file() {
    local f="$1"
    if is_strippable "$f"; then
        log "stripping: $f"
        # Prefer calling STRIP (may point to sstrip); fallback to strip -s
        if [ -n "$STRIP" ] && command -v "$(basename "$STRIP")" >/dev/null 2>&1; then
            # STRIP could be full path; call it
            "$STRIP" "$f" 2>/dev/null || log "warning: $STRIP failed for $f"
        elif command -v strip >/dev/null 2>&1; then
            strip -s "$f" 2>/dev/null || log "warning: strip -s failed for $f"
        else
            log "warning: no strip available to process $f"
        fi
    else
        log "skip (not strippable): $f"
    fi
}

if [ "$#" -eq 0 ]; then
    while IFS= read -r file || [ -n "$file" ]; do
        [ -z "$file" ] && continue
        process_file "$file"
    done
else
    for file in "$@"; do
        process_file "$file"
    done
fi
