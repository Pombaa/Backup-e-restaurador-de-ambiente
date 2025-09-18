# 📦 Guia de Instalação - Ambiente Backup

## 🚀 Instalação Rápida

### Para usuários do Arch Linux:

```bash
# 1. Atualizar base de dados (importante para novos pacotes)
yay -Syy

# 2. Instalar o pacote
yay -S ambiente-backup

# 3. Usar o aplicativo
ambiente-backup
```

### Ou em um comando:
```bash
yay -Syy && yay -S ambiente-backup
```

## 🔄 Se o pacote não aparecer

Se você receber "Nenhum pacote AUR localizado", faça:

```bash
# Força sincronização completa
yay -Syy

# Atualiza todos os pacotes AUR
yay -Suu

# Tenta instalar novamente
yay -S ambiente-backup
```

## 📋 Instalação Manual (sempre funciona)

Se ainda não aparecer no yay, instale manualmente:

```bash
git clone https://aur.archlinux.org/ambiente-backup.git
cd ambiente-backup
makepkg -si
```

## ✨ Comandos Disponíveis

Após a instalação:

```bash
ambiente-backup    # Interface principal (GUI)
backup-ambiente    # Alias alternativo
backup-env         # Apenas backup
restore-env        # Apenas restauração
```

## 📱 Encontrar no Menu

O aplicativo também aparece no menu do sistema como:
- **Nome**: Ambiente Backup
- **Categoria**: Sistema > Utilitários

## 🆘 Resolução de Problemas

### Pacote não encontrado:
```bash
# Limpar cache do yay
yay -Sc

# Sincronizar novamente
yay -Syy

# Tentar novamente
yay -S ambiente-backup
```

### Dependências em falta:
```bash
# Instalar dependências manualmente
sudo pacman -S bash zenity tar gzip xz zstd rsync
```

### Erro de permissão:
```bash
# Verificar se o usuário está no grupo wheel
groups $USER

# Se não estiver, adicionar:
sudo usermod -aG wheel $USER
```

## 🔗 Links Úteis

- **AUR**: https://aur.archlinux.org/packages/ambiente-backup
- **GitHub**: https://github.com/Pombaa/Backup-e-restaurador-de-ambiente
- **Documentação**: https://github.com/Pombaa/Backup-e-restaurador-de-ambiente/blob/main/ambiente/README.md

---

💡 **Dica**: Novos pacotes no AUR podem levar alguns minutos para aparecer na busca do yay. Use `yay -Syy` para forçar atualização.