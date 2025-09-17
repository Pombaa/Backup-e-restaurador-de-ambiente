#!/usr/bin/env bash
# ============================================================================
# backup-gui.sh
# ============================================================================
# Interface gráfica com zenity para backup-completo.sh
# Objetivo: Tornar o sistema de backup acessível para usuários não técnicos
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-completo.sh"

log() { echo "[backup-gui] $*" >&2; }
err() { echo "[backup-gui][ERRO] $*" >&2; }
die() { err "$1"; exit 1; }

# Verificar dependências
need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Comando '$1' ausente"; return 1; }; }
need_cmd zenity || die "zenity não instalado. Instale com: sudo pacman -S zenity"
[[ -f "$BACKUP_SCRIPT" ]] || die "Script de backup não encontrado: $BACKUP_SCRIPT"

# Função principal da interface
main_gui() {
    # 1. Seleção do perfil
    local profile=$(zenity --list --radiolist \
        --title="🗂️ Backup do Ambiente - Seleção de Perfil" \
        --text="Escolha o tipo de backup que deseja realizar:" \
        --width=500 --height=300 \
        --column="Selecionar" --column="Perfil" --column="Descrição" --column="Tamanho Aprox." \
        TRUE "core" "Essencial (recomendado)" "~500MB" \
        FALSE "full" "Completo (tudo)" "~5GB" \
        FALSE "share" "Compartilhável (sem dados pessoais)" "~400MB" \
        FALSE "minimal" "Mínimo (só scripts e pacotes)" "~4KB" \
        FALSE "custom" "Personalizado (escolher categorias)" "Variável" \
        2>/dev/null) || return 1
    
    log "Perfil selecionado: $profile"
    
    local categories=""
    local extra_options=()
    
    # 2. Se perfil custom, permitir seleção de categorias
    if [[ "$profile" == "custom" ]]; then
        categories=$(zenity --list --checklist \
            --title="📂 Seleção de Categorias" \
            --text="Escolha as categorias para backup:" \
            --width=600 --height=400 \
            --column="Incluir" --column="Categoria" --column="Descrição" \
            TRUE "user_configs_clean" "Configurações do usuário (limpa)" \
            FALSE "user_configs" "Configurações do usuário (completa)" \
            TRUE "scripts" "Scripts personalizados" \
            TRUE "themes" "Temas e wallpapers" \
            TRUE "system_themes" "Temas do sistema" \
            TRUE "packages_explicit" "Pacotes explicitamente instalados" \
            FALSE "packages" "Todos os pacotes" \
            FALSE "services" "Serviços systemd" \
            FALSE "system_configs" "Configurações do sistema (/etc)" \
            FALSE "php" "Configurações PHP" \
            FALSE "httpd" "Configurações Apache" \
            FALSE "keys" "⚠️ Chaves SSH/GPG (sensível)" \
            FALSE "custom_paths" "Caminhos personalizados" \
            --separator=" " 2>/dev/null) || return 1
        
        [[ -n "$categories" ]] || die "Nenhuma categoria selecionada"
        extra_options+=("--categories" "$categories")
        log "Categorias selecionadas: $categories"
    else
        extra_options+=("--profile" "$profile")
    fi
    
    # 3. Opções avançadas
    local advanced=$(zenity --list --checklist \
        --title="⚙️ Opções Avançadas" \
        --text="Selecione opções adicionais (opcional):" \
        --width=500 --height=350 \
        --column="Ativar" --column="Opção" --column="Descrição" \
        FALSE "sanitize" "Sanitizar (remover dados pessoais)" \
        FALSE "no-sudo" "Não usar sudo (pula configs sistema)" \
        FALSE "zst" "Compressão zstd (mais rápida)" \
        FALSE "xz" "Compressão xz (menor tamanho)" \
        --separator="|" 2>/dev/null) || advanced=""
    
    log "Opções avançadas: $advanced"
    
    # Processar opções avançadas
    if [[ "$advanced" =~ sanitize ]]; then
        extra_options+=("--sanitize")
    fi
    if [[ "$advanced" =~ no-sudo ]]; then
        extra_options+=("--no-sudo")
    fi
    if [[ "$advanced" =~ zst ]]; then
        extra_options+=("--compression" "zst")
    elif [[ "$advanced" =~ xz ]]; then
        extra_options+=("--compression" "xz")
    fi
    
    # 4. Nome personalizado (opcional)
    local custom_name=""
    if zenity --question --title="📝 Nome Personalizado" \
        --text="Deseja definir um nome personalizado para o backup?\n(Padrão: env-backup-DATA)" \
        --width=400 2>/dev/null; then
        
        custom_name=$(zenity --entry \
            --title="📝 Nome do Backup" \
            --text="Digite o prefixo do nome do arquivo:" \
            --entry-text="meu-backup" 2>/dev/null) || custom_name=""
        
        if [[ -n "$custom_name" ]]; then
            extra_options+=("--output-name" "$custom_name")
            log "Nome personalizado: $custom_name"
        fi
    fi
    
    # 5. Confirmação final
    local summary="🗂️ RESUMO DO BACKUP\n\n"
    summary+="📋 Perfil: $profile\n"
    if [[ "$profile" == "custom" ]]; then
        summary+="📂 Categorias: $categories\n"
    fi
    summary+="⚙️ Opções: ${advanced:-"Nenhuma"}\n"
    if [[ -n "$custom_name" ]]; then
        summary+="📝 Nome: $custom_name-DATA.tar.gz\n"
    else
        summary+="📝 Nome: env-backup-DATA.tar.gz\n"
    fi
    summary+="\n💾 Localização: ~/backups/\n"
    summary+="\n⏱️ Tempo estimado: 1-5 minutos"
    
    zenity --question \
        --title="✅ Confirmar Backup" \
        --text="$summary" \
        --width=450 --height=300 \
        --ok-label="🚀 Iniciar Backup" \
        --cancel-label="❌ Cancelar" 2>/dev/null || return 1
    
    # 6. Executar backup com indicador de progresso
    local cmd=("$BACKUP_SCRIPT" "${extra_options[@]}")
    log "Executando: ${cmd[*]}"
    
    # Executar em background e mostrar progresso
    (
        echo "10"; echo "# Preparando backup..."
        sleep 1
        echo "20"; echo "# Coletando arquivos..."
        "${cmd[@]}" >/tmp/backup-output.log 2>&1 &
        local backup_pid=$!
        
        # Monitorar progresso
        local progress=20
        while kill -0 $backup_pid 2>/dev/null; do
            progress=$((progress + 5))
            if [[ $progress -gt 90 ]]; then progress=90; fi
            echo "$progress"
            echo "# Backup em andamento... ($progress%)"
            sleep 2
        done
        
        wait $backup_pid
        local exit_code=$?
        
        echo "100"
        echo "# Backup concluído!"
        sleep 1
        
        exit $exit_code
    ) | zenity --progress \
        --title="⏳ Realizando Backup" \
        --text="Iniciando backup..." \
        --width=400 --height=150 \
        --auto-close \
        --no-cancel 2>/dev/null
    
    local result=$?
    
    # 7. Resultado final
    if [[ $result -eq 0 ]]; then
        local output=""
        if [[ -f /tmp/backup-output.log ]]; then
            output=$(tail -5 /tmp/backup-output.log)
        fi
        
        zenity --info \
            --title="✅ Backup Concluído com Sucesso!" \
            --text="🎉 Backup realizado com sucesso!\n\n📁 Verifique o arquivo em: ~/backups/\n\n📝 Detalhes:\n$output" \
            --width=500 --height=200 2>/dev/null
    else
        local error_msg="Erro desconhecido"
        if [[ -f /tmp/backup-output.log ]]; then
            error_msg=$(tail -10 /tmp/backup-output.log)
        fi
        
        zenity --error \
            --title="❌ Erro no Backup" \
            --text="😞 Falha ao realizar backup.\n\n🔍 Detalhes do erro:\n$error_msg\n\nConsulte o terminal para mais informações." \
            --width=500 --height=200 2>/dev/null
    fi
    
    # Limpeza
    rm -f /tmp/backup-output.log
    
    return $result
}

