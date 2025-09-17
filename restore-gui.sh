#!/usr/bin/env bash
# ============================================================================
# restore-gui.sh
# ============================================================================
# Interface gráfica com zenity para restaurar-ambiente.sh
# Objetivo: Tornar a restauração de backup acessível para usuários não técnicos
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESTORE_SCRIPT="$SCRIPT_DIR/restaurar-ambiente.sh"

log() { echo "[restore-gui] $*" >&2; }
err() { echo "[restore-gui][ERRO] $*" >&2; }
die() { err "$1"; exit 1; }

# Verificar dependências
need_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Comando '$1' ausente"; return 1; }; }
need_cmd zenity || die "zenity não instalado. Instale com: sudo pacman -S zenity"
[[ -f "$RESTORE_SCRIPT" ]] || die "Script de restauração não encontrado: $RESTORE_SCRIPT"

# Função para listar backups disponíveis
list_backups() {
    local backup_dir="$HOME/backups"
    local backups=()
    
    if [[ -d "$backup_dir" ]]; then
        while IFS= read -r -d '' file; do
            local basename_file=$(basename "$file")
            local size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "?")
            local date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || echo "?")
            backups+=("$file" "$basename_file ($size - $date)")
        done < <(find "$backup_dir" -name "env-backup-*.tar.*" -type f -print0 2>/dev/null | sort -rz)
    fi
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        backups+=("/caminho/para/arquivo" "Nenhum backup encontrado - Selecionar arquivo...")
    fi
    
    printf '%s\n' "${backups[@]}"
}

# Função para obter categorias de um arquivo
get_categories() {
    local archive="$1"
    [[ -f "$archive" ]] || return 1
    
    local categories=$("$RESTORE_SCRIPT" --list-categories --archive "$archive" 2>/dev/null | sed 's/Categorias no arquivo: //' || echo "")
    echo "$categories"
}

