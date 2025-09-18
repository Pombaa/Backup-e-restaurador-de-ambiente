#!/usr/bin/env bash
# =========================================================================
# backup-completo.sh (cópia completa na pasta ambiente/)
# =========================================================================
set -euo pipefail

VERSION="1.2.1"

# Variáveis de controle (podem ser exportadas antes de rodar):
#   FULL_SYSTEM_THEMES=1     -> copia TODOS os diretórios de /usr/share/themes e /usr/share/icons (default 1)
#   FULL_USER_LOCAL=1        -> copia ~/.local inteiro dentro de user_configs (cuidado: grande)
#   SCRIPT_EXTRA_PATHS="~/bin:~/scripts:~/Projetos/util"  -> caminhos adicionais para categoria scripts
#   FULL_SYSTEM_THEMES_SKIP_PATTERNS="*-legacy:*-backup"  -> padrões (separados por :) para ignorar ao copiar system_themes
#   SYSTEM_THEMES_LIMIT=<N>  -> se definido, limita número de diretórios copiados (debug)

# Função para solicitar sudo no início (varre argumentos de forma segura)
ensure_sudo(){ 
    local no_sudo=0
    for arg in "$@"; do
        [[ "$arg" == "--no-sudo" ]] && no_sudo=1 && break
    done
    if [[ $no_sudo == 1 ]]; then
        log "Modo --no-sudo ativo - não solicitando privilégios"
        return 0
    fi
    [[ $UID -eq 0 ]] && return 0
    if ! sudo -n true 2>/dev/null; then
        if [[ -n ${DISPLAY:-} ]] && command -v zenity >/dev/null 2>&1; then
            local passwd
            passwd=$(zenity --password --title="Senha do sudo" --text="Digite a senha para obter privilégios administrativos:" 2>/dev/null) || { log "Senha cancelada pelo usuário"; return 1; }
            echo "$passwd" | sudo -S true 2>/dev/null || { log "Senha incorreta ou sudo falhou"; return 1; }
        else
            log "Solicitando sudo via terminal..."
            sudo true || return 1
        fi
    fi
    log "Privilégios administrativos obtidos com sucesso"
}

need_cmd(){ command -v "$1" >/dev/null 2>&1 || { warn "Comando '$1' ausente"; return 1; }; }

BACKUP_ROOT_DIR="${BACKUP_ROOT_DIR:-$HOME/backups}"
COMPRESS_FORMAT="${COMPRESS_FORMAT:-gz}"  # gz | xz | zst
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$BACKUP_ROOT_DIR/session-$TIMESTAMP"
META_DIR="$WORK_DIR/meta"
CATEGORY_DIR="$WORK_DIR/categories"
ARCHIVE_NAME="env-backup"
mkdir -p "$META_DIR" "$CATEGORY_DIR"

EXCLUDES=(".cache" "Cache" "*.log" "node_modules" "Trash")

PROFILE_full=(user_configs packages system_configs services php httpd keys scripts themes system_themes)
PROFILE_core=(user_configs_clean scripts themes system_themes packages_explicit services system_configs php httpd)
PROFILE_share=(user_configs_clean scripts themes packages_explicit php httpd)
PROFILE_minimal=(scripts packages_explicit)

# Funções de logging e utilitários
log(){ printf '[backup] %s\n' "$*" >&2; }
warn(){ printf '[backup][WARN] %s\n' "$*" >&2; }
err(){ printf '[backup][ERRO] %s\n' "$*" >&2; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { warn "Comando '$1' ausente"; return 1; }; }
copy_safe(){ local src="$1" dst="$2"; [[ -e $src ]] || return 0; mkdir -p "$dst" 2>/dev/null || true; if [[ -d $src ]]; then if command -v rsync >/dev/null 2>&1; then rsync -a --exclude '.git' "$src" "$dst" 2>/dev/null || cp -r "$src" "$dst" 2>/dev/null || true; else cp -r "$src" "$dst" 2>/dev/null || true; fi; else cp "$src" "$dst" 2>/dev/null || true; fi; }

list_profiles(){ echo "Perfis disponíveis:" >&2; compgen -A variable PROFILE_ | sed 's/^PROFILE_//' | sort | while read -r p; do local arr="PROFILE_${p}[@]"; echo "  - ${p}: ${!arr}" >&2; done; }

