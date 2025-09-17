#!/usr/bin/env bash
# ============================================================================
# restaurar-ambiente.sh
# ============================================================================
# Objetivo: Restauração do backup modular criado por backup-completo.sh (>=1.2.0)
# Estrutura esperada do arquivo: (tar.{gz|xz|zst}) contendo diretórios:
#   categories/ <subpastas de cada categoria>
#   meta/manifest.sha256  meta/metadata.json  meta/summary.txt
#
# Este script NÃO cria backup, apenas aplica (com várias opções de filtro) e
# pode verificar integridade do manifest.
#
# Categorias suportadas (devem existir em categories/ para serem aplicadas):
#   user_configs user_configs_clean scripts themes system_themes packages packages_explicit \
#   services system_configs php httpd keys custom_paths
#
# Principais flags:
#   --archive ARQ.tar.gz   Arquivo do backup (se ausente: tenta último em ~/backups)
#   --list-categories      Lista categorias presentes no arquivo e sai
#   --categories "a b"     Limita restauração às categorias listadas
#   --dry-run              Mostra o que faria sem alterar o sistema
#   --no-packages          Não instala pacotes
#   --only-explicit        Instala somente pacotes explicitamente instalados
#   --no-services          Não habilita services
#   --no-system            Não aplica configs de /etc nem php/httpd nem system_themes system
#   --themes-user          Restaura system_themes dentro de ~/.themes / ~/.icons
#   --with-keys            Aplica categoria keys (~/.ssh ~/.gnupg) (padrão = ignora)
#   --verify               Verifica manifest (sha256)
#   --keep-tmp             Mantém diretório temporário extraído
#   --keep-existing        (Futuro) tenta não sobrescrever arquivos existentes (ainda não implementado)
#   --help                 Ajuda
#
# NOTA: "packages" e "packages_explicit" são mutuamente redundantes. Se ambas
# existirem e forem selecionadas, packages_explicit é suficiente para instalação.
# ============================================================================
set -euo pipefail

VERSION="1.0.0"

log()  { printf "[restaurar] %s\n" "$*" >&2; }
warn() { printf "[restaurar][WARN] %s\n" "$*" >&2; }
err()  { printf "[restaurar][ERRO] %s\n" "$*" >&2; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { warn "Comando '$1' ausente"; return 1; }; }

usage(){ sed -n '/^# Objetivo:/,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//'; cat <<EOF
Uso: $0 [opções]
    --archive ARQUIVO       Arquivo do backup (auto-detecta se omitido)
    --list-categories       Lista categorias presentes e sai
    --categories "a b"       Restringe a estas categorias
    --dry-run               Não aplica nada (mostra ações)
    --no-packages           Não instala pacotes
    --only-explicit         Usa só listas explícitas (ignora all.txt)
    --no-services           Não habilita systemd units
    --no-system             Não aplica system_configs php httpd nem system_themes no /usr/share
    --themes-user           Instala system_themes no HOME (ignora /usr/share)
    --with-keys             Aplica chaves ~/.ssh ~/.gnupg
    --verify                Verifica manifest sha256 antes de aplicar
    --keep-tmp              Mantém diretório temporário após execução
    --keep-existing         (placeholder) evitar sobrescrita agressiva
    --help                  Esta ajuda
EOF
}

die(){ err "$1"; exit 1; }

# ----------------------------- Parse args ----------------------------------
ARCHIVE=""
DRY_RUN=0 APPLY_PACKAGES=1 APPLY_SERVICES=1 APPLY_SYSTEM=1 APPLY_KEYS=0 THEMES_MODE="system" ONLY_EXPLICIT=0 VERIFY=0 KEEP_TMP=0 KEEP_EXISTING=0
USER_CATEGORIES=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --archive) shift; ARCHIVE="${1:-}" ;;
        --categories) shift; read -r -a USER_CATEGORIES <<< "${1:-}" ;;
        --list-categories) LIST_ONLY=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --no-packages) APPLY_PACKAGES=0 ;;
        --only-explicit) ONLY_EXPLICIT=1 ;;
        --no-services) APPLY_SERVICES=0 ;;
        --no-system) APPLY_SYSTEM=0 ;;
        --themes-user) THEMES_MODE="user" ;;
        --with-keys) APPLY_KEYS=1 ;;
        --verify) VERIFY=1 ;;
        --keep-tmp) KEEP_TMP=1 ;;
        --keep-existing) KEEP_EXISTING=1 ;;
        --help|-h) usage; exit 0 ;;
        *) err "Opção desconhecida: $1"; usage; exit 1 ;;
    esac; shift || true
