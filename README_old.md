# Ambiente (Backup & Restauração)

Conjunto de scripts para snapshot e restauração modular do ambiente Arch/Linux.

## Quick Start - Passo a Passo

### 1. Primeiro uso - Configuração inicial

```bash
# Clone ou navegue até o diretório do projeto
cd ambiente

# Torne os scripts executáveis
chmod +x *.sh

# (Opcional) Crie links simbólicos para uso global
./install.sh

# Verifique se ~/.local/bin está no PATH
echo $PATH | grep -q "$HOME/.local/bin" || echo "Adicione ~/.local/bin ao PATH no seu .bashrc/.zshrc"
```

### 2. Gerando seu primeiro backup

```bash
# Backup completo (recomendado para primeira vez)
./backup-completo.sh --profile full

# Ou se preferir sem chaves SSH/GPG (mais seguro para compartilhar)
./backup-completo.sh --profile share --sanitize
```

**Durante a execução você verá:**
```
=== Iniciando backup com perfil: full ===
Coletando: user_configs, scripts, themes, packages, services...
Comprimindo com gzip...
✓ Backup salvo em: /home/seu_usuario/backups/env-backup-20250915-143022.tar.gz
```

### 3. Verificando o backup gerado

```bash
# Listar arquivos de backup
ls -la ~/backups/

# Ver conteúdo do backup (sem extrair)
tar -tzf ~/backups/env-backup-20250915-143022.tar.gz | head -20

# Ver resumo do backup
tar -xzf ~/backups/env-backup-20250915-143022.tar.gz meta/summary.txt -O
```

### 4. Restaurando em uma nova máquina

```bash
# Copie o arquivo .tar.gz para a nova máquina
# scp ~/backups/env-backup-*.tar.gz usuario@nova-maquina:~/

# Na nova máquina, clone este repositório
git clone <repo-url> ambiente
cd ambiente
chmod +x *.sh

# Dry-run primeiro (para ver o que será feito)
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --dry-run

# Restauração parcial (configs e scripts básicos)
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --categories "user_configs_clean scripts packages_explicit"

# Restauração completa (requer sudo para configs de sistema)
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --verify
```

### 5. Comandos mais usados no dia a dia

```bash
# Backup rápido para compartilhar (sem dados pessoais)
./backup-completo.sh --profile share --sanitize

# Backup só dos essenciais (configs + pacotes)
./backup-completo.sh --profile core

# Restaurar apenas configs do usuário
./restaurar-ambiente.sh --categories "user_configs_clean"

# Ver diferenças de pacotes entre backups
./relatorio-pacotes.sh --diff --orphans
```

### 6. Estrutura do arquivo gerado

Após executar o backup, você terá:
```
~/backups/env-backup-YYYYMMDD-HHMMSS.tar.gz    # Arquivo principal
```

Conteúdo interno:
```
categories/user_configs/     # Configurações completas (~/.config, etc)
categories/scripts/          # Scripts do usuário
categories/packages/         # Listas de pacotes instalados  
categories/themes/           # Temas GTK/icons
meta/summary.txt            # Resumo do backup
meta/metadata.json          # Metadados completos
```

### 7. Exemplo completo de migração

```bash
# Na máquina atual:
./backup-completo.sh --profile full
# Resultado: ~/backups/env-backup-20250915-143022.tar.gz

# Transferir para nova máquina:
scp ~/backups/env-backup-*.tar.gz usuario@nova-maquina:~/

# Na nova máquina:
git clone <repo> ambiente && cd ambiente && chmod +x *.sh
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --verify

# Pronto! Ambiente restaurado.
```

## Visão Geral

Scripts:
- `backup-completo.sh`: Gera um backup modular (somente backup) com categorias selecionáveis, perfis, sanitização e metadados.
- `restaurar-ambiente.sh`: Restaura (total ou parcialmente) um arquivo gerado pelo script de backup.
- `relatorio-pacotes.sh`: Relatórios/diff de pacotes para limpeza.
- `install.sh`: Cria symlinks convenientes em `~/.local/bin`.

Diretório padrão de saída de backups: `~/backups`.