# Menu principal
show_help() {
    zenity --info \
        --title="ℹ️ Ajuda - Backup GUI" \
        --text="🗂️ BACKUP GUI - Interface Gráfica\n\n📋 PERFIS DISPONÍVEIS:\n• Core: Backup essencial (recomendado)\n• Full: Backup completo de tudo\n• Share: Para compartilhar (sem dados pessoais)\n• Minimal: Apenas scripts e lista de pacotes\n• Custom: Escolha suas próprias categorias\n\n⚙️ OPÇÕES:\n• Sanitizar: Remove dados pessoais do VS Code\n• No-sudo: Não solicita senha de administrador\n• Compressão: zstd (rápido) ou xz (menor)\n\n📁 Local: ~/backups/\n💡 Dica: Use 'Core' para backup diário!" \
        --width=500 --height=400 2>/dev/null
}

# Interface principal
main_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="🗂️ Backup do Ambiente - Menu Principal" \
            --text="Escolha uma opção:" \
            --width=400 --height=300 \
            --column="Ação" --column="Descrição" \
            "backup" "🚀 Realizar Backup" \
            "help" "ℹ️ Ajuda e Informações" \
            "quit" "❌ Sair" \
            2>/dev/null) || break
        
        case "$choice" in
            "backup")
                main_gui || true
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

# Verificar se foi chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Modo standalone
    main_menu
else
    # Modo sourced - exportar funções
    export -f main_gui show_help main_menu
fi