done

# ------------------------- Localizar arquivo -------------------------------
if [[ -z "$ARCHIVE" ]]; then
    # Procura último env-backup-* em ~/backups (padrão do backup-completo.sh)
    ARCHIVE=$(ls -1t "$HOME"/backups/env-backup-*.tar.* 2>/dev/null | head -n1 || true)
fi
[[ -n "$ARCHIVE" ]] || die "Nenhum arquivo informado/ encontrado"
[[ -f "$ARCHIVE" ]] || die "Arquivo não existe: $ARCHIVE"

# ------------------------ Extrair para TMP ---------------------------------
TMPDIR=$(mktemp -d -t restore-env-XXXXXX)
log "Extraindo '$ARCHIVE' em $TMPDIR"
case "$ARCHIVE" in
    *.tar.gz|*.tgz) tar -xzf "$ARCHIVE" -C "$TMPDIR" ;;
    *.tar.xz)       tar -xJf "$ARCHIVE" -C "$TMPDIR" ;;
    *.tar.zst|*.tar.zstd)
            if tar --help 2>&1 | grep -qi -- '--zstd'; then
                tar --zstd -xf "$ARCHIVE" -C "$TMPDIR"
            else
                need_cmd zstd || die "zstd não disponível para descompactar"
                cp "$ARCHIVE" "$TMPDIR/" && ( cd "$TMPDIR" && zstd -d "$(basename "$ARCHIVE")" && tar -xf "${ARCHIVE##*/%.zst}" )
            fi ;;
    *.tar)          tar -xf "$ARCHIVE" -C "$TMPDIR" ;;
    *) die "Formato não suportado: $ARCHIVE" ;;
esac

[[ -d "$TMPDIR/categories" ]] || die "Estrutura inválida: falta categories/"

CATEGORIES_PRESENT=($(cd "$TMPDIR/categories" && find . -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort))

if [[ ${LIST_ONLY:-0} -eq 1 ]]; then
    echo "Categorias no arquivo: ${CATEGORIES_PRESENT[*]}"
    exit 0
fi