Estrutura interna do arquivo de backup (`env-backup-YYYYMMDD-HHMMSS.tar.*`):
```
categories/
  user_configs/
  user_configs_clean/
  scripts/
  themes/
  system_themes/
  packages/
  services/
  system_configs/
  php/
  httpd/
  keys/
  custom/
  meta/
  manifest.sha256
  metadata.json
  summary.txt
```

## Requisitos Básicos

Dependências (backup): `bash`, `tar`, `find`, `sort`, `sha256sum`, `gzip` (ou `xz` / `zstd`), opcional: `dialog` ou `zenity`, `pacman`, `systemctl`, `sudo` (para categorias de sistema).  
Dependências (restore): `bash`, `tar`, `sha256sum`, `rsync` (opcional mas recomendado), `pacman`, helper AUR (`yay` ou `paru`) opcional.

## Instalação Rápida (Symlinks)

Crie links curtos no PATH:
```
cd ambiente
chmod +x *.sh
./install.sh
```

Verifique PATH inclui `~/.local/bin`:
```
echo $PATH | grep -q "$HOME/.local/bin" || echo "Adicione export PATH=\"$HOME/.local/bin:$PATH\" ao seu shell rc"
```

Depois:
```
backup-env --profile full
restore-env --dry-run --catego# Ambiente (Backup & Restauração)

Conjunto de scripts para snapshot e restauração modular do ambiente Arch/Linux.

## Quick Start - Passo a Passo

### 1. Primeiro uso - Configuração inicial

```bash
# Clone ou navegue até o diretório do projeto
cd ambiente

# Torne os scripts executáveis
chmod +x *.sh

# (Opcional) Crie links simbólicos para uso global
./install.sh

# Verifique se ~/.local/bin está no PATH
echo $PATH | grep -q "$HOME/.local/bin" || echo "Adicione ~/.local/bin ao PATH no seu .bashrc/.zshrc"
```

### 2. Gerando seu primeiro backup

```bash
# Backup completo (recomendado para primeira vez)
./backup-completo.sh --profile full

# Ou se preferir sem chaves SSH/GPG (mais seguro para compartilhar)
./backup-completo.sh --profile share --sanitize
```

**Durante a execução você verá:**
```
=== Iniciando backup com perfil: full ===
Coletando: user_configs, scripts, themes, packages, services...
Comprimindo com gzip...
✓ Backup salvo em: /home/seu_usuario/backups/env-backup-20250915-143022.tar.gz
```

### 3. Verificando o backup gerado

```bash
# Listar arquivos de backup
ls -la ~/backups/

# Ver conteúdo do backup (sem extrair)
tar -tzf ~/backups/env-backup-20250915-143022.tar.gz | head -20

# Ver resumo do backup
tar -xzf ~/backups/env-backup-20250915-143022.tar.gz meta/summary.txt -O
```

### 4. Restaurando em uma nova máquina

```bash
# Copie o arquivo .tar.gz para a nova máquina
# scp ~/backups/env-backup-*.tar.gz usuario@nova-maquina:~/

# Na nova máquina, clone este repositório
git clone <repo-url> ambiente
cd ambiente
chmod +x *.sh

# Dry-run primeiro (para ver o que será feito)
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --dry-run

# Restauração parcial (configs e scripts básicos)
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --categories "user_configs_clean scripts packages_explicit"

# Restauração completa (requer sudo para configs de sistema)
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --verify
```

### 5. Comandos mais usados no dia a dia

```bash
# Backup rápido para compartilhar (sem dados pessoais)
./backup-completo.sh --profile share --sanitize

# Backup só dos essenciais (configs + pacotes)
./backup-completo.sh --profile core

# Restaurar apenas configs do usuário
./restaurar-ambiente.sh --categories "user_configs_clean"

