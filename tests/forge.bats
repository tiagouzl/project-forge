#!/usr/bin/env bats
#
# Suíte de testes do Project Forge (bats-core).
# Rodar com: bats tests/forge.bats

setup() {
    FORGE_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    FORGE="$FORGE_ROOT/forge"

    # Sandbox isolado por teste.
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR" || exit 1
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
    # Fixture de template usada pelo teste de nomes com espaço: removida aqui
    # (em vez de um trap RETURN dentro do teste) porque um trap RETURN também
    # dispara quando funções internas do bats como `run` retornam — não só
    # quando o teste termina — apagando a fixture cedo demais.
    rm -rf "$FORGE_ROOT/templates/__test_spaces__"
}

# make_fakebin DIR TOOL... — links dos executáveis p/ simular PATH parcial.
make_fakebin() {
    local dest="$1"; shift
    mkdir -p "$dest"
    local tool path
    for tool in "$@"; do
        path="$(command -v "$tool")" || continue
        ln -s "$path" "$dest/$tool"
    done
}

@test "--version imprime a versão" {
    run "$FORGE" --version
    [ "$status" -eq 0 ]
    [[ "$output" == "forge "* ]]
}

@test "--help imprime o uso" {
    run "$FORGE" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "list mostra os templates disponíveis" {
    run "$FORGE" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"python"* ]]
    [[ "$output" == *"cpp"* ]]
    [[ "$output" == *"bash"* ]]
}

@test "list com argumento extra falha" {
    run "$FORGE" list extra
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: forge list"* ]]
}

@test "comando desconhecido retorna erro" {
    run "$FORGE" bogus
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown command"* ]]
}

@test "template inválido é rejeitado" {
    run "$FORGE" new java api --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown template"* ]]
}

@test "nome de projeto inválido é rejeitado" {
    run "$FORGE" new python 123teste --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid project name"* ]]
}

@test "nome de projeto vazio é rejeitado" {
    run "$FORGE" new python "" --dry-run
    [ "$status" -ne 0 ]
}

@test "--dry-run não cria nada no disco" {
    run "$FORGE" new python demo --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" == *"No changes were made."* ]]
    [ ! -e "demo" ]
}

@test "new python cria a estrutura esperada" {
    run "$FORGE" new python demo --no-git
    [ "$status" -eq 0 ]
    [ -d "demo" ]
    [ -f "demo/src/demo/__init__.py" ]
    [ -f "demo/tests/test_main.py" ]
    [ -f "demo/README.md" ]
    [ -f "demo/.gitignore" ]
}

@test "new cpp cria a estrutura esperada" {
    run "$FORGE" new cpp sensor --no-git
    [ "$status" -eq 0 ]
    [ -f "sensor/src/main.cpp" ]
    [ -d "sensor/include" ]
    [ -d "sensor/tests" ]
}

@test "new bash cria a estrutura esperada" {
    run "$FORGE" new bash backup-tool --no-git
    [ "$status" -eq 0 ]
    [ -f "backup-tool/src/backup_tool.sh" ]
    [ -x "backup-tool/src/backup_tool.sh" ]
}

@test "{{PROJECT_NAME}} e {{PROJECT_SLUG}} são substituídos no conteúdo" {
    "$FORGE" new python little-tool --no-git >/dev/null
    run cat "little-tool/README.md"
    [[ "$output" == *"# little-tool"* ]]
    [[ "$output" != *"{{PROJECT_NAME}}"* ]]

    run cat "little-tool/run.sh"
    [[ "$output" == *"python -m little_tool"* ]]
}

@test "__PROJECT_SLUG__ é substituído em nomes de arquivo/diretório" {
    "$FORGE" new python little-tool --no-git >/dev/null
    [ -d "little-tool/src/little_tool" ]
    [ ! -d "little-tool/src/__PROJECT_SLUG__" ]
}

@test "diretório existente sem --force falha e não apaga nada" {
    "$FORGE" new python demo --no-git >/dev/null
    echo "marcador" > demo/marcador.txt

    run "$FORGE" new python demo --no-git
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
    [ -f "demo/marcador.txt" ]
}

@test "--force sobrescreve diretório existente" {
    "$FORGE" new python demo --no-git >/dev/null
    echo "marcador" > demo/marcador.txt

    run "$FORGE" new python demo --no-git --force
    [ "$status" -eq 0 ]
    [ ! -f "demo/marcador.txt" ]
}

@test "--no-git não inicializa repositório" {
    "$FORGE" new python demo --no-git >/dev/null
    [ ! -d "demo/.git" ]
}

