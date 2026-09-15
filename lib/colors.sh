#!/usr/bin/env bash
# Saída colorida do Forge.
# Desabilitada automaticamente quando stdout não é um terminal ou quando NO_COLOR está definido.

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_GREEN='\033[0;32m'
    C_RED='\033[0;31m'
    C_YELLOW='\033[0;33m'
else
    C_RESET=''
    C_BOLD=''
    C_GREEN=''
    C_RED=''
    C_YELLOW=''
fi
readonly C_RESET C_BOLD C_GREEN C_RED C_YELLOW

forge::ok() {
    printf '  %b✔%b %s\n' "$C_GREEN" "$C_RESET" "$1"
}

forge::err() {
    printf '%bError:%b %s\n' "$C_RED" "$C_RESET" "$1" >&2
}

forge::warn() {
    printf '%bWarning:%b %s\n' "$C_YELLOW" "$C_RESET" "$1" >&2
}

forge::info() {
    printf '%s\n' "$1"
}

forge::title() {
    printf '%b%s%b\n' "$C_BOLD" "$1" "$C_RESET"
}
