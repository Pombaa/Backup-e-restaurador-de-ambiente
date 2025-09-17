# Ambiente (Backup & Restauração)

Conjunto de scripts para snapshot e restauração modular do ambiente Arch/Linux.

## ✨ Novo: Interface Gráfica

Agora com interface gráfica **zenity** para facilitar o uso!

```bash
# Interface completa (backup + restauração)
./ambiente-gui.sh

# Apenas backup
./backup-gui.sh

# Apenas restauração
./restore-gui.sh
```

**Recursos da GUI:**
- 🎯 Seleção visual de perfis e categorias
- ⚙️ Configuração de opções avançadas
- 📊 Indicador de progresso
- 🧪 Modo de teste (dry-run)
- 📋 Resumo detalhado antes da execução
- 💡 Ajuda contextual integrada

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
# Backup completo SEM sudo (recomendado para ambiente pessoal)
FULL_USER_LOCAL=0 ./backup-completo.sh --no-sudo --profile full --compression zst

# Backup completo COM sudo (inclui configurações de sistema)
FULL_USER_LOCAL=0 ./backup-completo.sh --profile full --compression zst

# Backup para compartilhar (sem dados pessoais/chaves)
./backup-completo.sh --no-sudo --profile share --sanitize
```

**Principais variáveis de controle:**
- `FULL_USER_LOCAL=0` - Copia apenas essencial de ~/.local (economiza espaço)
- `FULL_SYSTEM_THEMES=1` - Copia todos os temas do sistema (padrão)
- `SCRIPT_EXTRA_PATHS="~/bin:~/Projetos/util"` - Caminhos extras para scripts

**Durante a execução você verá:**
```
[backup] Iniciando backup categorias=user_configs packages system_configs...
[backup] Categoria: user_configs
[backup] FULL_USER_LOCAL=0 -> copiando subconjunto de ~/.local
[backup] user_configs: 100555 arquivos copiados
[backup] Categoria: system_themes
[backup] FULL_SYSTEM_THEMES=1 -> copiando /usr/share/themes e /usr/share/icons completos
[backup] system_themes: 85923 arquivos copiados
[backup] Gerando resumo por categoria
[backup] Compactando (formato=zst)
[backup] Arquivo final: /home/usuario/backups/env-backup-20250917-095521.tar.zst (tamanho 4,9G)
[backup] Concluído.
```

## 🖱️ Interface Gráfica (GUI)

### Instalação e Uso das GUIs

```bash
# Verificar se zenity está instalado (necessário para as GUIs)
sudo pacman -S zenity

# Launcher principal (menu com backup + restauração)
./ambiente-gui.sh

# GUIs específicas
./backup-gui.sh     # Apenas interface de backup
./restore-gui.sh    # Apenas interface de restauração
```

### Recursos das Interfaces Gráficas

**🚀 Backup GUI:**
- Seleção visual de perfis (core, full, share, minimal, custom)
- Configuração de categorias personalizadas
- Opções avançadas (sanitização, compressão, sudo)
- Nome personalizado para arquivos
- Indicador de progresso em tempo real
- Confirmação visual com resumo

**🗃️ Restore GUI:**
- Auto-detecção de backups em ~/backups/
- Seleção visual de arquivo de backup
- Listagem automática de categorias disponíveis
- Modo teste (dry-run) recomendado
- Opções de restauração configuráveis
- Verificação de integridade opcional

**💡 Vantagens da GUI:**
- Ideal para usuários não técnicos
- Previne erros de sintaxe de comando
- Interface amigável e intuitiva
- Ajuda contextual integrada
- Feedback visual de progresso
- Confirmações de segurança

### Criando Launcher Desktop

```bash
# Copiar para aplicações do usuário
cp sistema-backup.desktop ~/.local/share/applications/

# Ou instalar no sistema
sudo cp sistema-backup.desktop /usr/share/applications/
```

Após isso, o "Sistema de Backup" aparecerá no menu de aplicações do seu desktop environment.

### 3. Verificando o backup gerado

```bash
# Listar arquivos de backup
ls -la ~/backups/

# Ver conteúdo do backup (sem extrair)
tar -tf ~/backups/env-backup-20250917-095521.tar.zst | head -20

# Ver resumo do backup
tar -xf ~/backups/env-backup-20250917-095521.tar.zst meta/summary.txt -O

# Ver resumo por categoria
tar -xf ~/backups/env-backup-20250917-095521.tar.zst meta/category-summary.txt -O
```

### 4. Restaurando em uma nova máquina

```bash
# Copie o arquivo .tar.zst para a nova máquina
# scp ~/backups/env-backup-*.tar.zst usuario@nova-maquina:~/

# Na nova máquina, clone este repositório
git clone <repo-url> ambiente
cd ambiente
chmod +x *.sh

# Dry-run primeiro (para ver o que será feito)
./restaurar-ambiente.sh --archive ~/env-backup-20250917-095521.tar.zst --dry-run

# Restauração parcial (configs e scripts básicos)
./restaurar-ambiente.sh --archive ~/env-backup-20250917-095521.tar.zst --categories "user_configs_clean scripts packages_explicit"

# Restauração completa (requer sudo para configs de sistema)
./restaurar-ambiente.sh --archive ~/env-backup-20250917-095521.tar.zst --verify
```

### 5. Opções avançadas e variáveis de ambiente

**Variáveis de controle (exportar antes de executar):**
```bash
# Controla inclusão de ~/.local
FULL_USER_LOCAL=0     # Apenas essencial (bin, share/applications, fonts, icons, themes)
FULL_USER_LOCAL=1     # Copia ~/.local inteiro (pode ser muito grande)

