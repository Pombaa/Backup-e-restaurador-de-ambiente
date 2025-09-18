#!/usr/bin/env bash
# Script de instalação automática do ambiente-backup

set -euo pipefail

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INSTALL]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_system() {
    log "Verificando sistema..."
    
    if ! command -v pacman &> /dev/null; then
        error "Este script é apenas para Arch Linux (pacman não encontrado)"
    fi
    
    if ! command -v yay &> /dev/null; then
        warn "yay não encontrado, tentando instalar..."
        install_yay
    fi
    
    success "Sistema compatível"
}

install_yay() {
    log "Instalando yay..."
    
    # Instalar dependências
    sudo pacman -S --needed --noconfirm base-devel git
    
    # Clonar e compilar yay
    cd /tmp
    rm -rf yay
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    
    success "yay instalado com sucesso"
}

sync_databases() {
    log "Sincronizando bases de dados..."
    
    # Sincronizar repositórios oficiais
    sudo pacman -Sy --noconfirm
    
    # Sincronizar AUR (forçar atualização)
    yay -Syy --noconfirm
    
    success "Bases de dados sincronizadas"
}

install_ambiente_backup() {
    log "Instalando ambiente-backup..."
    
    # Tentar instalação via yay
    if yay -S ambiente-backup --noconfirm; then
        success "ambiente-backup instalado via yay!"
        return 0
    fi
    
    warn "Instalação via yay falhou, tentando método manual..."
    
    # Método manual (backup)
    cd /tmp
    rm -rf ambiente-backup
    git clone https://aur.archlinux.org/ambiente-backup.git
    cd ambiente-backup
    makepkg -si --noconfirm
    
    success "ambiente-backup instalado manualmente!"
}

test_installation() {
    log "Testando instalação..."
    
    local commands=(ambiente-backup backup-ambiente backup-env restore-env)
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            success "Comando '$cmd' disponível"
        else
            error "Comando '$cmd' não encontrado"
        fi
    done
    
    success "Instalação testada com sucesso!"
}

show_completion() {
    echo
    success "🎉 Instalação concluída!"
    echo
    echo -e "${GREEN}Comandos disponíveis:${NC}"
    echo "  • ambiente-backup     (interface principal)"
    echo "  • backup-ambiente     (alias)"
    echo "  • backup-env          (só backup)"
    echo "  • restore-env         (só restauração)"
    echo
    echo -e "${BLUE}Para usar:${NC}"
    echo "  ambiente-backup"
    echo
    echo -e "${BLUE}Ou procure no menu:${NC} Sistema → Ambiente Backup"
    echo
}

main() {
    echo -e "${BLUE}=== Instalador Ambiente Backup ===${NC}"
    echo "Sistema completo de backup e restauração de ambiente Linux"
    echo
    
    check_system
    sync_databases
    install_ambiente_backup
    test_installation
    show_completion
}

# Verificar se está sendo executado como root
if [[ $EUID -eq 0 ]]; then
    error "Não execute este script como root. Use seu usuário normal."
fi

main "$@"