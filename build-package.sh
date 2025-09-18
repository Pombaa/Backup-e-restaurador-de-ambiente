#!/usr/bin/env bash
# Script para criar pacote AUR do ambiente-backup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PKG_NAME="ambiente-backup"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[BUILD]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

check_dependencies() {
    log "Verificando dependências..."
    
    local deps=(makepkg git)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Dependência não encontrada: $dep"
        fi
    done
    
    success "Todas as dependências encontradas"
}

prepare_build() {
    log "Preparando diretório de build..."
    
    # Limpar build anterior
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Copiar PKGBUILD
    cp "$SCRIPT_DIR/PKGBUILD" "$BUILD_DIR/"
    
    cd "$BUILD_DIR"
    success "Diretório de build preparado"
}

build_package() {
    log "Construindo pacote..."
    
    cd "$BUILD_DIR"
    
    # Atualizar checksums se necessário
    if [[ "${UPDATE_CHECKSUMS:-0}" == "1" ]]; then
        log "Atualizando checksums..."
        updpkgsums
    fi
    
    # Construir pacote
    makepkg -sf --noconfirm
    
    success "Pacote construído com sucesso!"
}

install_package() {
    log "Instalando pacote..."
    
    cd "$BUILD_DIR"
    
    # Encontrar o pacote construído
    local pkg_file
    pkg_file=$(find . -name "${PKG_NAME}-*.pkg.tar.*" | head -1)
    
    if [[ -z "$pkg_file" ]]; then
        error "Pacote não encontrado após build"
    fi
    
    log "Instalando $pkg_file..."
    sudo pacman -U "$pkg_file" --noconfirm
    
    success "Pacote instalado com sucesso!"
}

test_installation() {
    log "Testando instalação..."
    
    # Testar comandos principais
    local commands=(ambiente-backup backup-ambiente backup-env restore-env)
    
    for cmd in "${commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            success "Comando '$cmd' disponível"
        else
            error "Comando '$cmd' não encontrado"
        fi
    done
    
    # Testar se arquivos estão no lugar
    local files=(
        "/usr/share/ambiente-backup/ambiente-gui.sh"
        "/usr/share/applications/ambiente-backup.desktop"
        "/usr/share/doc/ambiente-backup/README.md"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            success "Arquivo '$file' instalado"
        else
            error "Arquivo '$file' não encontrado"
        fi
    done
    
    success "Instalação testada com sucesso!"
}

show_usage() {
    cat << EOF
Uso: $0 [opções]

Opções:
    -h, --help              Mostra esta ajuda
    -b, --build             Apenas constrói o pacote
    -i, --install           Constrói e instala o pacote
    -t, --test              Testa a instalação atual
    -c, --clean             Limpa arquivos de build
    -u, --update-checksums  Atualiza checksums antes de construir

Exemplos:
    $0 --build              # Apenas constrói
    $0 --install            # Constrói e instala
    $0 --test               # Testa instalação
EOF
}

main() {
    local action=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -b|--build)
                action="build"
                shift
                ;;
            -i|--install)
                action="install"
                shift
                ;;
            -t|--test)
                action="test"
                shift
                ;;
            -c|--clean)
                action="clean"
                shift
                ;;
            -u|--update-checksums)
                export UPDATE_CHECKSUMS=1
                shift
                ;;
            *)
                error "Opção desconhecida: $1"
                ;;
        esac
    done
    
    case "$action" in
        build)
            check_dependencies
            prepare_build
            build_package
            success "Pacote disponível em: $BUILD_DIR"
            ;;
        install)
            check_dependencies
            prepare_build
            build_package
            install_package
            test_installation
            ;;
        test)
            test_installation
            ;;
        clean)
            log "Limpando arquivos de build..."
            rm -rf "$BUILD_DIR"
            success "Arquivos de build removidos"
            ;;
        *)
            show_usage
            error "Ação não especificada. Use --help para ver opções."
            ;;
    esac
}

main "$@"