# Função principal da interface de restauração
main_gui() {
    # 1. Seleção do arquivo de backup
    local archive=""
    local backups=($(list_backups))
    
    if [[ ${#backups[@]} -gt 2 ]]; then
        # Há backups disponíveis
        local selected=$(zenity --list \
            --title="🗃️ Restaurar Ambiente - Seleção de Backup" \
            --text="Escolha o arquivo de backup para restaurar:" \
            --width=700 --height=400 \
            --column="Caminho" --column="Arquivo" \
            "${backups[@]}" \
            --hide-column=1 \
            2>/dev/null) || return 1
        
        if [[ "$selected" == "Nenhum backup encontrado - Selecionar arquivo..." ]]; then
            archive=$(zenity --file-selection \
                --title="📁 Selecionar Arquivo de Backup" \
                --file-filter="Backups | *.tar.gz *.tar.xz *.tar.zst *.tar" \
                --filename="$HOME/backups/" \
                2>/dev/null) || return 1
        else
            archive="$selected"
        fi
    else
        # Nenhum backup encontrado, seleção manual
        archive=$(zenity --file-selection \
            --title="📁 Selecionar Arquivo de Backup" \
            --file-filter="Backups | *.tar.gz *.tar.xz *.tar.zst *.tar" \
            --filename="$HOME/" \
            2>/dev/null) || return 1
    fi
    
    [[ -f "$archive" ]] || die "Arquivo selecionado não existe: $archive"
    log "Arquivo selecionado: $archive"
    
    # 2. Listar categorias disponíveis
    local available_categories=$(get_categories "$archive")
    if [[ -z "$available_categories" ]]; then
        zenity --error \
            --title="❌ Erro" \
            --text="Não foi possível ler as categorias do arquivo de backup.\nVerifique se o arquivo não está corrompido." \
            --width=400 2>/dev/null
        return 1
    fi
    
    log "Categorias disponíveis: $available_categories"
    
    # 3. Seleção de categorias para restaurar
    local restore_all="yes"
    if zenity --question \
        --title="📂 Seleção de Categorias" \
        --text="Categorias disponíveis no backup:\n$available_categories\n\nDeseja restaurar TODAS as categorias?" \
        --width=500 --height=200 \
        --ok-label="✅ Todas" \
        --cancel-label="🎯 Escolher" 2>/dev/null; then
        restore_all="yes"
    else
        restore_all="no"
    fi
    
    local selected_categories=""
    local extra_options=()
    
    if [[ "$restore_all" == "no" ]]; then
        # Montar lista de categorias dinamicamente
        local category_list=()
        for cat in $available_categories; do
            case "$cat" in
                "user_configs") category_list+=(TRUE "$cat" "Configurações do usuário (completa)") ;;
                "user_configs_clean") category_list+=(TRUE "$cat" "Configurações do usuário (limpa)") ;;
                "scripts") category_list+=(TRUE "$cat" "Scripts personalizados") ;;
                "themes") category_list+=(TRUE "$cat" "Temas e wallpapers") ;;
                "system_themes") category_list+=(FALSE "$cat" "Temas do sistema") ;;
                "packages"|"packages_explicit") category_list+=(TRUE "$cat" "Pacotes") ;;
                "services") category_list+=(FALSE "$cat" "Serviços systemd") ;;
                "system_configs") category_list+=(FALSE "$cat" "Configurações do sistema") ;;
                "php") category_list+=(FALSE "$cat" "Configurações PHP") ;;
                "httpd") category_list+=(FALSE "$cat" "Configurações Apache") ;;
                "keys") category_list+=(FALSE "$cat" "⚠️ Chaves SSH/GPG (sensível)") ;;
                *) category_list+=(FALSE "$cat" "Categoria: $cat") ;;
            esac
        done
        
        selected_categories=$(zenity --list --checklist \
            --title="📂 Seleção Específica de Categorias" \
            --text="Escolha as categorias que deseja restaurar:" \
            --width=600 --height=400 \
            --column="Restaurar" --column="Categoria" --column="Descrição" \
            "${category_list[@]}" \
            --separator=" " 2>/dev/null) || return 1
        
        [[ -n "$selected_categories" ]] || die "Nenhuma categoria selecionada"
        extra_options+=("--categories" "$selected_categories")
        log "Categorias selecionadas: $selected_categories"
    fi
    
    # 4. Opções de restauração
    local restore_options=$(zenity --list --checklist \
        --title="⚙️ Opções de Restauração" \
        --text="Selecione as opções desejadas:" \
        --width=500 --height=400 \
        --column="Ativar" --column="Opção" --column="Descrição" \
        TRUE "dry-run" "🧪 Teste (mostrar o que seria feito)" \
        FALSE "verify" "🔍 Verificar integridade do arquivo" \
        FALSE "no-packages" "📦 Não instalar pacotes" \
        FALSE "no-services" "🔧 Não habilitar serviços" \
        FALSE "no-system" "🔒 Não aplicar configurações do sistema" \
        FALSE "themes-user" "🎨 Instalar temas no HOME (não /usr/share)" \
        FALSE "with-keys" "🔑 Restaurar chaves SSH/GPG" \
        FALSE "keep-tmp" "📁 Manter arquivos temporários" \
        --separator="|" 2>/dev/null) || restore_options=""
    
    log "Opções de restauração: $restore_options"
    
    # Processar opções
    local is_dry_run=false
    if [[ "$restore_options" =~ dry-run ]]; then
        extra_options+=("--dry-run")
        is_dry_run=true
    fi
    if [[ "$restore_options" =~ verify ]]; then
        extra_options+=("--verify")
    fi
    if [[ "$restore_options" =~ no-packages ]]; then
        extra_options+=("--no-packages")
    fi
    if [[ "$restore_options" =~ no-services ]]; then
        extra_options+=("--no-services")
    fi
    if [[ "$restore_options" =~ no-system ]]; then
        extra_options+=("--no-system")
    fi
    if [[ "$restore_options" =~ themes-user ]]; then
        extra_options+=("--themes-user")
    fi
    if [[ "$restore_options" =~ with-keys ]]; then
        extra_options+=("--with-keys")
    fi
    if [[ "$restore_options" =~ keep-tmp ]]; then
        extra_options+=("--keep-tmp")
    fi
    
    # 5. Confirmação final
    local summary="🗃️ RESUMO DA RESTAURAÇÃO\n\n"
    summary+="📁 Arquivo: $(basename "$archive")\n"
    summary+="📂 Categorias: "
    if [[ "$restore_all" == "yes" ]]; then
        summary+="Todas ($available_categories)\n"
    else
        summary+="$selected_categories\n"
    fi
    summary+="⚙️ Opções: ${restore_options:-"Nenhuma"}\n"
    
    if [[ "$is_dry_run" == "true" ]]; then
        summary+="\n🧪 MODO TESTE: Nenhuma alteração será feita no sistema!"
    else
        summary+="\n⚠️ ATENÇÃO: Esta operação pode sobrescrever arquivos existentes!"
    fi
    
    local action_label="🚀 Restaurar"
    if [[ "$is_dry_run" == "true" ]]; then
        action_label="🧪 Testar"
    fi
    
    zenity --question \
        --title="✅ Confirmar Restauração" \
        --text="$summary" \
        --width=500 --height=300 \
        --ok-label="$action_label" \
        --cancel-label="❌ Cancelar" 2>/dev/null || return 1
    
    # 6. Executar restauração
    local cmd=("$RESTORE_SCRIPT" "--archive" "$archive" "${extra_options[@]}")
    log "Executando: ${cmd[*]}"
    
    # Executar com indicador de progresso
    (
        echo "10"; echo "# Extraindo arquivo de backup..."
        sleep 1
        echo "30"; echo "# Verificando categorias..."
        "${cmd[@]}" >/tmp/restore-output.log 2>&1 &
        local restore_pid=$!
        
        # Monitorar progresso
        local progress=30
        while kill -0 $restore_pid 2>/dev/null; do
            progress=$((progress + 10))
            if [[ $progress -gt 90 ]]; then progress=90; fi
            echo "$progress"
            if [[ "$is_dry_run" == "true" ]]; then
                echo "# Simulando restauração... ($progress%)"
            else
                echo "# Restaurando arquivos... ($progress%)"
            fi
            sleep 1
        done
        
        wait $restore_pid
        local exit_code=$?
        
        echo "100"
        if [[ "$is_dry_run" == "true" ]]; then
            echo "# Teste concluído!"
        else
            echo "# Restauração concluída!"
        fi
        sleep 1
        
        exit $exit_code
    ) | zenity --progress \
        --title="⏳ Restaurando Backup" \
        --text="Iniciando restauração..." \
        --width=400 --height=150 \
        --auto-close \
        --no-cancel 2>/dev/null
    
    local result=$?
    
    # 7. Resultado final
    if [[ $result -eq 0 ]]; then
        local output=""
        if [[ -f /tmp/restore-output.log ]]; then
            output=$(tail -10 /tmp/restore-output.log)
        fi
        
        local title="✅ Restauração Concluída!"
        local message="🎉 Operação realizada com sucesso!"
        
        if [[ "$is_dry_run" == "true" ]]; then
            title="🧪 Teste Concluído!"
            message="📋 Teste realizado com sucesso! Nenhuma alteração foi feita no sistema."
        fi
        
        zenity --info \
            --title="$title" \
            --text="$message\n\n📝 Detalhes:\n$output\n\n💡 Dica: Considere reiniciar a sessão se necessário." \
            --width=500 --height=300 2>/dev/null
    else
        local error_msg="Erro desconhecido"
        if [[ -f /tmp/restore-output.log ]]; then
            error_msg=$(tail -10 /tmp/restore-output.log)
        fi
        
        zenity --error \
            --title="❌ Erro na Restauração" \
            --text="😞 Falha ao restaurar backup.\n\n🔍 Detalhes do erro:\n$error_msg\n\nConsulte o terminal para mais informações." \
            --width=500 --height=300 2>/dev/null
    fi
    
    # Limpeza
    rm -f /tmp/restore-output.log
    
    return $result
}

