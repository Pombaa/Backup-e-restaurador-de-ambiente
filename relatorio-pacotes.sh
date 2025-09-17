#!/usr/bin/env bash
# ============================================================================
# relatorio-pacotes.sh
# Gera relatórios e diffs históricos dos pacotes (pacman / AUR) a partir dos
# arquivos de backup gerados por backup-completo.sh (categories/packages/*).
# Objetivo: ajudar a identificar "lixo" acumulado, orfãos e mudanças entre
# snapshots para manter o sistema enxuto.
# ============================================================================
# Requerimentos: bash, tar, sort, pacman. Opcional: expac (para tamanhos), yay/paru (para AUR install date se precisar)
# ============================================================================
# Saída padrão: texto. Pode gerar modo markdown ou json simples.
#
# Flags:
#   --last N            Considera os N últimos backups (default 2)
#   --diff              Mostra diff entre os dois últimos backups (novo/removido)
#   --orphans           Lista pacotes orfãos atuais (pacman -Qdt)
#   --baseline FILE     Compara pacotes explícitos atuais com lista base
#   --output (text|md|json)  Formato (default text)
#   --sizes             Inclui tamanhos (expac) dos pacotes explícitos atuais
#   --installed-since DAYS   Mostra pacotes instalados nos últimos X dias (usa /var/lib/pacman/local)
#   --help              Ajuda
# ============================================================================
set -euo pipefail

LAST=2
DO_DIFF=0
DO_ORPHANS=0
OUTPUT=text
DO_SIZES=0
BASELINE=""
INST_SINCE=0

usage(){ grep '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --last) shift; LAST=${1:-2} ;;
    --diff) DO_DIFF=1 ;;
    --orphans) DO_ORPHANS=1 ;;
    --baseline) shift; BASELINE=${1:-} ;;
    --output) shift; OUTPUT=${1:-text} ;;
    --sizes) DO_SIZES=1 ;;
    --installed-since) shift; INST_SINCE=${1:-0} ;;
    --help|-h) usage ;;
    *) echo "[ERRO] Flag desconhecida: $1" >&2; usage ;;
  esac; shift || true
done

BACKUP_DIR=${BACKUP_ROOT_DIR:-"$HOME/backups"}
[[ -d "$BACKUP_DIR" ]] || { echo "[ERRO] Diretório de backups não existe: $BACKUP_DIR" >&2; exit 1; }

