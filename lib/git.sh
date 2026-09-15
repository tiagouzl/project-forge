#!/usr/bin/env bash
# Integração com Git. Nunca falha o comando principal por causa do git —
# no pior caso, avisa e segue (mantém o núcleo utilizável sem git instalado).

forge::git_available() {
    command -v git >/dev/null 2>&1
}

# forge::git_init DEST DRY_RUN
forge::git_init() {
    local dest="$1"
    local dry_run="${2:-false}"

    if [[ "$dry_run" == "true" ]]; then
        forge::info "Would initialize Git repository."
        return 0
    fi

    if ! forge::git_available; then
        forge::warn "git not found in PATH — skipping repository initialization."
        return 0
    fi

    if ! (
        cd "$dest" &&
        git init --quiet &&
        # Garante autor mesmo sem git global configurado (sandboxes, CI,
        # máquinas novas) sem tocar na configuração global do usuário.
        { git config user.name >/dev/null 2>&1 || git config user.name "Project Forge"; } &&
        { git config user.email >/dev/null 2>&1 || git config user.email "forge@localhost"; } &&
        git add -A &&
        git commit --quiet -m "Initial commit (project-forge)" --no-verify
    ) >/dev/null 2>&1; then
        forge::warn "git initialization failed — project files were still created."
        return 0
    fi

    forge::ok "Git repository"
}
