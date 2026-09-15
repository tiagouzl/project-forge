#!/usr/bin/env bash
# Validação de nomes de projeto/template e destino de escrita.

# forge::validate_identifier NAME LABEL
# Regra genérica: começa com letra; contém apenas letras, números, '-' ou '_'.
# Usada tanto para nome de projeto quanto de template (mesma regra, rótulo
# diferente na mensagem de erro).
forge::validate_identifier() {
    local name="${1:-}"
    local label="${2:-name}"

    if [[ -z "$name" ]]; then
        forge::err "${label} cannot be empty."
        return 1
    fi

    if [[ ! "$name" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]; then
        forge::err "invalid ${label}."
        cat >&2 <<EOF

${label^}s must:
  - start with a letter
  - contain letters, numbers, '-' or '_'
EOF
        return 1
    fi

    return 0
}

# forge::validate_project_name NAME
forge::validate_project_name() {
    forge::validate_identifier "${1:-}" "project name"
}

# forge::validate_template_name NAME
forge::validate_template_name() {
    forge::validate_identifier "${1:-}" "template name"
}

# forge::validate_template NAME BUILTIN_TEMPLATES_DIR
# Aceita tanto templates embutidos (BUILTIN_TEMPLATES_DIR) quanto templates
# customizados adicionados via `forge template add` (forge::user_templates_dir).
forge::validate_template() {
    local name="${1:-}"
    local templates_dir="$2"

    if [[ -z "$name" ]] || ! forge::resolve_template_dir "$name" "$templates_dir" >/dev/null; then
        forge::err "unknown template '${name:-<empty>}'."
        printf "\nRun 'forge list' to see available templates.\n" >&2
        return 1
    fi

    return 0
}

# forge::check_destination DEST FORCE
# FORCE deve ser a string "true" ou "false".
forge::check_destination() {
    local dest="$1"
    local force="${2:-false}"

    if [[ -e "$dest" ]] && [[ "$force" != "true" ]]; then
        forge::err "directory already exists:"
        printf '%s\n' "$dest" >&2
        printf '\nUse --force to overwrite.\n' >&2
        return 1
    fi

    return 0
}
