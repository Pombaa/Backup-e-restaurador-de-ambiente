#!/usr/bin/env bash
# ============================================================================
# ambiente-gui.sh
# ============================================================================
# Interface gráfica unificada para sistema de backup/restauração
# Permite escolher entre fazer backup ou restaurar ambiente
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_GUI="$SCRIPT_DIR/backup-gui.sh"
RESTORE_GUI="$SCRIPT_DIR/restore-gui.sh"

log() { echo "[ambiente-gui] $*" >&2; }
err() { echo "[ambiente-gui][ERRO] $*" >&2; }
die() { err "$1"; exit 1; }

# Verificar dependências
need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Comando '$1' ausente"; return 1; }; }
need_cmd zenity || die "zenity não instalado. Instale com: sudo pacman -S zenity"

# Verificar se os scripts GUI existem
[[ -f "$BACKUP_GUI" ]] || die "GUI de backup não encontrado: $BACKUP_GUI"
[[ -f "$RESTORE_GUI" ]] || die "GUI de restauração não encontrado: $RESTORE_GUI"

# Função para mostrar informações do sistema
show_system_info() {
    local info="💻 INFORMAÇÕES DO SISTEMA\n\n"
    info+="🖥️ Hostname: $(hostname)\n"
    info+="👤 Usuário: $(whoami)\n"
    info+="📁 Home: $HOME\n"
    info+="🗂️ Backups: $HOME/backups/\n"
    info+="📦 Espaço livre: $(df -h "$HOME" | awk 'NR==2 {print $4}' 2>/dev/null || echo "?")\n\n"
    
    # Verificar backups existentes
    local backup_count=0
    if [[ -d "$HOME/backups" ]]; then
        backup_count=$(find "$HOME/backups" -name "env-backup-*.tar.*" -type f 2>/dev/null | wc -l)
    fi
    info+="📦 Backups disponíveis: $backup_count\n"
    
    # Último backup
    if [[ $backup_count -gt 0 ]]; then
        local last_backup=$(find "$HOME/backups" -name "env-backup-*.tar.*" -type f 2>/dev/null | sort | tail -1)
        if [[ -n "$last_backup" ]]; then
            local last_date=$(stat -c %y "$last_backup" 2>/dev/null | cut -d' ' -f1 || echo "?")
            local last_size=$(du -h "$last_backup" 2>/dev/null | cut -f1 || echo "?")
            info+="📅 Último backup: $last_date ($last_size)\n"
        fi
    fi
    
    zenity --info \
        --title="💻 Informações do Sistema" \
        --text="$info" \
        --width=500 --height=300 2>/dev/null
}

# Menu de ajuda geral
show_help() {
    zenity --info \
        --title="ℹ️ Ajuda - Sistema de Backup" \
        --text="🗂️ SISTEMA DE BACKUP E RESTAURAÇÃO\n\n📋 FUNCIONALIDADES:\n• 🚀 Backup: Criar cópias do seu ambiente\n• 🗃️ Restaurar: Recuperar ambiente de backup\n• 💻 Info: Ver informações do sistema\n\n🗂️ TIPOS DE BACKUP:\n• Core: Essencial (configurações + temas)\n• Full: Completo (tudo)\n• Share: Compartilhável (sem dados pessoais)\n• Minimal: Básico (scripts + pacotes)\n• Custom: Personalizado\n\n📁 LOCALIZAÇÃO:\n• Backups: ~/backups/\n• Scripts: ~/ambiente/\n\n💡 DICAS:\n• Sempre teste restaurações com 'dry-run'\n• Faça backup regularmente\n• Use 'Core' para backup diário\n• 'Share' para enviar para amigos\n• 'Full' antes de mudanças grandes\n\n🔧 REQUISITOS:\n• zenity (interface gráfica)\n• tar, gzip/xz/zstd (compressão)\n• pacman (gerenciador de pacotes)" \
        --width=600 --height=500 2>/dev/null
}

# Menu principal
main_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="🗂️ Sistema de Backup - Menu Principal" \
            --text="Bem-vindo ao Sistema de Backup e Restauração!\nEscolha uma opção:" \
            --width=500 --height=400 \
            --column="Ação" --column="Descrição" --column="Função" \
            "backup" "🚀 Fazer Backup" "Criar cópia do ambiente atual" \
            "restore" "🗃️ Restaurar Backup" "Recuperar ambiente de backup" \
            "info" "💻 Informações" "Ver status do sistema" \
            "help" "ℹ️ Ajuda" "Guia de uso completo" \
            "quit" "❌ Sair" "Fechar aplicação" \
            --hide-column=3 \
            2>/dev/null) || break
        
        case "$choice" in
            "backup")
                log "Iniciando GUI de backup..."
                if [[ -x "$BACKUP_GUI" ]]; then
                    "$BACKUP_GUI" || true
                else
                    zenity --error \
                        --title="❌ Erro" \
                        --text="Script de backup não encontrado ou não executável:\n$BACKUP_GUI" \
                        --width=400 2>/dev/null
                fi
                ;;
            "restore")
                log "Iniciando GUI de restauração..."
                if [[ -x "$RESTORE_GUI" ]]; then
                    "$RESTORE_GUI" || true
                else
                    zenity --error \
                        --title="❌ Erro" \
                        --text="Script de restauração não encontrado ou não executável:\n$RESTORE_GUI" \
                        --width=400 2>/dev/null
                fi
                ;;
            "info")
                show_system_info
                ;;
            "help")
                show_help
                ;;
            "quit"|"")
                break
                ;;
        esac
    done
}

# Função de boas-vindas (opcional)
show_welcome() {
    if zenity --question \
        --title="🎉 Bem-vindo!" \
        --text="🗂️ Sistema de Backup e Restauração\n\n🚀 Este é um sistema completo para:\n• Criar backups do seu ambiente Linux\n• Restaurar configurações e dados\n• Gerenciar múltiplos perfis de backup\n\n💡 Primeira vez usando?\nRecomendamos começar com um backup 'Core' para testar o sistema.\n\nDeseja continuar?" \
        --width=450 --height=250 \
        --ok-label="🚀 Continuar" \
        --cancel-label="❌ Sair" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Verificar se foi chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log "Iniciando Sistema de Backup GUI..."
    
    # Mostrar boas-vindas se for primeira vez
    if [[ ! -f "$HOME/.backup-gui-welcomed" ]]; then
        if show_welcome; then
            touch "$HOME/.backup-gui-welcomed"
        else
            exit 0
        fi
    fi
    
    # Iniciar menu principal
    main_menu
    
    log "Sistema de Backup GUI finalizado."
fi