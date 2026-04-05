# filament-plugin-workbanch

Infraestrutura compartilhada de ambiente de desenvolvimento para plugins FilamentPHP.

Fornece:
- **Dockerfile** genérico (PHP 8.4 + Node 22 + Composer 2)
- **Entrypoint** com auto-install de dependências
- **Templates** de `docker-compose.yml` e `testbench.yaml`
- **CLI `workbench`** para subir, derrubar e gerenciar o ambiente com um único comando

> **Pré-requisito único: Docker instalado.** Não é necessário PHP, Composer ou Node no host.

---

## Instalação

### Via git submodule (recomendado)

Não requer nada além de `git` e `docker`.

```bash
# 1. Adicionar o submodule no repositório do plugin
git submodule add https://github.com/CoringaWc/filament-plugin-workbanch.git packages/workbench
git submodule update --init --recursive

# 2. Subir o ambiente (copia templates, detecta providers, sobe container)
./packages/workbench/bin/workbench up
```

Ao executar `workbench up` pela primeira vez, o script:
- Copia `docker-compose.yml` (via template)
- Copia `testbench.yaml` (via template) e preenche os providers do `composer.json`
- Faz o build da imagem Docker e inicia o container
- Exibe os logs em tempo real

---

### Via Composer

Use quando o plugin já usa Composer como workflow principal.

```bash
# 1. Instalar o pacote via Docker (sem precisar de Composer no host)
docker run --rm -v "$(pwd):/app" -w /app composer:2 require --dev coringawc/filament-plugin-workbanch

# 2. Subir o ambiente
./vendor/bin/workbench up
```

---

## Comandos disponíveis

| Comando | Descrição |
|---|---|
| `workbench up` | Copia templates se necessário, sobe o container, exibe logs |
| `workbench down` | Para e remove o container |
| `workbench fresh` | Executa `migrate:fresh --seed` dentro do container |
| `workbench logs` | Segue os logs do container em tempo real |
| `workbench shell` | Abre shell interativo dentro do container |
| `workbench help` | Exibe ajuda |

---

## Como adicionar a um novo plugin

```bash
# No repositório do novo plugin:
git submodule add https://github.com/CoringaWc/filament-plugin-workbanch.git packages/workbench
git submodule update --init --recursive

# Subir o ambiente pela primeira vez
./packages/workbench/bin/workbench up
```

O script detecta automaticamente os `ServiceProvider`s declarados em `composer.json`
(`extra.laravel.providers`) e preenche o `testbench.yaml` gerado.

Após isso, a estrutura do plugin ficará:

```
meu-plugin/
  packages/
    workbench/          ← este submodule
  workbench/            ← código de teste ESPECÍFICO do plugin (models, seeders, etc.)
  docker-compose.yml    ← gerado pelo workbench up (aponta para packages/workbench/docker/php)
  testbench.yaml        ← gerado pelo workbench up (providers preenchidos automaticamente)
  composer.json         ← scripts bootstrap:workbench, fresh:workbench, serve
```

---

## O que fica em cada lugar

| Arquivo/Pasta | Onde | Por quê |
|---|---|---|
| `Dockerfile`, `entrypoint.sh` | **Este pacote** (`packages/workbench/docker/`) | Infraestrutura genérica, reutilizável |
| `docker-compose.yml.stub` | **Este pacote** | Template com `build.context` já configurado |
| `testbench.yaml.stub` | **Este pacote** | Template com variáveis comuns documentadas |
| `bin/workbench` | **Este pacote** | CLI de bootstrapping |
| `workbench/` | **No plugin** | Models, seeders, policies, resources específicos do plugin |
| `composer.json` | **No plugin** | Scripts `bootstrap:workbench`, `serve`, `fresh:workbench` |
| `testbench.yaml` | **No plugin** | Providers e env específicos |
| `docker-compose.yml` | **No plugin** | Gerado pelo `workbench up` — pode ser customizado |

---

## Atualizando para a versão mais recente

```bash
git submodule update --remote packages/workbench
git add packages/workbench
git commit -m "chore: bump filament-plugin-workbanch"
```

---

## Estrutura do pacote

```
filament-plugin-workbanch/
  bin/
    workbench               ← CLI (POSIX sh, funciona com apenas Docker no host)
  docker/
    php/
      Dockerfile            ← PHP 8.4-cli + Node 22 + Composer 2, usuário não-root
      entrypoint.sh         ← auto-install vendor/ e node_modules/ ao iniciar
  docker-compose.yml.stub   ← template de docker-compose.yml para plugins
  testbench.yaml.stub       ← template de testbench.yaml para plugins
```