# Determinar categorias a aplicar
if [[ ${#USER_CATEGORIES[@]} -gt 0 ]]; then
    RESTORE_CATEGORIES=("${USER_CATEGORIES[@]}")
else
    RESTORE_CATEGORIES=("${CATEGORIES_PRESENT[@]}")
fi

log "Categorias disponíveis: ${CATEGORIES_PRESENT[*]}"
log "Categorias selecionadas: ${RESTORE_CATEGORIES[*]}"

# -------------------------- Manifest / Verify ------------------------------
if [[ $VERIFY -eq 1 ]]; then
    if [[ -f "$TMPDIR/meta/manifest.sha256" ]]; then
        log "Verificando manifest..."
        ( cd "$TMPDIR" && sha256sum -c meta/manifest.sha256 >/dev/null ) || die "Falha na verificação de integridade"
        log "Manifest OK"
    else
        warn "manifest.sha256 não encontrado (pulando verificação)"
    fi
fi

# -------------------------- Helpers de cópia -------------------------------
copy_dir(){
    local src="$1" dst="$2"; [[ -d $src ]] || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "DRY-RUN copy $src -> $dst"
    else
        mkdir -p "$dst" && rsync -a "$src/" "$dst/" 2>/dev/null || cp -r "$src/." "$dst/" || true
    fi
}

# -------------------------- Pacotes ----------------------------------------
restore_packages(){
    [[ $APPLY_PACKAGES -eq 1 ]] || { log "Pacotes ignorados (--no-packages)"; return 0; }
    if [[ ! " ${RESTORE_CATEGORIES[*]} " =~ ' packages ' && ! " ${RESTORE_CATEGORIES[*]} " =~ ' packages_explicit ' ]]; then return 0; fi
    local pkgdir="$TMPDIR/categories/packages"
    [[ -d $pkgdir ]] || { warn "Categoria packages não presente"; return 0; }
    need_cmd pacman || { warn "pacman ausente"; return 0; }
    local list_exp="$pkgdir/pacman-explicit.txt" list_aur="$pkgdir/aur-explicit.txt" list_all="$pkgdir/all.txt"
    local install_list=()
    if [[ $ONLY_EXPLICIT -eq 1 ]]; then
        [[ -f $list_exp ]] && mapfile -t install_list < "$list_exp"
    else
        [[ -f $list_exp ]] && mapfile -t install_list < "$list_exp" # (mantemos somente explicit de qualquer forma)
    fi
    if [[ ${#install_list[@]} -gt 0 ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "DRY-RUN pacman -S --needed ${install_list[*]}"
        else
            sudo pacman -S --needed --noconfirm "${install_list[@]}" || warn "Falha parcial pacman"
        fi
    fi
    if [[ -f $list_aur ]]; then
        local helper=""; for h in yay paru aura trizen pikaur; do command -v $h >/dev/null 2>&1 && { helper=$h; break; }; done
        if [[ -n $helper ]]; then
            mapfile -t aur_list < "$list_aur"
            if [[ ${#aur_list[@]} -gt 0 ]]; then
                if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN $helper -S --needed ${aur_list[*]}"; else $helper -S --needed --noconfirm "${aur_list[@]}" || warn "Falha parcial AUR"; fi
            fi
        else
            warn "Sem helper AUR (yay/paru). Pulei AUR."
        fi
    fi
}

# -------------------------- Configs usuário --------------------------------
restore_user_configs(){
    for cat in user_configs user_configs_clean; do
        [[ " ${RESTORE_CATEGORIES[*]} " =~ " $cat " ]] || continue
        local src="$TMPDIR/categories/$cat"; [[ -d $src ]] || continue
        log "Aplicando $cat -> HOME"
        copy_dir "$src" "$HOME"
    done
}

# -------------------------- Scripts ----------------------------------------
restore_scripts(){
    [[ " ${RESTORE_CATEGORIES[*]} " =~ ' scripts ' ]] || return 0
    local src="$TMPDIR/categories/scripts/bin"; [[ -d $src ]] || return 0
    log "Restaurando scripts (~/.local/bin)"
    mkdir -p "$HOME/.local/bin"
    copy_dir "$src" "$HOME/.local/bin"
    [[ $DRY_RUN -eq 1 ]] || chmod -R u+rx "$HOME/.local/bin" 2>/dev/null || true
}

# -------------------------- Temas usuário ----------------------------------
restore_themes(){
    [[ " ${RESTORE_CATEGORIES[*]} " =~ ' themes ' ]] || return 0
    local src="$TMPDIR/categories/themes"; [[ -d $src ]] || return 0
    log "Restaurando temas (home)"
    for d in .themes .icons Wallpapers; do
        [[ -d $src/$d ]] || continue
        copy_dir "$src/$d" "$HOME/$d"
    done
}

# -------------------------- Temas sistema ----------------------------------
restore_system_themes(){
    [[ " ${RESTORE_CATEGORIES[*]} " =~ ' system_themes ' ]] || return 0
    local src="$TMPDIR/categories/system_themes"; [[ -d $src ]] || return 0
    log "Restaurando system_themes (modo=$THEMES_MODE)"
    if [[ $THEMES_MODE == "user" || $APPLY_SYSTEM -eq 0 ]]; then
        mkdir -p "$HOME/.themes" "$HOME/.icons"
        for item in "$src"/*; do [[ -d $item ]] || continue; copy_dir "$item" "$HOME/.themes/$(basename "$item")"; done
    else
        if [[ $DRY_RUN -eq 1 ]]; then
            find "$src" -mindepth 1 -maxdepth 1 -type d -printf "DRY-RUN copy %f => /usr/share/{themes|icons}\n"
        else
            if sudo -n true 2>/dev/null; then
                for item in "$src"/*; do [[ -d $item ]] || continue; sudo cp -r "$item" /usr/share/themes/ 2>/dev/null || sudo cp -r "$item" /usr/share/icons/ 2>/dev/null || true; done
            else
                warn "Sem sudo para system_themes (use --themes-user)"
            fi
        fi
    fi
}

# -------------------------- System configs ---------------------------------
restore_system_configs(){
    [[ " ${RESTORE_CATEGORIES[*]} " =~ ' system_configs ' ]] || return 0
    [[ $APPLY_SYSTEM -eq 1 ]] || { log "Ignorando system_configs (--no-system)"; return 0; }
    local src="$TMPDIR/categories/system_configs"; [[ -d $src ]] || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        find "$src" -type f -printf "DRY-RUN etc: %P -> /etc/%P\n"
    else
        if sudo -n true 2>/dev/null; then
            (cd "$src" && sudo rsync -a ./ /) || warn "Falha parcial system_configs"
        else
            warn "Sem sudo para aplicar system_configs"
        fi
    fi
}

# -------------------------- PHP / HTTPD ------------------------------------
restore_php_httpd(){
    for comp in php httpd; do
        [[ " ${RESTORE_CATEGORIES[*]} " =~ " $comp " ]] || continue
        [[ $APPLY_SYSTEM -eq 1 ]] || { log "Ignorando $comp (--no-system)"; continue; }
        local src="$TMPDIR/categories/$comp"; [[ -d $src ]] || continue
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "DRY-RUN aplicar $comp em /etc/$comp*"
        else
            if sudo -n true 2>/dev/null; then
                sudo rsync -a "$src/" /etc/ || warn "Falha parcial $comp"
            else
                warn "Sem sudo para $comp"
            fi
        fi
    done
}

# -------------------------- Services ---------------------------------------
restore_services(){
    [[ " ${RESTORE_CATEGORIES[*]} " =~ ' services ' ]] || return 0
    [[ $APPLY_SERVICES -eq 1 ]] || { log "Ignorando services (--no-services)"; return 0; }
    local src="$TMPDIR/categories/services"; [[ -d $src ]] || return 0
    local user_list="$src/systemd-user-enabled.txt" sys_list="$src/systemd-system-enabled.txt"
    if [[ -f $user_list ]]; then
        awk '{print $1}' "$user_list" | while read -r unit; do
            [[ $unit == *.* ]] || continue
            if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN systemctl --user enable $unit"; else systemctl --user enable "$unit" 2>/dev/null || true; fi
        done
    fi
    if [[ -f $sys_list ]]; then
        awk '{print $1}' "$sys_list" | while read -r unit; do
            [[ $unit == *.* ]] || continue
            if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN sudo systemctl enable $unit"; else if sudo -n true 2>/dev/null; then sudo systemctl enable "$unit" 2>/dev/null || true; else warn "Sem sudo p/ $unit"; fi; fi
        done
    fi
}

# -------------------------- Keys -------------------------------------------
restore_keys(){
    [[ " ${RESTORE_CATEGORIES[*]} " =~ ' keys ' ]] || return 0
    [[ $APPLY_KEYS -eq 1 ]] || { log "Ignorando keys (use --with-keys)"; return 0; }
    local src="$TMPDIR/categories/keys"; [[ -d $src ]] || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "DRY-RUN copiar chaves ~/.ssh ~/.gnupg"
    else
        mkdir -p "$HOME/.ssh" "$HOME/.gnupg"
        rsync -a "$src/.ssh/" "$HOME/.ssh/" 2>/dev/null || true
        rsync -a "$src/.gnupg/" "$HOME/.gnupg/" 2>/dev/null || true
        chmod -R go-rwx "$HOME/.ssh" "$HOME/.gnupg" 2>/dev/null || true
    fi
}

# -------------------------- Custom paths -----------------------------------
note_custom_paths(){
    [[ " ${RESTORE_CATEGORIES[*]} " =~ ' custom_paths ' ]] || return 0
    log "custom_paths: restaure manualmente conforme necessidade (ver categories/custom)"
}

[[ $DRY_RUN -eq 1 ]] && log "Modo DRY-RUN ativo (nenhuma alteração real)."

restore_packages
restore_user_configs
restore_scripts
restore_themes
restore_system_themes
restore_system_configs
restore_php_httpd
restore_services
restore_keys
note_custom_paths

if [[ $DRY_RUN -eq 1 ]]; then
    log "DRY-RUN concluído. Nenhuma modificação aplicada."
else
    log "Restauração concluída. Considere reiniciar sessão." 
fi

[[ $KEEP_TMP -eq 1 ]] && { log "Mantendo diretório temporário: $TMPDIR"; exit 0; }
rm -rf "$TMPDIR"
exit 0
