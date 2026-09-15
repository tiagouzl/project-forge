#!/usr/bin/env bash
# forge template add|list|remove — templates customizados do usuário,
# guardados fora do repositório do forge em forge::user_templates_dir().
# Nunca sobrescreve um template embutido: nome de built-in é reservado.

# forge::template_is_builtin NAME BUILTIN_DIR
forge::template_is_builtin() {
    local name="$1"
    local builtin_dir="$2"
    [[ -d "$builtin_dir/$name" ]]
}

# forge::dir_has_symlinks DIR
# 0 se houver qualquer symlink na árvore — templates com symlink são
# recusados no add para não propagá-los a todo projeto gerado.
forge::dir_has_symlinks() {
    [[ -n "$(find "$1" -type l -print -quit)" ]]
}
# forge::cmd_template_add NAME SOURCE BUILTIN_DIR
# SOURCE pode ser um diretório local ou uma URL git (https://, git@ ou *.git).
forge::cmd_template_add() {
    local name="${1:-}"
    local source="${2:-}"
    local builtin_dir="$3"
    local user_dir dest

    if [[ -z "$name" ]] || [[ -z "$source" ]]; then
        forge::err "usage: forge template add <name> <path-or-git-url>"
        return 1
    fi

    forge::validate_identifier "$name" "template name" || return 1

    if forge::template_is_builtin "$name" "$builtin_dir"; then
        forge::err "'$name' is a built-in template name and cannot be overridden."
        return 1
    fi

    user_dir="$(forge::user_templates_dir)"
    dest="$user_dir/$name"

    if [[ -e "$dest" ]]; then
        forge::err "a custom template named '$name' already exists."
        printf "Run 'forge template remove %s' first.\n" "$name" >&2
        return 1
    fi

    mkdir -p "$user_dir"

    case "$source" in
        *.git|git@*|*://*)
            if ! forge::git_available; then
                forge::err "git is required to add a template from a URL."
                return 1
            fi
            if ! git clone --quiet --depth 1 "$source" "$dest" >/dev/null 2>&1; then
                forge::err "failed to clone '$source'."
                rm -rf "$dest"
                return 1
            fi
            rm -rf "$dest/.git"
            if forge::dir_has_symlinks "$dest"; then
                forge::err "template source contains symlinks — refusing to add."
                rm -rf "$dest"
                return 1
            fi
            ;;
        *)
            if [[ ! -d "$source" ]]; then
                forge::err "source directory not found: $source"
                return 1
            fi
            if forge::dir_has_symlinks "$source"; then
                forge::err "template source contains symlinks — refusing to add."
                return 1
            fi
            cp -r "$source" "$dest"
            ;;
    esac

    forge::ok "Template '$name' added ($dest)."
}

# forge::cmd_template_list
forge::cmd_template_list() {
    local user_dir dir name found=false

    user_dir="$(forge::user_templates_dir)"

    if [[ -d "$user_dir" ]]; then
        for dir in "$user_dir"/*/; do
            [[ -d "$dir" ]] || continue
            if [[ "$found" != "true" ]]; then
                found=true
                forge::title "Custom templates:"
                printf '\n'
            fi
            name="$(basename "$dir")"
            printf '  %-10s %s\n' "$name" "$dir"
        done
    fi

    if [[ "$found" != "true" ]]; then
        forge::info "No custom templates installed."
        printf "Add one with: forge template add <name> <path-or-git-url>\n"
    fi
}

# forge::cmd_template_remove NAME BUILTIN_DIR FORCE
forge::cmd_template_remove() {
    local name="${1:-}"
    local builtin_dir="$2"
    local force="${3:-false}"
    local user_dir dest reply

    if [[ -z "$name" ]]; then
        forge::err "usage: forge template remove <name> [--force]"
        return 1
    fi

    if forge::template_is_builtin "$name" "$builtin_dir"; then
        forge::err "'$name' is a built-in template and cannot be removed."
        return 1
    fi

    user_dir="$(forge::user_templates_dir)"
    dest="$user_dir/$name"

    if [[ ! -d "$dest" ]]; then
        forge::err "no custom template named '$name'."
        return 1
    fi

    if [[ "$force" != "true" ]]; then
        if [[ ! -t 0 ]]; then
            forge::err "refusing to remove '$name' without --force in non-interactive mode."
            return 1
        fi
        printf 'Remove custom template "%s"? [y/N] ' "$name"
        read -r reply
        case "$reply" in
            y|Y|yes|YES) ;;
            *)
                forge::info "Cancelled."
                return 0
                ;;
        esac
    fi

    rm -rf "$dest"
    forge::ok "Template '$name' removed."
}