@test "sem --no-git, inicializa repositório git com commit" {
    "$FORGE" new python demo >/dev/null
    [ -d "demo/.git" ]
    run git -C demo log --oneline
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "--force combinado com --dry-run apenas mostra prévia, sem apagar nada" {
    "$FORGE" new python demo --no-git >/dev/null
    echo "marcador" > demo/marcador.txt

    run "$FORGE" new python demo --force --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN"* ]]
    [[ "$output" == *"No changes were made."* ]]
    [ -f "demo/marcador.txt" ]
}

@test "preview_tree (unitário) lida com nomes de arquivo/diretório com espaço" {
    source "$FORGE_ROOT/lib/colors.sh"
    source "$FORGE_ROOT/lib/templates.sh"

    tmpl="$(mktemp -d)"
    mkdir -p "$tmpl/dir with space"
    touch "$tmpl/dir with space/file with space.txt"

    run forge::preview_tree "$tmpl" "dest" "demo"
    [ "$status" -eq 0 ]
    [[ "$output" == *"dest/dir with space/"* ]]
    [[ "$output" == *"dest/dir with space/file with space.txt"* ]]

    rm -rf "$tmpl"
}

@test "template com espaço no nome é criado corretamente (dry-run e real)" {
    extra_template="$FORGE_ROOT/templates/__test_spaces__"
    mkdir -p "$extra_template/dir with space"
    echo "conteudo" > "$extra_template/dir with space/file with space.txt"

    run "$FORGE" new __test_spaces__ demo --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"demo/dir with space/file with space.txt"* ]]

    run "$FORGE" new __test_spaces__ demo --no-git
    [ "$status" -eq 0 ]
    [ -f "demo/dir with space/file with space.txt" ]
}

@test "--path cria o projeto no diretório informado" {
    mkdir -p custom-parent
    run "$FORGE" new python demo --path custom-parent --no-git
    [ "$status" -eq 0 ]
    [ -d "custom-parent/demo" ]
}

@test "--path vazio é rejeitado" {
    run "$FORGE" new python demo --path "" --no-git
    [ "$status" -ne 0 ]
    [[ "$output" == *"non-empty"* ]]
}

@test "doctor reporta sucesso quando as dependências core estão presentes" {
    run "$FORGE" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"Bash"* ]]
    [[ "$output" == *"Perl"* ]]
    [[ "$output" == *"Git"* ]]
    [[ "$output" == *"All core dependencies are available."* ]]
}

@test "doctor com argumento extra falha" {
    run "$FORGE" doctor extra
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: forge doctor"* ]]
}

@test "doctor detecta dependência core ausente (perl fora do PATH)" {
    fakebin="$(mktemp -d)"
    make_fakebin "$fakebin" bash git cp mkdir find sort grep head cat rm mv chmod mktemp readlink dirname basename

    PATH="$fakebin" run "$FORGE" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"Perl"*"not found"* ]]
    [[ "$output" == *"one or more core dependencies are missing"* ]]

    rm -rf "$fakebin"
}

@test "doctor reporta toolchains opcionais mesmo se ausentes, sem falhar por causa delas" {
    fakebin="$(mktemp -d)"
    make_fakebin "$fakebin" bash perl git cp mkdir find sort grep head cat rm mv chmod mktemp readlink dirname basename

    PATH="$fakebin" run "$FORGE" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"Python"*"not found"* ]]
    [[ "$output" == *"GCC"*"not found"* ]]
    [[ "$output" == *"All core dependencies are available."* ]]

    rm -rf "$fakebin"
}

# --- forge template add/list/remove -----------------------------------

@test "template list sem nenhum customizado instalado" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    run "$FORGE" template list
    [ "$status" -eq 0 ]
    [[ "$output" == *"No custom templates installed."* ]]
}

@test "template add a partir de diretório local, depois aparece em list e forge list" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    mkdir -p src-template
    echo 'console.log("{{PROJECT_NAME}}");' > src-template/index.js

    run "$FORGE" template add node "$PWD/src-template"
    [ "$status" -eq 0 ]

    run "$FORGE" template list
    [ "$status" -eq 0 ]
    [[ "$output" == *"node"* ]]

    run "$FORGE" list
    [ "$status" -eq 0 ]
    [[ "$output" == *"node"*"(custom)"* ]]
}

@test "template add recusa nome colidindo com template built-in" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" src-template

    run "$FORGE" template add python "$PWD/src-template"
    [ "$status" -ne 0 ]
    [[ "$output" == *"built-in template name"* ]]
}

@test "template add recusa nome já usado por outro customizado" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" src-template

    "$FORGE" template add node "$PWD/src-template" >/dev/null

    run "$FORGE" template add node "$PWD/src-template"
    [ "$status" -ne 0 ]
    [[ "$output" == *"already exists"* ]]
}

@test "template add falha com mensagem clara se o diretório de origem não existe" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    run "$FORGE" template add node "$PWD/nao-existe"
    [ "$status" -ne 0 ]
    [[ "$output" == *"source directory not found"* ]]
}

