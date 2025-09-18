#!/usr/bin/env bash
# Instalador universal que funciona em qualquer sistema Linux

set -euo pipefail

VERSION="1.2.0"
INSTALL_DIR="${INSTALL_DIR:-/usr/local}"
USER_INSTALL="${USER_INSTALL:-0}"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INSTALL]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

check_dependencies() {
    log "Verificando dependências..."
    
    local deps=(bash zenity tar gzip)
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Dependências não encontradas: ${missing[*]}"
    fi
    
    success "Todas as dependências encontradas"
}

detect_install_method() {
    if [[ "$USER_INSTALL" == "1" ]] || [[ "$EUID" -ne 0 && "$INSTALL_DIR" == "/usr/local" ]]; then
        INSTALL_DIR="$HOME/.local"
        USER_INSTALL=1
        log "Instalação local do usuário em: $INSTALL_DIR"
    else
        log "Instalação sistema em: $INSTALL_DIR"
    fi
}

install_files() {
    log "Instalando arquivos..."
    
    local share_dir="$INSTALL_DIR/share/ambiente-backup"
    local bin_dir="$INSTALL_DIR/bin"
    local desktop_dir="$INSTALL_DIR/share/applications"
    local doc_dir="$INSTALL_DIR/share/doc/ambiente-backup"
    
    # Criar diretórios
    mkdir -p "$share_dir" "$bin_dir" "$desktop_dir" "$doc_dir"
    
    # Copiar scripts
    local scripts=(
        ambiente-gui.sh
        backup-completo.sh
        backup-gui.sh
        restaurar-ambiente.sh
        restore-gui.sh
        relatorio-pacotes.sh
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            cp "$script" "$share_dir/"
            chmod +x "$share_dir/$script"
            success "Instalado: $script"
        else
            warn "Script não encontrado: $script"
        fi
    done
    
    # Criar comandos principais
    create_wrapper "$bin_dir/ambiente-backup" "$share_dir/ambiente-gui.sh"
    create_wrapper "$bin_dir/backup-ambiente" "$share_dir/ambiente-gui.sh"
    create_wrapper "$bin_dir/backup-env" "$share_dir/backup-gui.sh"
    create_wrapper "$bin_dir/restore-env" "$share_dir/restore-gui.sh"
    
    # Instalar .desktop
    if [[ -f "sistema-backup.desktop" ]]; then
        sed "s|Exec=.*|Exec=$bin_dir/ambiente-backup|" sistema-backup.desktop > "$desktop_dir/ambiente-backup.desktop"
        success "Instalado: arquivo .desktop"
    fi
    
    # Documentação
    if [[ -f "README.md" ]]; then
        cp "README.md" "$doc_dir/"
        success "Instalado: documentação"
    fi
}

create_wrapper() {
    local wrapper_path="$1"
    local target_script="$2"
    
    cat > "$wrapper_path" << EOF
#!/usr/bin/env bash
# Wrapper para ambiente-backup
exec "$target_script" "\$@"
EOF
    chmod +x "$wrapper_path"
    success "Criado wrapper: $(basename "$wrapper_path")"
}

update_desktop_database() {
    if [[ "$USER_INSTALL" == "1" ]]; then
        if command -v update-desktop-database &> /dev/null; then
            update-desktop-database "$INSTALL_DIR/share/applications" 2>/dev/null || true
        fi
    else
        if command -v update-desktop-database &> /dev/null; then
            update-desktop-database /usr/share/applications 2>/dev/null || true
        fi
    fi
}

show_completion_message() {
    local bin_dir="$INSTALL_DIR/bin"
    
    success "Instalação concluída!"
    echo
    echo "📦 Arquivos instalados em: $INSTALL_DIR"
    echo "🎯 Comandos disponíveis:"
    echo "  • ambiente-backup     (interface principal)"
    echo "  • backup-ambiente     (alias)"
    echo "  • backup-env          (só backup)"
    echo "  • restore-env         (só restauração)"
    echo
    
    if [[ "$USER_INSTALL" == "1" ]]; then
        if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
            # Detectar arquivo de configuração do shell
            local shell_rc=""
            if [[ "$SHELL" == *"zsh"* ]]; then
                shell_rc="~/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]]; then
                shell_rc="~/.bashrc"
            elif [[ "$SHELL" == *"fish"* ]]; then
                shell_rc="~/.config/fish/config.fish"
            else
                shell_rc="~/.profile"
            fi
            
            warn "Adicione $bin_dir ao seu PATH:"
            echo "  echo 'export PATH=\"$bin_dir:\$PATH\"' >> $shell_rc"
            echo "  source $shell_rc"
            echo
        fi
    fi
    
    echo "🚀 Para usar:"
    echo "  $bin_dir/ambiente-backup"
    echo
    echo "📋 Para desinstalar:"
    echo "  rm -rf $INSTALL_DIR/share/ambiente-backup"
    echo "  rm -f $bin_dir/{ambiente-backup,backup-ambiente,backup-env,restore-env}"
    echo "  rm -f $INSTALL_DIR/share/applications/ambiente-backup.desktop"
}

uninstall() {
    log "Removendo ambiente-backup..."
    
    local share_dir="$INSTALL_DIR/share/ambiente-backup"
    local bin_dir="$INSTALL_DIR/bin"
    local desktop_dir="$INSTALL_DIR/share/applications"
    local doc_dir="$INSTALL_DIR/share/doc/ambiente-backup"
    
    rm -rf "$share_dir" "$doc_dir"
    rm -f "$bin_dir"/{ambiente-backup,backup-ambiente,backup-env,restore-env}
    rm -f "$desktop_dir/ambiente-backup.desktop"
    
    update_desktop_database
    
    success "ambiente-backup removido!"
}

show_help() {
    cat << EOF
Instalador Universal do Ambiente Backup v$VERSION

Uso: $0 [opções]

Opções:
  --user              Instalar apenas para o usuário atual (~/.local)
  --system            Instalar para todo o sistema (/usr/local)
  --prefix DIR        Diretório de instalação personalizado
  --uninstall         Remover instalação existente
  --help              Mostrar esta ajuda

Exemplos:
  $0                  # Instalação automática
  $0 --user           # Instalação local do usuário
  sudo $0 --system    # Instalação do sistema
  $0 --prefix /opt    # Instalação personalizada

Após a instalação, execute: ambiente-backup
EOF
}

main() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)
                USER_INSTALL=1
                INSTALL_DIR="$HOME/.local"
                shift
                ;;
            --system)
                USER_INSTALL=0
                INSTALL_DIR="/usr/local"
                shift
                ;;
            --prefix)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --uninstall)
                detect_install_method
                uninstall
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Opção desconhecida: $1"
                ;;
        esac
    done
    
    echo -e "${BLUE}=== Instalador Universal - Ambiente Backup v$VERSION ===${NC}"
    echo
    
    check_dependencies
    detect_install_method
    install_files
    update_desktop_database
    show_completion_message
}

main "$@"