# Lista arquivos env-backup ordenados por data de modificação (mais recente primeiro)
mapfile -t ARCHIVES < <(ls -1t "$BACKUP_DIR"/env-backup-*.tar.* 2>/dev/null || true)
[[ ${#ARCHIVES[@]} -gt 0 ]] || { echo "[ERRO] Nenhum env-backup encontrado em $BACKUP_DIR" >&2; exit 1; }

# Limita ao N solicitado
if (( LAST < ${#ARCHIVES[@]} )); then
  ARCHIVES=("${ARCHIVES[@]:0:$LAST}")
fi

extract_pkg_file(){
  local archive="$1" file="$2"; # caminho relativo dentro do tar
  # Usa tar para extrair para stdout; compatível com gz/xz/zst
  if [[ ! -f "$archive" ]]; then return 1; fi
  case "$archive" in
    *.tar.gz|*.tgz) tar -xzf "$archive" -O "$file" 2>/dev/null || true ;;
    *.tar.xz) tar -xJf "$archive" -O "$file" 2>/dev/null || true ;;
    *.tar.zst|*.tar.zstd) \
      if tar --help 2>&1 | grep -qi -- '--zstd'; then tar --zstd -xf "$archive" -O "$file" 2>/dev/null || true; \
      else zstd -dc "$archive" | tar -x -O "$file" 2>/dev/null || true; fi ;;
    *.tar) tar -xf "$archive" -O "$file" 2>/dev/null || true ;;
    *) return 1 ;;
  esac
}

get_lists_from_archive(){
  local archive="$1"
  local pac_exp aur_exp all
  pac_exp=$(extract_pkg_file "$archive" categories/packages/pacman-explicit.txt || true)
  aur_exp=$(extract_pkg_file "$archive" categories/packages/aur-explicit.txt || true)
  all=$(extract_pkg_file "$archive" categories/packages/all.txt || true)
  echo "PACMAN_EXPLICIT>>>"; echo "$pac_exp"
  echo "AUR_EXPLICIT>>>"; echo "$aur_exp"
  echo "ALL_PACKAGES>>>"; echo "$all"
}

# Carrega dados dos arquivos selecionados
declare -A PACMAN_EXPLICIT_MAP AUR_EXPLICIT_MAP ALL_MAP
ORDERED_KEYS=()

idx=0
for a in "${ARCHIVES[@]}"; do
  data=$(get_lists_from_archive "$a") || true
  pac=$(echo "$data" | awk '/^PACMAN_EXPLICIT>>>/{flag=1;next}/^AUR_EXPLICIT>>>/{flag=0}flag')
  aur=$(echo "$data" | awk '/^AUR_EXPLICIT>>>/{flag=1;next}/^ALL_PACKAGES>>>/{flag=0}flag')
  all=$(echo "$data" | awk '/^ALL_PACKAGES>>>/{flag=1;next}END{flag=0}flag')
  PACMAN_EXPLICIT_MAP[$idx]="$(echo "$pac" | sed '/^$/d' | sort)"
  AUR_EXPLICIT_MAP[$idx]="$(echo "$aur" | sed '/^$/d' | sort)"
  ALL_MAP[$idx]="$(echo "$all" | sed '/^$/d' | sort)"
  ORDERED_KEYS+=($idx)
  ((idx++))
  [[ $idx -ge $LAST ]] && break
done

latest=$(( ${#ORDERED_KEYS[@]} - 1 ))
# Em ORDERED_KEYS 0 é o mais recente (pois ls -t). Vamos manter coerência:
# chave 0 => mais recente, chave 1 => anterior.

# Diff entre dois últimos
compute_diff(){
  local newer older; newer="$1"; older="$2"
  comm -23 <(echo "${PACMAN_EXPLICIT_MAP[$newer]}" | sort -u) <(echo "${PACMAN_EXPLICIT_MAP[$older]}" | sort -u)
}
compute_removed(){
  local newer older; newer="$1"; older="$2"
  comm -13 <(echo "${PACMAN_EXPLICIT_MAP[$newer]}" | sort -u) <(echo "${PACMAN_EXPLICIT_MAP[$older]}" | sort -u)
}

# Pacotes orfãos atuais
orphans_list(){ pacman -Qdtq 2>/dev/null || true; }

# Top-level explícitos atuais (ignorando dependências) pacman -Qet
explicit_top(){ pacman -Qetq 2>/dev/null || true; }

# Tamanhos (expac) - se disponível
sizes_for(){
  command -v expac >/dev/null 2>&1 || return 0
  expac -H M '%n %m' "$@" 2>/dev/null | sort -k2 -nr
}

# Instalados nos últimos X dias
installed_since(){
  local days=$1 now epoch limit pkgdir
  (( days > 0 )) || return 0
  now=$(date +%s); limit=$(( now - days*86400 ))
  for p in /var/lib/pacman/local/*; do
    [[ -d $p ]] || continue
    pkg=$(basename "$p")
    mtime=$(stat -c %Y "$p" 2>/dev/null || echo 0)
    if (( mtime >= limit )); then
      echo "$pkg"
    fi
  done | sort
}

# Baseline diff
baseline_diff(){
  [[ -f $BASELINE ]] || return 0
  comm -23 <(explicit_top | sort -u) <(sort -u "$BASELINE")
}

# ---------- OUTPUT ---------------------------------------------------------
print_text(){
  echo "Arquivos considerados (mais recente primeiro):"; printf '  %s\n' "${ARCHIVES[@]}"; echo
  echo "[Pacotes explícitos últimos snapshots]"; for k in "${!PACMAN_EXPLICIT_MAP[@]}"; do echo "--- Snapshot $k ---"; echo "${PACMAN_EXPLICIT_MAP[$k]}"; done; echo
  if (( DO_DIFF==1 )) && (( ${#PACMAN_EXPLICIT_MAP[@]} > 1 )); then
    echo "[Novos desde penúltimo]"; compute_diff 0 1; echo
    echo "[Removidos desde penúltimo]"; compute_removed 0 1; echo
  fi
  echo "[AUR explícitos mais recente]"; echo "${AUR_EXPLICIT_MAP[0]:-}"; echo
  if (( DO_ORPHANS==1 )); then
    echo "[Orfãos atuais pacman -Qdt]"; orphans_list; echo
  fi
  if [[ -n $BASELINE ]]; then
    echo "[Novos vs baseline]"; baseline_diff; echo
  fi
  if (( DO_SIZES==1 )); then
    echo "[Tamanhos (MiB) pacotes top-level atuais]"; sizes_for $(explicit_top); echo
  fi
  if (( INST_SINCE>0 )); then
    echo "[Instalados nos últimos $INST_SINCE dias]"; installed_since "$INST_SINCE"; echo
  fi
  echo "Sugestão limpeza orfãos: sudo pacman -Rns $(pacman -Qdtq 2>/dev/null | tr '\n' ' ' 2>/dev/null || true)"
}

print_md(){
  echo "# Relatório de Pacotes"
  echo "Arquivos analisados:"; for a in "${ARCHIVES[@]}"; do echo "- $a"; done; echo
  echo "## Explícitos (snapshot mais recente)"; echo '```'; echo "${PACMAN_EXPLICIT_MAP[0]}"; echo '```'
  if (( DO_DIFF==1 )) && (( ${#PACMAN_EXPLICIT_MAP[@]} > 1 )); then
    echo "## Novos vs penúltimo"; echo '```'; compute_diff 0 1; echo '```'
    echo "## Removidos vs penúltimo"; echo '```'; compute_removed 0 1; echo '```'
  fi
  echo "## AUR explícitos"; echo '```'; echo "${AUR_EXPLICIT_MAP[0]:-}"; echo '```'
  if (( DO_ORPHANS==1 )); then echo "## Orfãos"; echo '```'; orphans_list; echo '```'; fi
  if [[ -n $BASELINE ]]; then echo "## Novos vs baseline"; echo '```'; baseline_diff; echo '```'; fi
  if (( DO_SIZES==1 )); then echo "## Tamanhos (MiB)"; echo '```'; sizes_for $(explicit_top); echo '```'; fi
  if (( INST_SINCE>0 )); then echo "## Instalados últimos $INST_SINCE dias"; echo '```'; installed_since "$INST_SINCE"; echo '```'; fi
  echo "## Limpeza Orfãos"; echo '```'; echo "sudo pacman -Rns $(pacman -Qdtq 2>/dev/null | tr '\n' ' ' 2>/dev/null || true)"; echo '```'
}

print_json(){
  # Json simplificado
  printf '{"archives":["%s"],' "${ARCHIVES[*]}" | sed 's/ /","/g'
  printf '"pacman_explicit_latest":["%s"],' $(echo "${PACMAN_EXPLICIT_MAP[0]}" | tr '\n' ' ' ) | sed 's/ /","/g'
  printf '"aur_explicit_latest":["%s"],' $(echo "${AUR_EXPLICIT_MAP[0]:-}" | tr '\n' ' ' ) | sed 's/ /","/g'
  if (( DO_DIFF==1 )) && (( ${#PACMAN_EXPLICIT_MAP[@]} > 1 )); then
    printf '"added":["%s"],' $(compute_diff 0 1 | tr '\n' ' ' ) | sed 's/ /","/g'
    printf '"removed":["%s"],' $(compute_removed 0 1 | tr '\n' ' ' ) | sed 's/ /","/g'
  fi
  if (( DO_ORPHANS==1 )); then printf '"orphans":["%s"],' $(orphans_list | tr '\n' ' ' ) | sed 's/ /","/g'; fi
  if [[ -n $BASELINE ]]; then printf '"new_vs_baseline":["%s"],' $(baseline_diff | tr '\n' ' ' ) | sed 's/ /","/g'; fi
  if (( INST_SINCE>0 )); then printf '"installed_since":["%s"],' $(installed_since "$INST_SINCE" | tr '\n' ' ' ) | sed 's/ /","/g'; fi
  echo '"ok":true}'
}

case "$OUTPUT" in
  text) print_text ;;
  md) print_md ;;
  json) print_json ;;
  *) echo "Formato inválido: $OUTPUT" >&2; exit 1 ;;
cesac
