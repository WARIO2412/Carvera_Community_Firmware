#!/usr/bin/env bash

# mri/gdb.sh
# Helper script to launch arm‑none‑eabi‑gdb against a Carvera running MRI.
#
# Behaviour:
# 1. Locates a suitable arm‑none‑eabi‑gdb (prefers newest version).
# 2. Determines a serial port if none supplied.
# 3. Selects a sensible default baud rate.
# 4. Execs GDB with init.gdb and sets $PORT within GDB without disturbing shell quoting.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"

######################################################################
# Locate a suitable arm‑none‑eabi‑gdb
######################################################################

candidates=()

# 1) Already in PATH?
if command -v arm-none-eabi-gdb >/dev/null 2>&1; then
    candidates+=("$(command -v arm-none-eabi-gdb)")
fi

# 2) Search inside the project for */bin/arm-none-eabi-gdb
while IFS= read -r -d '' f; do
    candidates+=("$f")
    # shellcheck disable=SC2086 # we need word splitting for find -path glob
done < <(find "$PROJECT_ROOT" -type f -path '*/bin/arm-none-eabi-gdb' -print0 2>/dev/null || true)

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "Error: arm-none-eabi-gdb not found in PATH or project tree." >&2
    exit 1
fi

# If more than one candidate, pick the one with the highest version according to `-v` output.
select_gdb() {
    extract_ver() {
        local out="$($1 -v 2>&1 | head -n1)"
        grep -oE '[0-9]+(\.[0-9]+)+' <<< "$out" | head -n1 || echo "0.0"
    }

    # Build a list of "version path" then sort by version
    local chosen
    chosen="$(for p in "${candidates[@]}"; do
        printf '%s %s\n' "$(extract_ver "$p")" "$p"
    done | sort -k1 -V | tail -n1 | cut -d' ' -f2-)"

    echo "$chosen"
}

GDB="$(select_gdb)"

if [[ -z "$GDB" ]]; then
    echo "Error: Failed to select a usable arm-none-eabi-gdb." >&2
    exit 1
fi

######################################################################
# Verify ELF binary exists
######################################################################

ELF_FILE="$PROJECT_ROOT/LPC1768/main.elf"
if [[ ! -f "$ELF_FILE" ]]; then
    echo "Error: Firmware ELF binary not found at $ELF_FILE. Build the firmware first." >&2
    exit 1
fi

######################################################################
# Select serial port (if not provided)
######################################################################

PORT="${1:-}"
if [[ -z "$PORT" ]]; then
    uname_out="$(uname -s)"
    case "${uname_out}" in
        Darwin)
            # Prefer cu.* usb serial devices, avoiding Bluetooth.
            for dev in /dev/cu.usbserial*; do
                [[ -e "$dev" ]] || continue
                [[ "$dev" == *Bluetooth* ]] && continue
                PORT="$dev"
                break
            done
            ;;
        Linux)
            for pattern in /dev/ttyACM* /dev/ttyUSB*; do
                for dev in $pattern; do
                    [[ -e "$dev" ]] || continue
                    PORT="$dev"
                    break 2
                done
            done
            ;;
    esac
fi

if [[ -z "$PORT" ]]; then
    echo "Error: Unable to determine a serial port automatically. Please provide one." >&2
    echo "Usage: $0 [serial_port] [baud]" >&2
    exit 1
fi

######################################################################
# Baud rate
######################################################################

BAUD="${2:-115200}"

######################################################################
# Launch GDB
######################################################################

exec "$GDB" -b "$BAUD" -x "$SCRIPT_DIR/init.gdb" -ex "target remote $PORT" "$ELF_FILE"