log(){ printf '[backup] %s\n' "$*" >&2; }
warn(){ printf '[backup][WARN] %s\n' "$*" >&2; }
err(){ printf '[backup][ERRO] %s\n' "$*" >&2; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { warn "Comando '$1' ausente"; return 1; }; }
copy_safe(){ local src="$1" dst="$2"; [[ -e $src ]] || return 0; mkdir -p "$dst" 2>/dev/null || true; if [[ -d $src ]]; then if command -v rsync >/dev/null 2>&1; then rsync -a --exclude '.git' "$src" "$dst" 2>/dev/null || cp -r "$src" "$dst" 2>/dev/null || true; else cp -r "$src" "$dst" 2>/dev/null || true; fi; else cp "$src" "$dst" 2>/dev/null || true; fi; }

sanitize_backup(){ local flag="${1:-0}"; [[ $flag != 1 ]] && return 0; log "Aplicando sanitização"; local targets=(user_configs_clean user_configs); local defaults=( \
".config/google-chrome" ".config/chromium" ".config/BraveSoftware" ".config/Vivaldi" ".config/spotify" ".config/discord" ".config/Slack" ".config/zoom" ".config/Signal" ".mozilla" ".cache" ".local/share/Trash" ".local/share/recently-used.xbel" ".local/share/Steam" ".local/share/virtualenvs" ".local/share/flatpak" ".local/share/containers" ".config/Code/User/workspaceStorage" ".config/Code/User/globalStorage/state.vscdb*" ); local patterns=("${defaults[@]}"); if [[ -n "${SANITIZE_EXTRA_REMOVE:-}" ]]; then local extra="${SANITIZE_EXTRA_REMOVE//:/;}"; IFS=';' read -r -a extra_arr <<< "$extra" || true; patterns+=("${extra_arr[@]}"); fi; for cat in "${targets[@]}"; do local base="$CATEGORY_DIR/$cat"; [[ -d $base ]] || continue; for p in "${patterns[@]}"; do local t="$base/$p"; if compgen -G "$t" >/dev/null 2>&1; then for match in $t; do log "Removendo (sanitize): $cat:${match#$base/}"; rm -rf "$match" || true; done; fi; done; done; find "$CATEGORY_DIR" -type f \( -name Cookies -o -name History -o -name "Login Data" \) -delete 2>/dev/null || true; }

