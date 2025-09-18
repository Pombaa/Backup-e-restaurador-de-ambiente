#!/usr/bin/env bash
# Script para criar um repositório local que funciona com yay

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_NAME="ambiente-backup-local"
REPO_DIR="/tmp/$REPO_NAME"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[LOCAL-REPO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

create_local_repo() {
    log "Criando repositório local..."
    
    # Limpar e criar diretório
    rm -rf "$REPO_DIR"
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    
    # Copiar PKGBUILD
    cp "$SCRIPT_DIR/PKGBUILD" .
    
    # Construir pacote
    makepkg -s --noconfirm
    
    # Criar banco de dados do repositório
    repo-add "$REPO_NAME.db.tar.xz" *.pkg.tar.*
    
    success "Repositório local criado em: $REPO_DIR"
}

add_to_pacman_conf() {
    log "Adicionando repositório ao pacman.conf..."
    
    # Backup do pacman.conf
    sudo cp /etc/pacman.conf /etc/pacman.conf.backup
    
    # Adicionar repositório
    if ! grep -q "\[$REPO_NAME\]" /etc/pacman.conf; then
        echo "" | sudo tee -a /etc/pacman.conf
        echo "[$REPO_NAME]" | sudo tee -a /etc/pacman.conf
        echo "SigLevel = Optional TrustAll" | sudo tee -a /etc/pacman.conf  
        echo "Server = file://$REPO_DIR" | sudo tee -a /etc/pacman.conf
        
        success "Repositório adicionado ao pacman.conf"
    else
        warn "Repositório já existe no pacman.conf"
    fi
    
    # Atualizar base de dados
    sudo pacman -Sy
    
    success "Base de dados atualizada"
}

install_package() {
    log "Instalando pacote..."
    
    # Tentar instalar
    if sudo pacman -S ambiente-backup --noconfirm; then
        success "Pacote instalado com sucesso!"
    else
        error "Falha na instalação"
    fi
}

remove_repo() {
    log "Removendo repositório local..."
    
    # Restaurar pacman.conf
    if [[ -f /etc/pacman.conf.backup ]]; then
        sudo cp /etc/pacman.conf.backup /etc/pacman.conf
        sudo rm /etc/pacman.conf.backup
        success "pacman.conf restaurado"
    fi
    
    # Remover diretório
    rm -rf "$REPO_DIR"
    
    # Atualizar base de dados
    sudo pacman -Sy
    
    success "Repositório removido"
}

show_help() {
    cat << EOF
Repositório Local do Ambiente Backup

Uso: $0 [opção]

Opções:
    --create        Criar repositório local
    --install       Criar repositório e instalar pacote
    --remove        Remover repositório local
    --help          Mostrar esta ajuda

Após --install, você pode usar:
    pacman -S ambiente-backup
    yay -S ambiente-backup (se yay estiver configurado)

EOF
}

main() {
    case "${1:-help}" in
        --create)
            create_local_repo
            add_to_pacman_conf
            success "Repositório criado! Execute 'sudo pacman -S ambiente-backup'"
            ;;
        --install)
            create_local_repo
            add_to_pacman_conf
            install_package
            success "Pronto! Comando 'ambiente-backup' disponível"
            ;;
        --remove)
            remove_repo
            ;;
        *)
            show_help
            ;;
    esac
}

main "$@"