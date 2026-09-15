#!/usr/bin/env bash
# forge doctor — verifica dependências do ambiente:
#   - "core": o que o próprio forge usa internamente (sem isso, ele não funciona)
#   - "template toolchains": o que os projetos GERADOS podem precisar depois
#     (o forge cria os arquivos de qualquer forma; compilar/rodar é por conta
#     do usuário ter python3/gcc instalados)

# forge::doctor_version CMD
# Extrai major.minor da saída de versão do comando, de forma tolerante a
# diferenças de formato entre ferramentas e plataformas (GNU vs BSD, etc).
forge::doctor_version() {
    local cmd="$1"
    local raw=""

    case "$cmd" in
        bash)
            raw="$BASH_VERSION"
            ;;
        perl)
            raw="$(perl -e 'print $^V' 2>/dev/null)"
            ;;
        *)
            raw="$("$cmd" --version 2>&1 | head -n 1)"
            ;;
    esac

    printf '%s' "$raw" | grep -oE '[0-9]+\.[0-9]+' | head -n 1
}

# forge::doctor_check LABEL CMD
# Imprime uma linha de status e retorna 1 se o comando não for encontrado.
forge::doctor_check() {
    local label="$1"
    local cmd="$2"
    local version

    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf '  %-8s %bnot found%b\n' "$label" "$C_RED" "$C_RESET"
        return 1
    fi

    version="$(forge::doctor_version "$cmd")"
    if [[ -n "$version" ]]; then
        printf '  %-8s %b✔%b %s\n' "$label" "$C_GREEN" "$C_RESET" "$version"
    else
        printf '  %-8s %b✔%b\n' "$label" "$C_GREEN" "$C_RESET"
    fi
}

# forge::cmd_doctor
forge::cmd_doctor() {
    local core_ok=true

    forge::title "Project Forge — environment check"
    printf '\n'

    forge::info "Core (required by forge itself):"
    forge::doctor_check "Bash" "bash" || core_ok=false
    forge::doctor_check "Perl" "perl" || core_ok=false
    forge::doctor_check "Git"  "git"  || core_ok=false
    printf '\n'

    forge::info "Template toolchains (optional — needed to build/run generated projects):"
    forge::doctor_check "Python" "python3" || true
    forge::doctor_check "GCC"    "gcc"     || true
    forge::doctor_check "G++"   "g++"      || true
    printf '\n'

    if [[ "$core_ok" == "true" ]]; then
        forge::ok "All core dependencies are available."
        return 0
    else
        forge::err "one or more core dependencies are missing."
        printf 'forge itself will not work correctly until these are installed.\n' >&2
        return 1
    fi
}
