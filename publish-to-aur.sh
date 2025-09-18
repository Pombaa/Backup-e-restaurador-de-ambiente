#!/usr/bin/env bash
# Script simplificado para publicar no AUR

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_NAME="ambiente-backup"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[AUR]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

test_ssh() {
    log "Testando conexão SSH com AUR..."
    if ssh -o ConnectTimeout=10 -T aur@aur.archlinux.org 2>&1 | grep -q "Welcome to AUR"; then
        success "Conexão SSH OK!"
        return 0
    else
        return 1
    fi
}

create_aur_package() {
    log "Criando pacote no AUR..."
    
    cd "$SCRIPT_DIR"
    
    # Criar diretório temporário
    local temp_dir="aur-temp-$PKG_NAME"
    rm -rf "$temp_dir"
    mkdir "$temp_dir"
    cd "$temp_dir"
    
    # Inicializar repositório git
    git init
    git remote add origin "ssh://aur@aur.archlinux.org/${PKG_NAME}.git"
    
    # Copiar arquivos
    cp "../PKGBUILD" .
    
    # Gerar .SRCINFO
    makepkg --printsrcinfo > .SRCINFO
    
    # Commit inicial
    git add PKGBUILD .SRCINFO
    git commit -m "Initial release of ambiente-backup v1.2.0

Sistema completo de backup e restauração de ambiente Linux com interface gráfica.

Features:
- Interface gráfica zenity
- Backup modular de configurações
- Restauração seletiva
- Suporte a múltiplos formatos de compressão
- Integração com menu do sistema"
    
    # Push (isso cria o pacote no AUR)
    log "Publicando no AUR..."
    git push -u origin master
    
    success "Pacote publicado no AUR com sucesso!"
    success "Usuários podem instalar com: yay -S $PKG_NAME"
    
    # Limpar
    cd "$SCRIPT_DIR"
    rm -rf "$temp_dir"
}

check_pkgbuild() {
    log "Verificando PKGBUILD..."
    
    if [[ ! -f "PKGBUILD" ]]; then
        error "PKGBUILD não encontrado"
    fi
    
    # Verificar se a tag existe
    local version=$(grep "pkgver=" PKGBUILD | cut -d'=' -f2)
    if ! git tag -l | grep -q "v$version"; then
        error "Tag v$version não encontrada. Execute: git tag v$version && git push origin v$version"
    fi
    
    success "PKGBUILD válido"
}

main() {
    echo -e "${BLUE}=== Publicação no AUR - ambiente-backup ===${NC}"
    echo
    
    if ! test_ssh; then
        error "Conexão SSH falhou. Configure sua chave SSH no AUR primeiro:
1. Acesse: https://aur.archlinux.org/
2. Vá em 'My Account' → 'SSH Public Keys'  
3. Adicione sua chave SSH
4. Execute: ./setup-aur.sh --show-key (para ver a chave)"
    fi
    
    check_pkgbuild
    create_aur_package
    
    echo
    success "🎉 Pronto! Agora qualquer pessoa pode instalar com:"
    echo -e "${GREEN}yay -S ambiente-backup${NC}"
    echo
    warn "Pode levar alguns minutos para aparecer na busca do yay"
}

main "$@"