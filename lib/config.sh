#!/usr/bin/env bash
# Config de usuário do Forge (~/.config/project-forge/config).
# Formato: KEY=VALUE, uma por linha; '#' inicia comentário.
# Só duas chaves são lidas; o resto é ignorado:
#   default_path   — diretório pai padrão para `forge new` (padrão: .)
#   no_git         — "true"/"false" (padrão: false)
# Flags CLI sempre vencem o config; arquivo ausente = comportamento atual.

# forge::config_file — ecoa o caminho do arquivo de config.
forge::config_file() {
    printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/project-forge/config"
}

# forge::load_config — preenche FORGE_CFG_DEFAULT_PATH / FORGE_CFG_NO_GIT.
# Vazio = não configurado. Nunca falha por arquivo ausente ou malformado.
forge::load_config() {
    FORGE_CFG_DEFAULT_PATH=""
    FORGE_CFG_NO_GIT=""

    local cfg
    cfg="$(forge::config_file)"
    [[ -f "$cfg" ]] || return 0

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        # Trim espaços.
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        [[ "$line" != *=* ]] && continue

        key="${line%%=*}"
        value="${line#*=}"
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        # Remove aspas circundantes, se houver.
        if [[ ${#value} -ge 2 ]]; then
            if [[ "$value" == \"*\" && "$value" == *\" ]]; then
                value="${value:1:${#value}-2}"
            elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
                value="${value:1:${#value}-2}"
            fi
        fi

        case "$key" in
            default_path)
                # Expande ~ inicial para $HOME.
                if [[ "$value" == "~"* ]]; then
                    value="${value/#\~/$HOME}"
                fi
                [[ -n "$value" ]] && FORGE_CFG_DEFAULT_PATH="$value"
                ;;
            no_git)
                case "$value" in
                    true|false) FORGE_CFG_NO_GIT="$value" ;;
                    *) forge::warn "ignoring invalid no_git value in config: '$value' (expected true/false)." ;;
                esac
                ;;
            *) ;; # chave desconhecida: ignora em silêncio.
        esac
    done < "$cfg"
}
