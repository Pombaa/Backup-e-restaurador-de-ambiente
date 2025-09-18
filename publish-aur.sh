#!/usr/bin/env bash
# Script para publicar no AUR

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUR_DIR="$SCRIPT_DIR/aur-ambiente-backup"
PKG_NAME="ambiente-backup"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[AUR]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

check_dependencies() {
    log "Verificando dependências para publicação no AUR..."
    
    local deps=(git ssh makepkg)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Dependência não encontrada: $dep"
        fi
    done
    
    # Verificar se tem chave SSH configurada para AUR
    if ! ssh -T aur@aur.archlinux.org 2>&1 | grep -q "successfully authenticated"; then
        warn "Chave SSH para AUR não configurada ou não funcionando"
        warn "Configure sua chave SSH seguindo: https://wiki.archlinux.org/title/Arch_User_Repository#Authentication"
    fi
    
    success "Dependências verificadas"
}

setup_aur_repo() {
    log "Configurando repositório AUR..."
    
    if [[ -d "$AUR_DIR" ]]; then
        log "Diretório AUR já existe, atualizando..."
        cd "$AUR_DIR"
        git pull
    else
        log "Clonando repositório AUR..."
        git clone "ssh://aur@aur.archlinux.org/${PKG_NAME}.git" "$AUR_DIR"
        cd "$AUR_DIR"
    fi
    
    success "Repositório AUR configurado"
}

update_aur_files() {
    log "Atualizando arquivos no repositório AUR..."
    
    cd "$AUR_DIR"
    
    # Copiar PKGBUILD
    cp "$SCRIPT_DIR/PKGBUILD" .
    
    # Atualizar checksums
    log "Atualizando checksums..."
    updpkgsums
    
    # Testar build
    log "Testando build..."
    makepkg --printsrcinfo > .SRCINFO
    
    success "Arquivos AUR atualizados"
}

commit_and_push() {
    log "Fazendo commit e push para AUR..."
    
    cd "$AUR_DIR"
    
    # Verificar se há mudanças
    if ! git diff --quiet || ! git diff --cached --quiet; then
        # Adicionar arquivos
        git add PKGBUILD .SRCINFO
        
        # Commit
        local version
        version=$(grep "pkgver=" PKGBUILD | cut -d'=' -f2)
        git commit -m "Update to version $version"
        
        # Push
        git push
        
        success "Pacote publicado no AUR com sucesso!"
        success "Usuários podem instalar com: yay -S $PKG_NAME"
    else
        warn "Nenhuma mudança detectada, nada para publicar"
    fi
}

show_instructions() {
    cat << EOF

${GREEN}🎉 Pacote configurado para o AUR!${NC}

${YELLOW}Para publicar no AUR pela primeira vez:${NC}
1. Configure sua chave SSH no AUR: https://wiki.archlinux.org/title/Arch_User_Repository#Authentication
2. Execute: ./publish-aur.sh --setup
3. Execute: ./publish-aur.sh --publish

${YELLOW}Para atualizar uma versão existente:${NC}
1. Atualize a versão no PKGBUILD
2. Execute: ./publish-aur.sh --publish

${YELLOW}Para usuários instalarem:${NC}
# Com yay
yay -S ambiente-backup

# Com pacman (após compilar)
git clone https://aur.archlinux.org/ambiente-backup.git
cd ambiente-backup
makepkg -si

${YELLOW}Comandos disponíveis após instalação:${NC}
- ambiente-backup     # Interface principal (GUI)
- backup-ambiente     # Alias alternativo
- backup-env          # Interface de backup
- restore-env         # Interface de restauração

EOF
}

main() {
    local action=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup)
                action="setup"
                shift
                ;;
            --publish)
                action="publish"
                shift
                ;;
            --instructions)
                action="instructions"
                shift
                ;;
            -h|--help)
                cat << EOF
Uso: $0 [opção]

Opções:
    --setup         Configura repositório AUR
    --publish       Publica/atualiza no AUR
    --instructions  Mostra instruções completas
    --help          Mostra esta ajuda
EOF
                exit 0
                ;;
            *)
                error "Opção desconhecida: $1"
                ;;
        esac
    done
    
    case "$action" in
        setup)
            check_dependencies
            setup_aur_repo
            success "Setup concluído. Use --publish para publicar"
            ;;
        publish)
            check_dependencies
            setup_aur_repo
            update_aur_files
            commit_and_push
            ;;
        instructions)
            show_instructions
            ;;
        *)
            show_instructions
            ;;
    esac
}

main "$@"