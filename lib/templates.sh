#!/usr/bin/env bash
# Descoberta, renderização e materialização de templates.
#
# Placeholders suportados:
#   {{PROJECT_NAME}}     — nome exato passado em `forge new <template> NAME`
#   {{PROJECT_SLUG}}     — nome com '-' convertido para '_' (identificador válido)
#   __PROJECT_SLUG__     — no NOME de arquivos/diretórios do template, é
#                          renomeado para o slug (ex.: pacote Python)

forge::project_slug() {
    local name="$1"
    printf '%s' "${name//-/_}"
}

# forge::user_templates_dir
# Onde ficam os templates customizados adicionados via `forge template add`.
# Respeita XDG_CONFIG_HOME; nunca colide com os templates embutidos, que
# sempre têm prioridade de nome (ver forge::resolve_template_dir).
forge::user_templates_dir() {
    printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/project-forge/templates"
}

# forge::resolve_template_dir NAME BUILTIN_DIR
# Ecoa o caminho absoluto do template (built-in tem prioridade sobre
# customizado com o mesmo nome) ou retorna 1 se não existir em nenhum dos dois.
forge::resolve_template_dir() {
    local name="$1"
    local builtin_dir="$2"
    local user_dir
    user_dir="$(forge::user_templates_dir)"

    if [[ -d "$builtin_dir/$name" ]]; then
        printf '%s/%s' "$builtin_dir" "$name"
        return 0
    fi

    if [[ -d "$user_dir/$name" ]]; then
        printf '%s/%s' "$user_dir" "$name"
        return 0
    fi

    return 1
}

forge::template_description() {
    local name="$1"
    case "$name" in
        python) printf 'Python project' ;;
        cpp)    printf 'C++ project' ;;
        bash)   printf 'Bash CLI project' ;;
        *)      printf '%s project' "$name" ;;
    esac
}

# forge::list_templates TEMPLATES_DIR
forge::list_templates() {
    local templates_dir="$1"
    local user_dir dir name
    user_dir="$(forge::user_templates_dir)"

    forge::title "Available templates:"
    printf '\n'

    for dir in "$templates_dir"/*/; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"
        printf '  %-10s %s\n' "$name" "$(forge::template_description "$name")"
    done

    if [[ -d "$user_dir" ]]; then
        for dir in "$user_dir"/*/; do
            [[ -d "$dir" ]] || continue
            name="$(basename "$dir")"
            printf '  %-10s %s (custom)\n' "$name" "$(forge::template_description "$name")"
        done
    fi
}

# forge::render_file FILE PROJECT_NAME
# Substitui os placeholders de conteúdo. Usa perl com \Q...\E para tratar
# o nome do projeto como texto literal (evita os riscos de metacaracteres
# de regex/replacement que `sed` teria com nomes contendo '/', '&', etc).
forge::render_file() {
    local file="$1"
    local project_name="$2"
    local slug
    slug="$(forge::project_slug "$project_name")"

    [[ -f "$file" ]] || return 0

    # \Q..\E só é aplicado no PATTERN (lado esquerdo). Do lado do replacement
    # ele escaparia literalmente cada caractere não alfanumérico do nome
    # (ex.: "little-tool" viraria "little\-tool" no arquivo gerado).
    # project_name/slug já são validados como [A-Za-z0-9_-], então é seguro
    # colocá-los sem escapar do lado do replacement.
    perl -pi -e "
        s/\Q{{PROJECT_NAME}}\E/$project_name/g;
        s/\Q{{PROJECT_SLUG}}\E/$slug/g;
    " "$file"
}

# forge::render_tree DEST PROJECT_NAME
forge::render_tree() {
    local dest="$1"
    local project_name="$2"
    local file

    while IFS= read -r -d '' file; do
        forge::render_file "$file" "$project_name"
    done < <(find "$dest" -type f -print0)
}

# forge::rename_placeholders DEST PROJECT_NAME
# Renomeia arquivos/diretórios cujo NOME contém o literal __PROJECT_SLUG__.
# -depth garante que filhos são renomeados antes dos pais.
forge::rename_placeholders() {
    local dest="$1"
    local project_name="$2"
    local slug path new
    slug="$(forge::project_slug "$project_name")"

    while IFS= read -r -d '' path; do
        new="${path//__PROJECT_SLUG__/$slug}"
        [[ "$path" != "$new" ]] && mv "$path" "$new"
    done < <(find "$dest" -depth -name '*__PROJECT_SLUG__*' -print0)
}

# forge::preview_tree TEMPLATE_DIR DEST
# Lista o que seria criado, sem tocar em disco. Aplica a mesma renomeação
# de __PROJECT_SLUG__ apenas na exibição (nomes, não no disco).
# Usa -print0/-z ao longo de todo o pipeline para não quebrar em nomes
# com espaço, quebra de linha ou outros caracteres especiais.
forge::preview_tree() {
    local template_dir="$1"
    local dest="$2"
    local project_name="$3"
    local slug rel display
    slug="$(forge::project_slug "$project_name")"

    while IFS= read -r -d '' rel; do
        rel="${rel#./}"
        display="${rel//__PROJECT_SLUG__/$slug}"
        if [[ -d "$template_dir/$rel" ]]; then
            printf '%s/%s/\n' "$dest" "$display"
        else
            printf '%s/%s\n' "$dest" "$display"
        fi
    done < <(cd "$template_dir" && find . -mindepth 1 -print0 | sort -z)
}

# forge::instantiate TEMPLATE_DIR DEST PROJECT_NAME DRY_RUN
forge::instantiate() {
    local template_dir="$1"
    local dest="$2"
    local project_name="$3"
    local dry_run="${4:-false}"

    if [[ "$dry_run" == "true" ]]; then
        forge::info "Would create:"
        printf '\n'
        forge::preview_tree "$template_dir" "$dest" "$project_name"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    cp -r "$template_dir" "$dest"
    forge::ok "directories"
    forge::ok "template files"

    forge::rename_placeholders "$dest" "$project_name"
    forge::render_tree "$dest" "$project_name"
    forge::ok "variable substitution"

    # Preserva permissões de execução nos scripts do template (run.sh, etc.)
    find "$dest" -name '*.sh' -exec chmod +x {} +
}