# Ver diferenças de pacotes entre backups
./relatorio-pacotes.sh --diff --orphans
```

### 6. Estrutura do arquivo gerado

Após executar o backup, você terá:
```
~/backups/env-backup-YYYYMMDD-HHMMSS.tar.gz    # Arquivo principal
```

Conteúdo interno:
```
categories/user_configs/     # Configurações completas (~/.config, etc)
categories/scripts/          # Scripts do usuário
categories/packages/         # Listas de pacotes instalados  
categories/themes/           # Temas GTK/icons
meta/summary.txt            # Resumo do backup
meta/metadata.json          # Metadados completos
```

### 7. Exemplo completo de migração

```bash
# Na máquina atual:
./backup-completo.sh --profile full
# Resultado: ~/backups/env-backup-20250915-143022.tar.gz

# Transferir para nova máquina:
scp ~/backups/env-backup-*.tar.gz usuario@nova-maquina:~/

# Na nova máquina:
git clone <repo> ambiente && cd ambiente && chmod +x *.sh
./restaurar-ambiente.sh --archive ~/env-backup-20250915-143022.tar.gz --verify

# Pronto! Ambiente restaurado.
```

## Visão Geral

// ...existing code...ries "user_configs_clean scripts"
pkg-report --diff --orphans
```

## 1. Gerando um Backup

Execução simples (perfil completo):
```
./backup-completo.sh --profile full
```

Perfis disponíveis:
- `full`: tudo (inclui chaves)
- `core`: configs limpas essenciais + pacotes explícitos + serviços + system configs + php/httpd + temas
- `share`: versão limpa para compartilhar (sem chaves, sem lixo pessoal)
- `minimal`: scripts + pacotes explícitos

Exemplo com sanitização e compressão zstd:
```
./backup-completo.sh --profile share --sanitize --compression zst
```

Seleção interativa (dialog):
```
./backup-completo.sh --select
```

Seleção interativa (zenity):
```
./backup-completo.sh --zenity
```

Personalizando categorias manualmente:
```
./backup-completo.sh --categories "user_configs_clean scripts packages_explicit"
```

Adicionar caminhos personalizados (arquivo com um path por linha):
```
./backup-completo.sh --profile core --custom-paths extra_paths.txt
```

Variáveis de ambiente úteis:
- `BACKUP_ROOT_DIR`: altera diretório destino (default `~/backups`)
- `COMPRESS_FORMAT`: força formato (gz|xz|zst)
- `SANITIZE_EXTRA_REMOVE`: padrões extras para remover (se `--sanitize`) separados por `:` ou `;`
- `CLEAN_CONFIG_ALLOW`: whitelist de subpastas de `~/.config` para `user_configs_clean`
- `CUSTOM_PATHS`: lista de caminhos adicionais separados por `:`

Saída gerada (exemplo):
```
~/backups/env-backup-20250829-142301.tar.zst
```
Metadados: confira `meta/metadata.json` e `meta/summary.txt` dentro do arquivo (após extrair ou via `tar -tf`).

## 2. Sanitização

Ative com `--sanitize` para remover dados pessoais: caches, perfis de navegadores, etc.  
Estenda via `SANITIZE_EXTRA_REMOVE=".config/Outlook;.config/Teams"`.

## 3. Restaurando um Backup

Restauração padrão (último arquivo em `~/backups`):
```
./restaurar-ambiente.sh
```

Restauração específica com verificação:
```
./restaurar-ambiente.sh --archive ~/backups/env-backup-20250829-142301.tar.zst --verify
```

Dry-run (planejamento):
```
./restaurar-ambiente.sh --dry-run --categories "user_configs_clean packages_explicit"
```

Restaurar temas do sistema dentro do HOME (sem sudo):
```
./restaurar-ambiente.sh --themes-user --categories "system_themes"
```

Incluir chaves (EXIGE confiança no arquivo):
```
./restaurar-ambiente.sh --with-keys --categories "keys"
```

Ignorar instalação de pacotes e serviços:
```
./restaurar-ambiente.sh --no-packages --no-services
```

Instalar apenas pacotes explícitos, sem configs de sistema:
```
./restaurar-ambiente.sh --only-explicit --no-system
```

Listar categorias presentes no arquivo sem restaurar:
```
./restaurar-ambiente.sh --archive <arquivo> --list-categories
```

## 4. Recomendações de Fluxo

