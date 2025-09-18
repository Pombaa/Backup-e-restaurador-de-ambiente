#!/usr/bin/env bash
# Script para testar a instalação completa

set -euo pipefail

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[TEST]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

test_commands() {
    log "Testando comandos disponíveis..."
    
    local commands=(
        "ambiente-backup"
        "backup-ambiente" 
        "backup-env"
        "restore-env"
    )
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            success "Comando '$cmd' disponível"
        else
            error "Comando '$cmd' não encontrado"
            return 1
        fi
    done
}

test_files() {
    log "Testando arquivos instalados..."
    
    local files=(
        "/usr/share/ambiente-backup/ambiente-gui.sh"
        "/usr/share/ambiente-backup/backup-completo.sh"
        "/usr/share/ambiente-backup/restaurar-ambiente.sh"
        "/usr/share/applications/ambiente-backup.desktop"
        "/usr/share/doc/ambiente-backup/README.md"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            success "Arquivo '$file' presente"
        else
            error "Arquivo '$file' não encontrado"
            return 1
        fi
    done
}

test_desktop_integration() {
    log "Testando integração com desktop..."
    
    # Verificar se .desktop é válido
    if command -v desktop-file-validate &> /dev/null; then
        if desktop-file-validate /usr/share/applications/ambiente-backup.desktop 2>/dev/null; then
            success "Arquivo .desktop é válido"
        else
            warn "Arquivo .desktop pode ter problemas"
        fi
    else
        warn "desktop-file-validate não disponível para teste"
    fi
}

test_execution() {
    log "Testando execução básica..."
    
    # Testar se o comando principal executa (apenas help)
    if ambiente-backup --help &> /dev/null; then
        success "Comando ambiente-backup executa corretamente"
    else
        error "Comando ambiente-backup falhou"
        return 1
    fi
}

test_package_info() {
    log "Verificando informações do pacote..."
    
    if command -v pacman &> /dev/null; then
        if pacman -Qi ambiente-backup &> /dev/null; then
            success "Pacote ambiente-backup está instalado"
            pacman -Qi ambiente-backup | grep -E "^(Name|Version|Description)"
        else
            warn "Pacote não instalado via pacman (pode ser instalação manual)"
        fi
    fi
}

main() {
    echo -e "${BLUE}=== Teste de Instalação do Ambiente Backup ===${NC}"
    echo
    
    test_commands
    echo
    
    test_files
    echo
    
    test_desktop_integration
    echo
    
    test_execution
    echo
    
    test_package_info
    echo
    
    success "Todos os testes concluídos!"
    echo
    echo -e "${GREEN}✅ Instalação verificada com sucesso!${NC}"
    echo
    echo "Para usar o aplicativo:"
    echo "  • Digite: ambiente-backup"
    echo "  • Ou procure 'Ambiente Backup' no menu de aplicações"
}

main "$@"