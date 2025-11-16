#!/bin/sh
# Safe rstrip wrapper for OpenWrt packaging (POSIX sh compatible)
# Only attempt to strip ELF "executable" files.
# Skip:
#  - *.so, *.so.*, *.ko
#  - file types containing "shared object" or "relocatable"

LOG="/tmp/rstrip-debug.log"
: "${STRIP:=/usr/bin/strip}"

log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
}

is_strippable() {
    f="$1"
    [ -e "$f" ] || return 1

    case "$f" in
        *.so|*.so.*|*.ko) return 1 ;;
    esac

    ft=$(file -L "$f" 2>/dev/null) || return 1

    # Log for diagnostics
    log "file -L for '$f': $ft"

    # must be ELF and an executable; reject shared object or relocatable
    echo "$ft" | grep -q 'ELF' || return 1
    echo "$ft" | grep -qi 'executable' || return 1
    echo "$ft" | grep -qi 'shared object' && return 1
    echo "$ft" | grep -qi 'relocatable' && return 1

    return 0
}

process_file() {
    f="$1"
    if is_strippable "$f"; then
        log "stripping: $f"
        # call specified STRIP if available, else try strip
        bn=$(basename "$STRIP" 2>/dev/null || true)
        if [ -n "$bn" ] && command -v "$bn" >/dev/null 2>&1; then
            "$STRIP" "$f" 2>>"$LOG" || log "warning: $STRIP failed for $f"
        elif command -v strip >/dev/null 2>&1; then
            strip -s "$f" 2>>"$LOG" || log "warning: strip -s failed for $f"
        else
            log "warning: no strip available for $f"
        fi
    else
        log "skip (not strippable): $f"
    fi
}

# Invocation: either args or stdin list
log "---------------------------------------------------------------------------"
log "Called as: $0 $*"
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
log "Done"