1. Gerar backup full periódico: `./backup-completo.sh --profile full`
2. Para compartilhar: `./backup-completo.sh --profile share --sanitize`
3. Para migração limpa: usar `core` ou `full` conforme necessidade.
4. Antes de restaurar pacotes: garantir rede e espelhos atualizados (`sudo pacman -Syu`).
5. Usar `--dry-run` antes de uma restauração grande.

## 5. Verificação de Integridade

Use `--verify` no restaurador para validar `manifest.sha256`.  
Ou manualmente:
```
TMP=$(mktemp -d); tar -xzf env-backup-*.tar.gz -C "$TMP"; (cd "$TMP" && sha256sum -c meta/manifest.sha256)
```
(Ajuste o comando para `.tar.xz` ou `.tar.zst` conforme o caso.)

## 6. Extensão de Categorias

Para adicionar nova categoria ao backup:
1. Editar `backup-completo.sh` criando função `do_novacategoria()` seguindo padrão.
2. Incluir case em `run_categories`.
3. Adicionar aos perfis desejados.
4. (Opcional) Incluir nas UIs dialog/zenity.

## 7. Segurança

- Não compartilhe backups com `keys` a terceiros.
- Sempre revise conteúdo sanitizado antes de publicar.
- Rodar restauração de configs de sistema (`system_configs`, `php`, `httpd`) requer `sudo` e pode sobrescrever arquivos locais.
- Faça snapshot (ex: btrfs, timeshift) antes de uma restauração intrusiva.

## 8. Exemplos Rápidos

Backup mínimo scripts + pacotes explícitos em xz:
```
COMPRESS_FORMAT=xz ./backup-completo.sh --profile minimal
```

Backup custom escolhendo no diálogo:
```
./backup-completo.sh --select
```

Restauração apenas das configs limpas e scripts (dry-run):
```
./restaurar-ambiente.sh --dry-run --categories "user_configs_clean scripts"
```

## 9. Troubleshooting

| Problema | Causa provável | Ação |
|----------|----------------|------|
| Manifest falha | Arquivo corrompido | Refaça download / copie novamente |
| Pacotes AUR não instalam | Helper não instalado | Instale `yay` ou `paru` manualmente |
| system_themes não aplicou | Falta sudo | Use `--themes-user` ou rode com sudo disponível |
| Chaves não restauradas | Faltou flag | Adicione `--with-keys` |

## 10. Licença

Adapte e aplique a licença de sua preferência (ex: MIT) se for distribuir.

## 11. Gestão e Limpeza de Pacotes

Use o script `relatorio-pacotes.sh` para acompanhar evolução dos pacotes e evitar acúmulo de "lixo".

Torne executável (primeira vez):
```
chmod +x relatorio-pacotes.sh
```

Relatório texto simples (dois últimos backups):
```
./relatorio-pacotes.sh --diff
```

Incluir orfãos e tamanhos (requer `expac`):
```
./relatorio-pacotes.sh --diff --orphans --sizes
```

Listar pacotes instalados nos últimos 15 dias:
```
./relatorio-pacotes.sh --installed-since 15
```

Comparar com baseline (capture um baseline inicial):
```
pacman -Qetq > baseline.txt
./relatorio-pacotes.sh --baseline baseline.txt --diff
```

Exportar em Markdown (para colar em wiki pessoal):
```
./relatorio-pacotes.sh --diff --orphans --output md > relatorio.md
```

Exportar JSON (para processamento externo):
```
./relatorio-pacotes.sh --diff --output json > relatorio.json
```

Limpeza sugerida de orfãos (revise antes):
```
sudo pacman -Rns $(pacman -Qdtq)
```

Remover caches do pacman (opcional):
```
sudo paccache -r
```

Checar tamanhos maiores (top 20):
```
expac -H M '%m %n' | sort -nr | head -20
```

Checar pacotes instalados hoje:
```
./relatorio-pacotes.sh --installed-since 1
```

Estratégia recomendada:
1. Gerar backup semanal.
2. Rodar `relatorio-pacotes.sh --diff --orphans` e remover o que não usa.
3. Atualizar baseline quando satisfeito (`pacman -Qetq > baseline.txt`).
4. Antes de um backup "share", fazer limpeza de orfãos e caches.

---
Gerado em: $(date +%Y-%m-%d)