# Menu de ajuda
show_help() {
    zenity --info \
        --title="ℹ️ Ajuda - Restore GUI" \
        --text="🗃️ RESTORE GUI - Interface de Restauração\n\n📋 COMO USAR:\n1. Selecione um arquivo de backup\n2. Escolha categorias (ou todas)\n3. Configure opções de restauração\n4. Execute (teste ou real)\n\n⚙️ OPÇÕES PRINCIPAIS:\n• 🧪 Dry-run: Apenas mostra o que seria feito\n• 🔍 Verify: Verifica integridade do arquivo\n• 📦 No-packages: Não instala pacotes\n• 🔒 No-system: Não altera configurações sistema\n• 🎨 Themes-user: Instala temas só no usuário\n• 🔑 With-keys: Restaura chaves SSH/GPG\n\n⚠️ IMPORTANTE:\n• Sempre teste primeiro com 'Dry-run'\n• Backup seus dados antes de restaurar\n• Reinicie a sessão após restaurar" \
        --width=500 --height=450 2>/dev/null
}

# Interface principal
main_menu() {
    while true; do
        local choice=$(zenity --list \
            --title="🗃️ Restaurar Ambiente - Menu Principal" \
            --text="Escolha uma opção:" \
            --width=400 --height=300 \
            --column="Ação" --column="Descrição" \
            "restore" "🚀 Restaurar Backup" \
            "help" "ℹ️ Ajuda e Informações" \
            "quit" "❌ Sair" \
            2>/dev/null) || break
        
        case "$choice" in
            "restore")
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
    export -f main_gui show_help main_menu get_categories list_backups
fi