# Controla temas/ícones do sistema
FULL_SYSTEM_THEMES=1  # Copia /usr/share/themes e /usr/share/icons completos (padrão)
FULL_SYSTEM_THEMES=0  # Apenas temas detectados pelo gsettings

# Caminhos extras para scripts
SCRIPT_EXTRA_PATHS="~/bin:~/Projetos/scripts:~/meus-utils"

# Padrões para ignorar em system_themes
FULL_SYSTEM_THEMES_SKIP_PATTERNS="*-legacy:*-backup:*-old"
```

**Diferenças --no-sudo vs com sudo:**
```bash
# SEM sudo (para ambiente pessoal) - RECOMENDADO
FULL_USER_LOCAL=0 ./backup-completo.sh --no-sudo --profile full --compression zst
# ✅ user_configs, scripts, themes, packages, keys
# ✅ php/httpd básicos (se legíveis)
# ❌ /etc/ configs, serviços do sistema

# COM sudo (backup completo de sistema)  
FULL_USER_LOCAL=0 ./backup-completo.sh --profile full --compression zst
# ✅ Tudo do --no-sudo +
# ✅ /etc/pacman.conf, /etc/fstab, /etc/hosts
# ✅ Serviços systemd do sistema
# ✅ /etc/php/ e /etc/httpd/ completos
```

**Formatos de compressão:**
```bash
--compression gz    # Padrão, compatível
--compression xz    # Melhor compressão, mais lento
--compression zst   # Mais rápido, boa compressão (recomendado)
```

### 6. Comandos mais usados no dia a dia

```bash
# Backup rápido sem sudo (mais comum)
FULL_USER_LOCAL=0 ./backup-completo.sh --no-sudo --profile core --compression zst

# Backup para compartilhar (sem dados pessoais)
./backup-completo.sh --no-sudo --profile share --sanitize

# Backup só dos essenciais (configs + pacotes)
./backup-completo.sh --no-sudo --profile core

# Restaurar apenas configs do usuário
./restaurar-ambiente.sh --categories "user_configs_clean"

# Ver diferenças de pacotes entre backups
./relatorio-pacotes.sh --diff --orphans
```

### 7. Estrutura do arquivo gerado

Após executar o backup, você terá:
```
~/backups/env-backup-YYYYMMDD-HHMMSS.tar.zst    # Arquivo principal
```

Conteúdo interno:
```
categories/user_configs/     # Configurações completas (~/.config, dotfiles)
categories/scripts/          # Scripts do usuário (bin/)
categories/packages/         # Listas de pacotes instalados  
categories/themes/           # Temas GTK/icons pessoais
categories/system_themes/    # Temas/ícones do sistema (/usr/share/)
categories/keys/             # SSH/GPG (se incluído)
meta/summary.txt            # Resumo do backup
meta/metadata.json          # Metadados completos
meta/category-summary.txt   # Resumo por categoria
meta/manifest.sha256        # Checksums dos arquivos
```

### 8. Exemplo completo de migração

```bash
# Na máquina atual:
FULL_USER_LOCAL=0 ./backup-completo.sh --no-sudo --profile full --compression zst
# Resultado: ~/backups/env-backup-20250917-095521.tar.zst (4.9GB)

# Transferir para nova máquina:
scp ~/backups/env-backup-*.tar.zst usuario@nova-maquina:~/

# Na nova máquina:
git clone <repo> ambiente && cd ambiente && chmod +x *.sh
./restaurar-ambiente.sh --archive ~/env-backup-20250917-095521.tar.zst --verify

# Pronto! Ambiente restaurado.
```

## Visão Geral

Scripts:
- `backup-completo.sh`: Gera um backup modular (somente backup) com categorias selecionáveis, perfis, sanitização e metadados.
- `restaurar-ambiente.sh`: Restaura (total ou parcialmente) um arquivo gerado pelo script de backup.
- `relatorio-pacotes.sh`: Relatórios/diff de pacotes para limpeza.
- `install.sh`: Cria symlinks convenientes em `~/.local/bin`.

Diretório padrão de saída de backups: `~/backups`.

Estrutura interna do arquivo de backup (`env-backup-YYYYMMDD-HHMMSS.tar.zst`):
```
categories/
  user_configs/      # ~/.config, dotfiles, (~/.local se FULL_USER_LOCAL=1)
  user_configs_clean/
  scripts/           # ~/.local/bin, ~/bin, ~/scripts + SCRIPT_EXTRA_PATHS
  themes/            # ~/.themes, ~/.icons, wallpapers
  system_themes/     # /usr/share/themes, /usr/share/icons (completo por padrão)
  packages/          # listas pacman/AUR
  services/          # systemd units
  system_configs/    # /etc configs
  php/               # /etc/php/
  httpd/             # /etc/httpd/
  keys/              # ~/.ssh, ~/.gnupg
  custom/            # caminhos customizados
meta/
  manifest.sha256    # checksums
  metadata.json      # metadados estruturados
  summary.txt        # resumo legível
  category-summary.txt # contadores por categoria
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
backup-env --no-sudo --profile full
restore-env --dry-run --categories "user_configs_clean scripts"
pkg-report --diff --orphans
```