@test "template add recusa origem local com symlink" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" src-template
    echo "x" > src-template/file.txt
    ln -s file.txt src-template/link

    run "$FORGE" template add node "$PWD/src-template"
    [ "$status" -ne 0 ]
    [[ "$output" == *"symlink"* ]]
    [ ! -e "$HOME/.config/project-forge/templates/node" ]
}

@test "template add recusa clone git com symlink" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    fixture="$TEST_DIR/git-link-source"
    mkdir -p "$fixture"
    (
        cd "$fixture" &&
        git init --quiet &&
        git config user.name "test" &&
        git config user.email "test@example.com" &&
        echo "x" > file.txt &&
        ln -s file.txt link &&
        git add -A &&
        git commit --quiet -m "seed"
    )

    run "$FORGE" template add fromgit "file://$fixture"
    [ "$status" -ne 0 ]
    [[ "$output" == *"symlink"* ]]
    [ ! -e "$HOME/.config/project-forge/templates/fromgit" ]
}

@test "forge new usa um template customizado normalmente" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" src-template
    echo 'console.log("{{PROJECT_NAME}}");' > src-template/index.js

    "$FORGE" template add node "$PWD/src-template" >/dev/null

    run "$FORGE" new node meu-app --no-git
    [ "$status" -eq 0 ]
    [ -f "meu-app/index.js" ]
    run cat "meu-app/index.js"
    [[ "$output" == *'"meu-app"'* ]]
}

@test "template remove recusa remover template built-in" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    run "$FORGE" template remove python --force
    [ "$status" -ne 0 ]
    [[ "$output" == *"built-in template"* ]]
}

@test "template remove sem --force falha em modo não interativo" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" src-template
    "$FORGE" template add node "$PWD/src-template" >/dev/null

    run bash -c "'$FORGE' template remove node < /dev/null"
    [ "$status" -ne 0 ]
    [[ "$output" == *"without --force"* ]]

    run "$FORGE" template list
    [[ "$output" == *"node"* ]]
}

@test "template remove com --force apaga o template customizado" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" src-template
    "$FORGE" template add node "$PWD/src-template" >/dev/null

    run "$FORGE" template remove node --force
    [ "$status" -eq 0 ]

    run "$FORGE" template list
    [[ "$output" == *"No custom templates installed."* ]]
}

@test "template add clona via URL git (file://) e remove .git residual" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    fixture="$TEST_DIR/git-template-source"
    mkdir -p "$fixture"
    (
        cd "$fixture" &&
        git init --quiet &&
        git config user.name "test" &&
        git config user.email "test@example.com" &&
        echo '{{PROJECT_NAME}}' > file.txt &&
        git add -A &&
        git commit --quiet -m "seed"
    )

    run "$FORGE" template add fromgit "file://$fixture"
    [ "$status" -eq 0 ]
    [ -f "$HOME/.config/project-forge/templates/fromgit/file.txt" ]
    [ ! -d "$HOME/.config/project-forge/templates/fromgit/.git" ]
}

@test "template add com argumento extra falha em vez de ignorar" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" src-template

    run "$FORGE" template add node "$PWD/src-template" extra
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: forge template add"* ]]
}

@test "template list com argumento extra falha" {
    run "$FORGE" template list extra
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: forge template list"* ]]
}

# --- config de usuário (v0.4) -----------------------------------------

@test "config default_path é usado quando --path não é passado" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME/.config/project-forge" custom-parent
    printf 'default_path=%s\n' "$PWD/custom-parent" > "$HOME/.config/project-forge/config"

    run "$FORGE" new python demo --no-git
    [ "$status" -eq 0 ]
    [ -d "custom-parent/demo" ]
}

@test "--path sobrescreve o default_path do config" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME/.config/project-forge" cfg-parent cli-parent
    printf 'default_path=%s\n' "$PWD/cfg-parent" > "$HOME/.config/project-forge/config"

    run "$FORGE" new python demo --path cli-parent --no-git
    [ "$status" -eq 0 ]
    [ -d "cli-parent/demo" ]
    [ ! -e "cfg-parent/demo" ]
}

@test "config no_git=true pula o git init" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME/.config/project-forge"
    printf 'no_git=true\n' > "$HOME/.config/project-forge/config"

    run "$FORGE" new python demo
    [ "$status" -eq 0 ]
    [ -d "demo" ]
    [ ! -d "demo/.git" ]
}

@test "config com no_git inválido e chave desconhecida é ignorado" {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME/.config/project-forge"
    printf 'no_git=maybe\nunknown_key=1\n' > "$HOME/.config/project-forge/config"

    run "$FORGE" new python demo
    [ "$status" -eq 0 ]
    [ -d "demo/.git" ]
}
