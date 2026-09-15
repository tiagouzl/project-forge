# Project Forge

A lightweight project scaffolding CLI built entirely with Bash.

`forge` cria projetos a partir de templates, aplica substituição de
variáveis, valida nome/destino, e opcionalmente inicializa um repositório
Git — sem depender de Python, Node ou qualquer runtime além de utilitários
POSIX básicos (`bash`, `cp`, `mkdir`, `find`, `perl`, `git`).

## Uso

```bash
./forge list

./forge new python little-tool
./forge new cpp sensor --dry-run
./forge new bash backup-tool --path ~/Projects --no-git
```

## Opções

| Flag            | Efeito                                             |
|-----------------|-----------------------------------------------------|
| `--path <dir>`  | Diretório pai do novo projeto (padrão: `.`)         |
| `--no-git`      | Não inicializa repositório Git                      |
| `--force`       | Sobrescreve o destino se já existir                 |
| `--dry-run`     | Mostra o que seria criado, sem tocar em disco       |

## Ambiente

```bash
./forge doctor
```

Verifica as dependências **core** do próprio forge (`bash`, `perl`, `git` —
sem elas o forge não funciona) e as **toolchains opcionais** usadas pelos
projetos gerados (`python3`, `gcc`, `g++` — o forge cria os arquivos de
qualquer forma; compilar/rodar depois é responsabilidade de cada toolchain).

## Configuração

Opcional, em `${XDG_CONFIG_HOME:-~/.config}/project-forge/config`
(formato `KEY=VALUE`, uma por linha; `#` inicia comentário):

```bash
default_path=~/Projects
no_git=false
```

- `default_path` — diretório pai padrão do `forge new` (padrão: `.`).
- `no_git` — `true`/`false` (padrão: `false`). Com `true`, `new` pula o
  `git init` — e não há flag para reabilitar no comando; remova do config.
- Chaves desconhecidas são ignoradas; `no_git` inválido é ignorado com aviso.
- Flags CLI vencem o config (`--path` sobrescreve `default_path`,
  `--no-git` força sem git). Arquivo ausente = comportamento atual.

## Templates customizados

Além dos três templates embutidos, é possível adicionar os seus, guardados
em `${XDG_CONFIG_HOME:-~/.config}/project-forge/templates/` (fora do
repositório do forge):

```bash
forge template add node ./meu-template-local
forge template add node https://github.com/usuario/meu-template.git

forge template list
forge template remove node
forge template remove node --force   # sem confirmação interativa
```

Regras:
- Um nome de template **built-in nunca pode ser sobrescrito** (`python`, `cpp`, `bash`).
- Origem local (diretório) é copiada como está; origem git é clonada
  (`--depth 1`) e o `.git` resultante é removido — o template fica só com
  os arquivos.
- `forge list` mostra templates embutidos e customizados juntos, marcando
  os customizados com `(custom)`.

## Templates

| Nome     | Conteúdo                                                        |
|----------|------------------------------------------------------------------|
| `python` | pacote em `src/<slug>/`, testes, `.gitignore`, `run.sh`          |
| `cpp`    | `src/main.cpp`, `include/`, `tests/`                             |
| `bash`   | script executável em `src/`, teste básico                        |

Templates usam dois placeholders:
- `{{PROJECT_NAME}}` / `{{PROJECT_SLUG}}` — substituídos no *conteúdo* dos arquivos.
- `__PROJECT_SLUG__` — substituído em *nomes* de arquivo/diretório.

## Testes

```bash
bats tests/forge.bats
```

## Roadmap

- **v0.1**: `new`, `list`, templates Python/C++/Bash, validação, `--dry-run`, Git.
- **v0.2**: `forge doctor` (detecção de ambiente: bash, perl, git, python, gcc).
- **v0.3**: templates externos (`forge template add/list/remove`).
- **v0.4** (atual): configuração de usuário em `~/.config/project-forge/config` (`default_path`, `no_git`).
