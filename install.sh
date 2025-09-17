#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="${HOME}/.local/bin"
mkdir -p "$TARGET_BIN"
chmod +x "$BASE_DIR"/*.sh 2>/dev/null || true

link() {
  local src="$1" name="$2"; local dest="$TARGET_BIN/$2"
  if [[ -L $dest || -f $dest ]]; then
    echo "Atualizando link: $dest"
    rm -f "$dest"
  fi
  ln -s "$src" "$dest"
  echo "-> $dest -> $src"
}

link "$BASE_DIR/backup-completo.sh" backup-env
link "$BASE_DIR/restaurar-ambiente.sh" restore-env
link "$BASE_DIR/relatorio-pacotes.sh" pkg-report

echo "Instalação concluída. Certifique-se de que ~/.local/bin está no PATH."
echo "Exemplos:"
echo "  backup-env --profile share --sanitize"
echo "  restore-env --dry-run --categories 'user_configs_clean scripts'"
echo "  pkg-report --diff --orphans"