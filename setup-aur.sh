#!/usr/bin/env bash
# Script para configuração inicial do AUR

set -euo pipefail

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[SETUP]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

show_ssh_key() {
    log "Sua chave SSH pública para adicionar ao AUR:"
    echo
    echo "=============================================="
    
    # Encontrar e mostrar chave SSH pública
    local found_key=false
    for key_type in ed25519 rsa ecdsa; do
        local pub_key="$HOME/.ssh/id_$key_type.pub"
        if [[ -f "$pub_key" ]]; then
            cat "$pub_key"
            found_key=true
            break
        fi
    done
    
    if [[ "$found_key" == "false" ]]; then
        echo "NENHUMA CHAVE SSH ENCONTRADA!"
        echo
        echo "Gere uma chave SSH primeiro:"
        echo "  ssh-keygen -t ed25519 -C \"seu-email@exemplo.com\""
    fi
    
    echo "=============================================="
    echo
}

configure_ssh() {
    log "Configurando SSH para AUR..."
    
    # Detectar chave SSH existente
    local ssh_key=""
    for key_type in rsa ed25519 ecdsa; do
        if [[ -f "$HOME/.ssh/id_$key_type" ]]; then
            ssh_key="~/.ssh/id_$key_type"
            break
        fi
    done
    
    if [[ -z "$ssh_key" ]]; then
        warn "Nenhuma chave SSH encontrada. Gere uma com:"
        echo "  ssh-keygen -t ed25519 -C \"seu-email@exemplo.com\""
        return 1
    fi
    
    # Criar configuração SSH para AUR
    if ! grep -q "Host aur.archlinux.org" ~/.ssh/config 2>/dev/null; then
        mkdir -p ~/.ssh
        echo "" >> ~/.ssh/config
        echo "Host aur.archlinux.org" >> ~/.ssh/config
        echo "  HostName aur.archlinux.org" >> ~/.ssh/config
        echo "  User aur" >> ~/.ssh/config
        echo "  IdentityFile $ssh_key" >> ~/.ssh/config
        echo "  StrictHostKeyChecking accept-new" >> ~/.ssh/config
        success "Configuração SSH adicionada"
    else
        warn "Configuração SSH já existe"
    fi
}

test_ssh() {
    log "Testando conexão SSH com AUR..."
    
    if ssh -T aur@aur.archlinux.org 2>&1 | grep -q "successfully authenticated"; then
        success "SSH configurado corretamente!"
        return 0
    else
        warn "SSH ainda não configurado ou pacote não existe no AUR"
        return 1
    fi
}

create_local_test() {
    log "Criando teste local do pacote..."
    
    cd "$(dirname "${BASH_SOURCE[0]}")"
    
    # Construir pacote localmente
    if [[ -x "./build-package.sh" ]]; then
        log "Construindo pacote para teste..."
        ./build-package.sh --build
        success "Pacote construído com sucesso!"
        
        warn "Para instalar localmente:"
        echo "  sudo pacman -U build/ambiente-backup-*.pkg.tar.*"
        echo
        warn "Para testar:"
        echo "  ./test-installation.sh"
    else
        error "Script build-package.sh não encontrado"
    fi
}

show_instructions() {
    cat << EOF

${YELLOW}📋 INSTRUÇÕES PARA CONFIGURAR O AUR${NC}

${BLUE}1. Adicionar chave SSH ao AUR:${NC}
   • Acesse: https://aur.archlinux.org/
   • Faça login ou crie uma conta
   • Vá em "My Account" → "SSH Public Keys"
   • Adicione sua chave SSH (mostrada acima)

${BLUE}2. Criar o pacote pela primeira vez:${NC}
   • Após configurar a chave SSH, execute:
     ./setup-aur.sh --create-package

${BLUE}3. Testar localmente antes de publicar:${NC}
   • Execute: ./build-package.sh --install
   • Teste: ./test-installation.sh

${BLUE}4. Publicar no AUR:${NC}
   • Após testes, execute: ./publish-aur.sh --setup
   • Depois: ./publish-aur.sh --publish

${GREEN}💡 DICA:${NC} Comece testando localmente primeiro!

EOF
}

create_first_package() {
    log "Criando pacote AUR pela primeira vez..."
    
    # Tentar criar o repositório vazio
    if test_ssh; then
        log "SSH OK, tentando criar repositório..."
        
        mkdir -p aur-ambiente-backup
        cd aur-ambiente-backup
        
        # Inicializar repositório git vazio
        git init
        git remote add origin ssh://aur@aur.archlinux.org/ambiente-backup.git
        
        # Criar arquivos iniciais
        cp ../PKGBUILD .
        makepkg --printsrcinfo > .SRCINFO
        
        # Commit inicial
        git add PKGBUILD .SRCINFO
        git commit -m "Initial commit for ambiente-backup"
        
        # Push inicial (isso criará o pacote no AUR)
        git push -u origin master
        
        success "Pacote criado no AUR com sucesso!"
    else
        error "Configure sua chave SSH primeiro!"
        show_instructions
    fi
}

main() {
    echo -e "${BLUE}=== Configuração do AUR para ambiente-backup ===${NC}"
    echo
    
    case "${1:-help}" in
        --show-key)
            show_ssh_key
            ;;
        --configure-ssh)
            configure_ssh
            ;;
        --test-ssh)
            test_ssh
            ;;
        --build-local)
            create_local_test
            ;;
        --create-package)
            create_first_package
            ;;
        --full-setup)
            show_ssh_key
            configure_ssh
            warn "Agora adicione sua chave SSH ao AUR, depois execute:"
            warn "./setup-aur.sh --create-package"
            ;;
        *)
            show_ssh_key
            configure_ssh
            show_instructions
            create_local_test
            ;;
    esac
}

main "$@"