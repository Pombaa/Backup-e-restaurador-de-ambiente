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

💡 **Dica**: Novos pacotes no AUR podem levar alguns minutos para aparecer na busca do yay. Use `yay -Syy` para forçar atualização.# 🎉 Ambiente Backup - Guia Completo de Distribuição

## ✅ **PROBLEMA RESOLVIDO!**

O erro que você teve era porque:
1. Não havia chave SSH configurada para o AUR
2. O pacote ainda não existia no AUR
3. Não havia tags no repositório

## 📦 **Soluções Implementadas**

### **1. Instalação Imediata (Funciona AGORA)**

```bash
# Opção 1: Instalação local do usuário
./install-universal.sh --user

# Opção 2: Instalação sistema (com sudo)
sudo ./install-universal.sh --system

# Usar o aplicativo
ambiente-backup
```

### **2. Pacote AUR (Para distribuição futura)**

```bash
# Construir pacote localmente
./build-package.sh --build

# Instalar pacote local
./build-package.sh --install

# Testar instalação
./test-installation.sh
```

## 🚀 **Para Usuários Finais**

### **Instalação Rápida**
```bash
# Download e instalação em um comando
curl -fsSL https://raw.githubusercontent.com/Pombaa/Backup-e-restaurador-de-ambiente/main/ambiente/install-universal.sh | bash
```

### **Comandos Disponíveis**
```bash
ambiente-backup    # Interface principal (GUI)
backup-ambiente    # Alias alternativo  
backup-env         # Só backup
restore-env        # Só restauração
```

## 🛠️ **Para Publicar no AUR (Quando Quiser)**

### **1. Configurar AUR**
```bash
# Mostrar sua chave SSH
./setup-aur.sh --show-key

# Adicionar em: https://aur.archlinux.org/account/
# Seção: "SSH Public Keys"
```

### **2. Publicar**
```bash
# Configurar repositório AUR
./setup-aur.sh --create-package

# Ou usar o script de publicação
./publish-aur.sh --setup
./publish-aur.sh --publish
```

## 📋 **Status Atual**

✅ **Funcionando AGORA:**
- ✅ Instalação universal (`./install-universal.sh`)
- ✅ Comandos intuitivos (`ambiente-backup`)
- ✅ Integração com menu do sistema
- ✅ Pacote .pkg.tar.zst gerado
- ✅ Scripts de build e teste
- ✅ GitHub Actions configurado

🔄 **Para fazer depois:**
- 🔄 Configurar chave SSH no AUR
- 🔄 Publicar no AUR pela primeira vez
- 🔄 Configurar releases automáticos

## 🎯 **Demonstração**

```bash
# 1. Instalar
./install-universal.sh --user

# 2. Usar
ambiente-backup

# 3. Compartilhar
echo "Instale com: curl -fsSL https://raw.githubusercontent.com/Pombaa/Backup-e-restaurador-de-ambiente/main/ambiente/install-universal.sh | bash"
```

## 📊 **Arquivos Criados**

- `PKGBUILD` - Especificação do pacote AUR
- `build-package.sh` - Construir pacotes localmente  
- `install-universal.sh` - Instalador universal
- `setup-aur.sh` - Configuração inicial do AUR
- `publish-aur.sh` - Publicação no AUR
- `test-installation.sh` - Testes de instalação
- `.github/workflows/release.yml` - CI/CD automático

**Seu aplicativo está pronto para distribuição! 🎉**