do_user_configs(){ log "Categoria: user_configs"; local target="$CATEGORY_DIR/user_configs"; mkdir -p "$target"; log "Copiando ~/.config..."; copy_safe "$HOME/.config" "$target"; if [[ "${FULL_USER_LOCAL:-1}" == "1" ]]; then log "Copiando ~/.local (FULL_USER_LOCAL=1)..."; copy_safe "$HOME/.local" "$target"; else log "FULL_USER_LOCAL=0 -> copiando subconjunto de ~/.local"; [[ -d "$HOME/.local/share" ]] && mkdir -p "$target/.local" && copy_safe "$HOME/.local/share/applications" "$target/.local/share" && copy_safe "$HOME/.local/share/fonts" "$target/.local/share" && copy_safe "$HOME/.local/share/icons" "$target/.local/share" && copy_safe "$HOME/.local/share/themes" "$target/.local/share"; [[ -d "$HOME/.local/bin" ]] && mkdir -p "$target/.local" && copy_safe "$HOME/.local/bin" "$target/.local"; fi; local dotfiles=(.zshrc .bashrc .gitconfig .tmux.conf .vimrc .xinitrc .xprofile .profile .aliases); for f in "${dotfiles[@]}"; do [[ -f "$HOME/$f" ]] && { log "Copiando ~/$f"; copy_safe "$HOME/$f" "$target"; }; done; log "user_configs: $(find "$target" -type f | wc -l) arquivos copiados"; }
do_user_configs_clean(){ log "Categoria: user_configs_clean"; local target="$CATEGORY_DIR/user_configs_clean"; mkdir -p "$target"; local dotfiles=(.zshrc .bashrc .gitconfig .tmux.conf .vimrc .xinitrc .xprofile); for f in "${dotfiles[@]}"; do copy_safe "$HOME/$f" "$target"; done; local allow_raw="${CLEAN_CONFIG_ALLOW:-alacritty;kitty;nvim;vim;Code;code;VSCodium;gtk-3.0;gtk-4.0;xfce4;Thunar;hypr;hyprland;waybar;polybar;i3;bspwm;picom;rofi;dunst;starship;lf;ranger;tmux;git;zsh;bash;fish;wezterm;foot;php;httpd}"; allow_raw=${allow_raw//:/;}; IFS=';' read -r -a allow_list <<< "$allow_raw"; mkdir -p "$target/.config"; for dir in "${allow_list[@]}"; do [[ -z $dir ]] && continue; [[ -d "$HOME/.config/$dir" ]] && copy_safe "$HOME/.config/$dir" "$target/.config"; done; copy_safe "$HOME/.local/share/applications" "$target"; copy_safe "$HOME/.local/share/fonts" "$target"; }
do_scripts(){ log "Categoria: scripts"; local target="$CATEGORY_DIR/scripts"; mkdir -p "$target/bin"; local sources=(); [[ -d "$HOME/.local/bin" ]] && sources+=("$HOME/.local/bin"); [[ -d "$HOME/bin" ]] && sources+=("$HOME/bin"); [[ -d "$HOME/scripts" ]] && sources+=("$HOME/scripts"); [[ -d "$HOME/.scripts" ]] && sources+=("$HOME/.scripts"); if [[ -n "${SCRIPT_EXTRA_PATHS:-}" ]]; then IFS=':' read -r -a extra_paths <<< "${SCRIPT_EXTRA_PATHS}"; for p in "${extra_paths[@]}"; do p_expanded=$(eval echo "$p"); [[ -d "$p_expanded" ]] && sources+=("$p_expanded"); done; fi; if [[ ${#sources[@]} -eq 0 ]]; then warn "Nenhuma pasta de scripts encontrada"; return 0; fi; for s in "${sources[@]}"; do log "Copiando scripts de $s"; copy_safe "$s" "$target/bin"; done; local total=$(find "$target/bin" -maxdepth 5 -type f 2>/dev/null | wc -l); log "scripts: $total arquivos copiados"; }
do_themes(){ 
    log "Categoria: themes"
    local target="$CATEGORY_DIR/themes"
    mkdir -p "$target"
    local copied=0
    
    # Temas do usuário
    if [[ -d "$HOME/.themes" ]]; then 
        log "Copiando ~/.themes..."
        copy_safe "$HOME/.themes" "$target"
        copied=1
    fi
    
    if [[ -d "$HOME/.icons" ]]; then 
        log "Copiando ~/.icons..."
        copy_safe "$HOME/.icons" "$target"
        copied=1
    fi
    
    # Wallpapers - múltiplos locais comuns
    local wallpaper_dirs=(
        "$HOME/Imagens/Wallpapers"
        "$HOME/Pictures/Wallpapers" 
        "$HOME/Wallpapers"
        "$HOME/.local/share/wallpapers"
    )
    
    for walldir in "${wallpaper_dirs[@]}"; do
        if [[ -d "$walldir" ]]; then
            log "Copiando $(basename "$walldir") de $(dirname "$walldir")..."
            copy_safe "$walldir" "$target" 2>/dev/null || true
            copied=1
            break # Apenas um diretório de wallpaper
        fi
    done
    
    [[ $copied -eq 1 ]] && log "themes: $(find "$target" -type f 2>/dev/null | wc -l) arquivos copiados" || warn "Nenhuma pasta de tema encontrada"
}
do_system_themes(){ log "Categoria: system_themes"; local target="$CATEGORY_DIR/system_themes"; mkdir -p "$target"; local full="${FULL_SYSTEM_THEMES:-1}"; local skip_raw="${FULL_SYSTEM_THEMES_SKIP_PATTERNS:-}"; IFS=':' read -r -a skip_list <<< "$skip_raw"; if [[ "$full" == "1" ]]; then log "FULL_SYSTEM_THEMES=1 -> copiando /usr/share/themes e /usr/share/icons completos"; for dir in /usr/share/themes /usr/share/icons; do if [[ -d $dir ]]; then for item in "$dir"/*; do [[ -d $item ]] || continue; base_item="$(basename "$item")"; local skip=0; for pat in "${skip_list[@]}"; do [[ -n $pat && $base_item == $pat ]] && { skip=1; break; }; done; [[ $skip -eq 1 ]] && { log "Ignorando (padrão): $base_item"; continue; }; copy_safe "$item" "$target"; done; fi; done; else log "FULL_SYSTEM_THEMES=0 -> modo seletivo"; local names=(); for d in "$HOME/.themes"/* "$HOME/.icons"/*; do [[ -d $d ]] || continue; names+=("$(basename "$d")"); done; [[ -n "${XCURSOR_THEME:-}" ]] && names+=("$XCURSOR_THEME"); if command -v gsettings >/dev/null 2>&1; then local gtk_theme icon_theme cursor_theme; gtk_theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'") || true; icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'") || true; cursor_theme=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'") || true; [[ -n $gtk_theme ]] && names+=("$gtk_theme"); [[ -n $icon_theme ]] && names+=("$icon_theme"); [[ -n $cursor_theme ]] && names+=("$cursor_theme"); fi; local uniq=(); declare -A seen; for n in "${names[@]}"; do [[ -z $n || -n ${seen[$n]:-} ]] && continue; uniq+=("$n"); seen[$n]=1; done; if [[ ${#uniq[@]} -eq 0 ]]; then warn "Nenhum tema do sistema"; return 0; fi; log "Temas encontrados: ${uniq[*]}"; for n in "${uniq[@]}"; do for base in /usr/share/themes /usr/share/icons; do [[ -d "$base/$n" ]] && { log "Copiando $base/$n"; copy_safe "$base/$n" "$target"; }; done; done; fi; [[ -n "${SYSTEM_THEMES_LIMIT:-}" ]] && find "$target" -mindepth 1 -maxdepth 1 -type d | head -n "${SYSTEM_THEMES_LIMIT}" > "$target/.keep_list.tmp" && find "$target" -mindepth 1 -maxdepth 1 -type d | grep -vxF -f "$target/.keep_list.tmp" | xargs -r rm -rf && rm -f "$target/.keep_list.tmp"; log "system_themes: $(find "$target" -type f 2>/dev/null | wc -l) arquivos copiados"; }
do_keys(){ log "Categoria: keys"; local target="$CATEGORY_DIR/keys"; mkdir -p "$target"; local copied=0; if [[ -d "$HOME/.ssh" ]]; then log "Copiando ~/.ssh..."; copy_safe "$HOME/.ssh" "$target"; copied=1; fi; if [[ -d "$HOME/.gnupg" ]]; then log "Copiando ~/.gnupg..."; copy_safe "$HOME/.gnupg" "$target"; copied=1; fi; chmod -R go-rwx "$target" 2>/dev/null || true; [[ $copied -eq 1 ]] && log "keys: $(find "$target" -type f 2>/dev/null | wc -l) arquivos copiados" || warn "Nenhuma chave encontrada"; }
do_packages(){ log "Categoria: packages"; local target="$CATEGORY_DIR/packages"; mkdir -p "$target"; need_cmd pacman || return 0; pacman -Qqen > "$target/pacman-explicit.txt" || true; pacman -Qqem > "$target/aur-explicit.txt" || true; pacman -Qq > "$target/all.txt" || true; }
do_packages_explicit(){ log "Categoria: packages_explicit"; local target="$CATEGORY_DIR/packages"; mkdir -p "$target"; need_cmd pacman || return 0; pacman -Qqen > "$target/pacman-explicit.txt" || true; pacman -Qqem > "$target/aur-explicit.txt" || true; }
do_services() { 
    log "Categoria: services"
    local target="$CATEGORY_DIR/services"
    mkdir -p "$target"
    
    # Services do usuário (não precisa sudo)
    systemctl list-unit-files --state=enabled --user > "$target/systemd-user-enabled.txt" 2>/dev/null || true
    
    # Services do sistema (precisa sudo)
    if sudo -n true 2>/dev/null; then
        sudo systemctl list-unit-files --state=enabled > "$target/systemd-system-enabled.txt" 2>/dev/null || true
        log "services: user + system salvos"
    else
        warn "Sem sudo - apenas services do usuário salvos"
    fi
}
do_system_configs() { 
    log "Categoria: system_configs"
    local target="$CATEGORY_DIR/system_configs"
    mkdir -p "$target"
    
    if sudo -n true 2>/dev/null; then
        local etc_files=(/etc/pacman.conf /etc/makepkg.conf /etc/hosts /etc/fstab)
        for f in "${etc_files[@]}"; do
            [[ -f "$f" ]] && sudo cp "$f" "$target/" 2>/dev/null || true
        done
        
        for d in /etc/X11/xorg.conf.d /etc/systemd/system /etc/udev/rules.d; do
            [[ -d "$d" ]] && sudo cp -r "$d" "$target/" 2>/dev/null || true
        done
        
        log "system_configs: $(find "$target" -type f 2>/dev/null | wc -l) arquivos copiados"
    else
        warn "Sem sudo - system_configs ignorado"
    fi
}
do_php() {
    log "Categoria: php"
    local target="$CATEGORY_DIR/php"
    mkdir -p "$target"
    local found=0
    
    if sudo -n true 2>/dev/null; then
        if [[ -f /etc/php/php.ini ]]; then
            sudo cp /etc/php/php.ini "$target/" 2>/dev/null && {
                log "Copiado: /etc/php/php.ini"
                found=1
            } || true
        fi
        if [[ -d /etc/php ]]; then
            sudo cp -r /etc/php "$target/etc-php" 2>/dev/null && {
                log "Copiado: /etc/php/ -> etc-php/"
                found=1
            } || true
        fi
    else
        if [[ -r /etc/php/php.ini ]]; then
            cp /etc/php/php.ini "$target/" 2>/dev/null && {
                log "Copiado: /etc/php/php.ini (sem sudo)"
                found=1
            } || true
        fi
    fi
    
    [[ $found -eq 0 ]] && warn "Nenhum config PHP encontrado ou acessível"
    log "do_php concluído"
}
do_httpd() {
    log "Categoria: httpd"
    local target="$CATEGORY_DIR/httpd"
    mkdir -p "$target"
    local found=0
    
    if sudo -n true 2>/dev/null; then
        if [[ -f /etc/httpd/conf/httpd.conf ]]; then
            sudo mkdir -p "$target/conf" 2>/dev/null || true
            sudo cp /etc/httpd/conf/httpd.conf "$target/conf/" 2>/dev/null && {
                log "Copiado: /etc/httpd/conf/httpd.conf"
                found=1
            } || true
        fi
        if [[ -d /etc/httpd ]]; then
            sudo cp -r /etc/httpd "$target/etc-httpd" 2>/dev/null && {
                log "Copiado: /etc/httpd/ -> etc-httpd/"
                found=1
            } || true
        fi
    else
        if [[ -r /etc/httpd/conf/httpd.conf ]]; then
            mkdir -p "$target/conf" 2>/dev/null || true
            cp /etc/httpd/conf/httpd.conf "$target/conf/" 2>/dev/null && {
                log "Copiado: /etc/httpd/conf/httpd.conf (sem sudo)"
                found=1
            } || true
        fi
    fi
    
    [[ $found -eq 0 ]] && warn "Nenhum config HTTPD encontrado ou acessível"
    log "do_httpd concluído"
}
do_custom_paths(){ log "Categoria: custom_paths"; local target="$CATEGORY_DIR/custom"; mkdir -p "$target"; local list=(); [[ -n "${CUSTOM_PATHS:-}" ]] && IFS=":" read -r -a list <<< "$CUSTOM_PATHS"; if [[ -f "$META_DIR/custom_paths.txt" ]]; then while IFS= read -r line; do [[ -n $line ]] && list+=("$line"); done < "$META_DIR/custom_paths.txt"; fi; [[ ${#list[@]} -eq 0 ]] && { warn "Nenhum custom path"; return 0; }; for p in "${list[@]}"; do copy_safe "$p" "$target"; done; }

select_categories_ui(){ need_cmd dialog || { err "dialog não instalado"; return 1; }; local tmp=$(mktemp); dialog --checklist "Selecione categorias" 22 72 14 1 "user_configs" off 2 "user_configs_clean" on 3 "scripts" on 4 "themes" on 5 "system_themes" on 6 "packages" off 7 "packages_explicit" on 8 "system_configs" on 9 "services" on 10 "php" off 11 "httpd" off 12 "keys (sensível)" off 13 "custom_paths" off 2>"$tmp"; local res=$(<"$tmp"); rm -f "$tmp"; res=${res//\"/}; local out=(); for token in $res; do case "$token" in 1) out+=(user_configs);;2) out+=(user_configs_clean);;3) out+=(scripts);;4) out+=(themes);;5) out+=(system_themes);;6) out+=(packages);;7) out+=(packages_explicit);;8) out+=(system_configs);;9) out+=(services);;10) out+=(php);;11) out+=(httpd);;12) out+=(keys);;13) out+=(custom_paths);; esac; done; echo "${out[@]}"; }
select_categories_zenity(){ 
    need_cmd zenity || { err "zenity não instalado"; return 1; }
    
    while true; do
        # Tela inicial - seleção de perfil
        local profile
        profile=$(zenity --list --radiolist --title="Backup - Selecionar Perfil" \
            --text="Escolha um perfil de backup:" \
            --column="Sel" --column="Perfil" --column="Descrição" \
            --ok-label="Continuar" --cancel-label="Cancelar" \
            TRUE core "Essencial - Configurações principais" \
            FALSE full "Completo - Tudo incluído" \
            FALSE share "Compartilhável - Sem dados pessoais" \
            FALSE minimal "Mínimo - Apenas scripts e pacotes" \
            FALSE custom "Personalizado - Escolher categorias" \
            2>/dev/null)
        
        # Se cancelou na tela inicial, sair do programa
        if [[ $? -ne 0 ]]; then
            log "Backup cancelado pelo usuário"
            exit 0
        fi
        
        local categories=()
        
        if [[ $profile != custom ]]; then
            # Perfil pré-definido
            local var="PROFILE_${profile}[@]"
            categories=( ${!var} )
            
            # Tela de confirmação final para perfis pré-definidos
            local profile_desc=""
            case "$profile" in
                core) profile_desc="Configurações essenciais e pacotes" ;;
                full) profile_desc="Backup completo de tudo" ;;
                share) profile_desc="Backup compartilhável (sem dados pessoais)" ;;
                minimal) profile_desc="Apenas scripts e lista de pacotes" ;;
            esac
            
            if zenity --question --title="Confirmar Backup" \
                --width=400 --height=200 \
                --text="<b>Perfil:</b> $profile\n<b>Descrição:</b> $profile_desc\n\n<b>Categorias incluídas:</b>\n• ${categories[*]// /\n• }\n\nDeseja iniciar o backup agora?" \
                --ok-label="🚀 Fazer Backup" --cancel-label="⬅️ Voltar" 2>/dev/null; then
                break  # Confirmado, sair do loop
            else
                continue  # Voltar para seleção de perfil
            fi
        else
            # Perfil personalizado - mostrar categorias
            while true; do
                local sel
                sel=$(zenity --list --checklist --title="Backup - Categorias Personalizadas" \
                    --text="Escolha as categorias para backup:" \
                    --column="Sel" --column="Categoria" --column="Descrição" \
                    --ok-label="Continuar" --cancel-label="Voltar" \
                    --separator=" " \
                    FALSE user_configs "Configurações completas do usuário" \
                    TRUE user_configs_clean "Configurações limpas (sem cache)" \
                    TRUE scripts "Scripts e executáveis pessoais" \
                    TRUE themes "Temas e ícones do usuário" \
                    TRUE system_themes "Temas do sistema" \
                    FALSE packages "Todos os pacotes instalados" \
                    TRUE packages_explicit "Pacotes instalados explicitamente" \
                    TRUE services "Serviços do sistema" \
                    TRUE system_configs "Configurações do sistema (/etc)" \
                    FALSE php "Configurações PHP" \
                    FALSE httpd "Configurações Apache/Nginx" \
                    FALSE keys "Chaves SSH/GPG (sensível)" \
                    FALSE custom_paths "Caminhos personalizados" \
                    2>/dev/null)
                
                if [[ $? -ne 0 ]]; then
                    # Voltou - sair do loop interno para voltar à seleção de perfil
                    break
                fi
                
                # Se chegou aqui, tem seleção válida
                read -r -a categories <<< "$sel"
                
                # Validar se pelo menos uma categoria foi selecionada
                if [[ ${#categories[@]} -eq 0 ]]; then
                    zenity --warning --title="Nenhuma Categoria" \
                        --text="Você deve selecionar pelo menos uma categoria para o backup.\n\nTente novamente." 2>/dev/null
                    continue  # Voltar para seleção de categorias
                fi
                
                # Tela de confirmação final para categorias personalizadas
                if zenity --question --title="Confirmar Backup Personalizado" \
                    --width=400 --height=200 \
                    --text="<b>Backup Personalizado</b>\n\n<b>Categorias selecionadas:</b>\n• ${categories[*]// /\n• }\n\nDeseja iniciar o backup agora?" \
                    --ok-label="🚀 Fazer Backup" --cancel-label="⬅️ Voltar" 2>/dev/null; then
                    # Confirmado, sair dos loops
                    break 2
                else
                    continue  # Voltar para seleção de categorias
                fi
            done
            
            # Se chegou aqui e categories está vazio, significa que voltou
            if [[ ${#categories[@]} -eq 0 ]]; then
                continue  # Voltar para seleção de perfil
            fi
        fi
    done
    
    # Se escolheu custom_paths, configurar caminhos
    if printf '%s\n' "${categories[@]}" | grep -q '^custom_paths$'; then
        local custom_file="$META_DIR/custom_paths.txt"
        : > "$custom_file"
        
        while true; do
            if zenity --question --title="Caminhos Personalizados" \
                --text="Deseja adicionar um caminho personalizado para backup?" \
                --ok-label="Sim" --cancel-label="Não" 2>/dev/null; then
                
                local path
                path=$(zenity --file-selection --directory --title="Selecionar Diretório" \
                    --filename="$HOME/" 2>/dev/null)
                
                if [[ $? -eq 0 && -n $path ]]; then
                    echo "$path" >> "$custom_file"
                    zenity --info --title="Caminho Adicionado" \
                        --text="Caminho adicionado: $path" 2>/dev/null
                fi
            else
                break
            fi
        done
    fi
    
    echo "${categories[@]}"
}

generate_manifest(){ log "Gerando manifest"; ( cd "$WORK_DIR" && find categories -type f -print0 | sort -z | xargs -0 sha256sum > "$META_DIR/manifest.sha256" ) || true; local file_count size_bytes; file_count=$(find "$WORK_DIR/categories" -type f 2>/dev/null | wc -l | awk '{print $1}'); size_bytes=$(du -sb "$WORK_DIR/categories" 2>/dev/null | awk '{print $1}'); cat > "$META_DIR/metadata.json" <<JSON
{"version":"$VERSION","timestamp":"$TIMESTAMP","archive":"PENDENTE","compression":"$COMPRESS_FORMAT","categories":"${SELECTED_CATEGORIES:-}","sanitized":"${SANITIZE:-0}","file_count":$file_count,"size_bytes":$size_bytes}
JSON
}
finalize_metadata(){ [[ -n "${FINAL_ARCHIVE:-}" ]] || return 0; local b="$(basename "$FINAL_ARCHIVE")"; sed -i "s/\"archive\": \"PENDENTE\"/\"archive\": \"$b\"/" "$META_DIR/metadata.json" 2>/dev/null || true; { echo "Backup criado: $TIMESTAMP"; echo "Arquivo: $FINAL_ARCHIVE"; echo "Formato: $COMPRESS_FORMAT"; echo "Categorias: ${SELECTED_CATEGORIES:-}"; echo "Sanitizado: ${SANITIZE:-0}"; echo "Arquivos: $(jq -r '.file_count' "$META_DIR/metadata.json" 2>/dev/null || echo '?')"; echo "Tamanho bytes: $(jq -r '.size_bytes' "$META_DIR/metadata.json" 2>/dev/null || echo '?')"; } > "$META_DIR/summary.txt"; }
create_archive(){
    log "Compactando (formato=$COMPRESS_FORMAT)"
    local base="${ARCHIVE_NAME}-${TIMESTAMP}"
    local out=""
    cd "$WORK_DIR"
    case "$COMPRESS_FORMAT" in
        gz)
            out="${base}.tar.gz"
            log "Criando arquivo tar.gz (pode demorar com muitos arquivos)..."
            tar --warning=no-file-ignored --exclude='*.sock' --exclude='*socket' -czf "$out" categories meta 2>/dev/null || tar -czf "$out" categories meta || return 1
            ;;
        xz)
            out="${base}.tar.xz"
            log "Criando arquivo tar.xz (pode demorar com muitos arquivos)..."
            tar --warning=no-file-ignored --exclude='*.sock' --exclude='*socket' -cJf "$out" categories meta 2>/dev/null || tar -cJf "$out" categories meta || return 1
            ;;
        zst)
            out="${base}.tar.zst"
            log "Criando arquivo tar.zst (pode demorar com muitos arquivos)..."
            if tar --help 2>&1 | grep -qi -- '--zstd'; then
                tar --warning=no-file-ignored --exclude='*.sock' --exclude='*socket' --zstd -cf "$out" categories meta 2>/dev/null || tar --zstd -cf "$out" categories meta || return 1
            else
                local tmpTar="${base}.tar"
                log "Criando tar temporário..."
                tar --warning=no-file-ignored --exclude='*.sock' --exclude='*socket' -cf "$tmpTar" categories meta 2>/dev/null || tar -cf "$tmpTar" categories meta || return 1
                log "Comprimindo com zstd..."
                zstd -q --rm "$tmpTar" || { err "Falha ao comprimir com zstd"; return 1; }
                mv "${tmpTar}.zst" "$out"
            fi
            ;;
        *)
            err "Formato inválido"
            return 1
            ;;
    esac
    [[ -f "$out" ]] || { err "Arquivo $out não criado"; return 1; }
    mv "$out" "$BACKUP_ROOT_DIR/" || { err "Falha ao mover $out"; return 1; }
    FINAL_ARCHIVE="$BACKUP_ROOT_DIR/$out"
    log "Arquivo final: $FINAL_ARCHIVE (tamanho $(du -h "$FINAL_ARCHIVE" | awk '{print $1}'))"
    cd - >/dev/null 2>&1 || true
}

# Resumo por categoria: gera tabela de arquivos e tamanho.
summarize_categories(){
    local summary_file="$META_DIR/category-summary.txt"
    : > "$summary_file"
    log "Gerando resumo por categoria"
    printf '%-25s %-12s %s\n' 'Categoria' 'Arquivos' 'Tamanho' | tee -a "$summary_file" >/dev/null
    printf '%-25s %-12s %s\n' '---------' '--------' '-------' | tee -a "$summary_file" >/dev/null
    local total_files=0 total_size=0
    for dir in "$CATEGORY_DIR"/*; do
        [[ -d $dir ]] || continue
        local cat="$(basename "$dir")"
        local files=$(find "$dir" -type f 2>/dev/null | wc -l | awk '{print $1}')
        local size=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
        total_files=$((total_files + files))
        total_size=$((total_size + size))
        local hsize=$(numfmt --to=iec --suffix=B $size 2>/dev/null || echo $size)
        printf '%-25s %-12s %s\n' "$cat" "$files" "$hsize" | tee -a "$summary_file" >/dev/null
    done
    local htotal=$(numfmt --to=iec --suffix=B $total_size 2>/dev/null || echo $total_size)
    printf '%-25s %-12s %s\n' 'TOTAL' "$total_files" "$htotal" | tee -a "$summary_file" >/dev/null
}

run_categories(){ local cats=("$@"); local uniq=(); declare -A seen; for c in "${cats[@]}"; do [[ -n ${seen[$c]:-} ]] && continue; uniq+=("$c"); seen[$c]=1; done; for c in "${uniq[@]}"; do case "$c" in user_configs) do_user_configs;; user_configs_clean) do_user_configs_clean;; scripts) do_scripts;; themes) do_themes;; system_themes) do_system_themes;; keys) do_keys;; packages) do_packages;; packages_explicit) do_packages_explicit;; services) do_services;; system_configs) do_system_configs;; php) do_php;; httpd) do_httpd;; custom_paths) do_custom_paths;; *) warn "Categoria desconhecida: $c";; esac; done; }
usage(){ cat <<EOF
Uso: $0 [opções]
	--profile NOME          Perfil (full core share minimal)
	--select                UI dialog
	--zenity                UI zenity
	--categories "a b"      Lista explícita
	--compression fmt       gz|xz|zst
	--custom-paths FILE     Arquivo com caminhos extras
	--sanitize              Sanitiza dados pessoais
	--no-sudo               Não solicita sudo (pula configs sistema)
	--list-profiles         Lista perfis
	--output-name NAME      Prefixo arquivo (default env-backup)
	--help                  Ajuda
EOF
}
main(){
    # Checa sudo primeiro, antes de processar argumentos
    ensure_sudo "$@"

    local selected_categories=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                shift; local p="$1"; local var="PROFILE_${p}"; [[ -n ${!var:-} ]] || { err "Perfil desconhecido: $p"; list_profiles; exit 1; };
                local arr_var="${var}[@]"; selected_categories+=( ${!arr_var} ) ;;
            --categories)
                shift; read -r -a extra <<< "$1"; selected_categories+=("${extra[@]}");;
            --compression)
                shift; COMPRESS_FORMAT="$1" ;;
            --select)
                read -r -a extra <<< "$(select_categories_ui)"; selected_categories+=("${extra[@]}");;
            --zenity)
                read -r -a extra <<< "$(select_categories_zenity)"; selected_categories+=("${extra[@]}");;
            --custom-paths)
                shift; cp "$1" "$META_DIR/custom_paths.txt" ;;
            --sanitize)
                SANITIZE=1 ;;
            --no-sudo)
                NO_SUDO=1 ;;
            --output-name)
                shift; ARCHIVE_NAME="$1" ;;
            --list-profiles)
                list_profiles; return 0 ;;
            --help|-h)
                usage; return 0 ;;
            *)
                err "Opção desconhecida: $1"; usage; return 1 ;;
        esac
        shift || true
    done

    if [[ ${#selected_categories[@]} -eq 0 ]]; then
        warn "Nenhuma categoria; usando full"
        local arr_var="PROFILE_full[@]"
        selected_categories=( ${!arr_var} )
    fi
    SELECTED_CATEGORIES="${selected_categories[*]}"

    for dep in tar find sort sha256sum; do
        need_cmd "$dep" || { err "Dependência: $dep"; exit 1; }
    done
    case "$COMPRESS_FORMAT" in
        gz) need_cmd gzip || { err "gzip ausente"; exit 1; } ;;
        xz) need_cmd xz || { err "xz ausente"; exit 1; } ;;
        zst) if ! command -v zstd >/dev/null 2>&1 && ! tar --help 2>&1 | grep -qi -- '--zstd'; then err "zstd ausente"; exit 1; fi ;;
        *) err "Formato de compressão inválido"; exit 1 ;;
    esac

    log "Iniciando backup categorias=${selected_categories[*]}"
    run_categories "${selected_categories[@]}"
    sanitize_backup "${SANITIZE:-0}"
    summarize_categories
    generate_manifest
    create_archive
    finalize_metadata
    log "Concluído. WORK_DIR: $WORK_DIR"
}
main "$@"