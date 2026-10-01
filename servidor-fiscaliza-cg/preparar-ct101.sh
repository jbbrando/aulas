#!/usr/bin/env bash
# =============================================================================
#  preparar-ct101.sh
#  Prepara o CT 101 (LXC no Proxmox, 192.168.100.111) para rodar o Claude Code
#  com Remote Control, na pasta ~/fiscaliza-cg do usuario comum.
#
#  COMO USAR (no servidor, como root):
#      bash preparar-ct101.sh
#
#  O QUE ELE FAZ:
#    1. Diagnostico somente leitura (nada e alterado).
#    2. Para cada mudanca no sistema, explica o que vai fazer e pede o seu OK.
#       Se voce responder N, pula aquela etapa.
#    3. Nunca grava senha em arquivo. A senha do usuario e digitada por voce
#       no terminal, na hora.
#    4. NAO mexe em containers, volumes nem no docker-compose.yml.
#    5. NAO reinicia o CT nem o Docker.
#
#  Variaveis que voce pode mudar antes de rodar (opcional):
#      USUARIO=joao  bash preparar-ct101.sh      (nome do usuario comum)
# =============================================================================
set -u

USUARIO="${USUARIO:-joao}"
PROJETO="fiscaliza-cg"
SESSAO_TMUX="fiscaliza"
ARQUIVO_PROMPT="prompt_claude_code_fiscaliza_cg.md"
VERSAO_MINIMA="2.1.51"
PACOTES_NECESSARIOS=(curl git tmux)

# ---------- utilitarios -------------------------------------------------------
titulo()   { printf '\n\033[1;34m== %s ==\033[0m\n' "$*"; }
ok()       { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
aviso()    { printf '\033[1;33m[AVISO]\033[0m %s\n' "$*"; }
erro()     { printf '\033[1;31m[ERRO]\033[0m %s\n' "$*"; }
confirmar() {
  # Pergunta e so retorna 0 se a resposta comecar com s/S/y/Y.
  local resposta
  read -r -p "$1 [s/N] " resposta
  [[ "$resposta" =~ ^[sSyY] ]]
}
como_usuario() {
  # Roda um comando como o usuario comum, com o ambiente de login dele.
  su - "$USUARIO" -c "$*"
}
versao_maior_ou_igual() {
  # versao_maior_ou_igual 2.1.60 2.1.51  -> verdadeiro
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# ---------- checagens iniciais ------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  erro "Rode este script como root:  sudo bash $0"
  exit 1
fi
if [ ! -f /etc/debian_version ]; then
  aviso "Este script usa 'apt'. O sistema nao parece ser Debian/Ubuntu."
  confirmar "Continuar mesmo assim?" || exit 1
fi
if [ "$(hostname -I 2>/dev/null | tr -d ' ')" = "192.168.100.113" ]; then
  erro "Este e o HOST do Proxmox (192.168.100.113). Rode no CT 101, nao aqui."
  exit 1
fi

# =============================================================================
#  ETAPA 2 - DIAGNOSTICO (somente leitura)
# =============================================================================
titulo "DIAGNOSTICO (somente leitura)"

echo "--- Sistema operacional"
grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release
echo "Hostname: $(hostname)   IPs: $(hostname -I 2>/dev/null)"

echo; echo "--- Arquitetura e memoria"
echo "Arquitetura: $(uname -m)   Kernel: $(uname -r)"
free -h | sed -n '1,2p'

echo; echo "--- Espaco em disco (raiz)"
df -h / | sed -n '1,2p'

echo; echo "--- Usuarios comuns (nao root, UID >= 1000)"
USUARIOS_COMUNS=$(awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd)
if [ -n "$USUARIOS_COMUNS" ]; then
  echo "$USUARIOS_COMUNS"
else
  echo "(nenhum - so existe root)"
fi

echo; echo "--- Programas"
for p in curl git tmux docker; do
  if command -v "$p" >/dev/null 2>&1; then
    case "$p" in
      curl)   v=$(curl --version | head -n1 | awk '{print $2}') ;;
      git)    v=$(git --version | awk '{print $3}') ;;
      tmux)   v=$(tmux -V | awk '{print $2}') ;;
      docker) v=$(docker --version | awk '{print $3}' | tr -d ,) ;;
    esac
    ok "$p instalado (versao $v)"
  else
    aviso "$p NAO instalado"
  fi
done
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  ok "docker compose: $(docker compose version --short 2>/dev/null)"
fi

echo; echo "--- Claude Code"
if id "$USUARIO" >/dev/null 2>&1 && como_usuario "command -v claude" >/dev/null 2>&1; then
  ok "claude ja instalado para $USUARIO: $(como_usuario 'claude --version' 2>/dev/null)"
elif command -v claude >/dev/null 2>&1; then
  aviso "claude instalado para root ($(claude --version 2>/dev/null)), mas nao para $USUARIO"
else
  echo "claude nao instalado"
fi

echo; echo "--- Portas em uso (referencia)"
ss -tlnp 2>/dev/null | awk 'NR==1 || /LISTEN/' | cut -c1-120

echo; echo "--- Containers rodando (referencia)"
if command -v docker >/dev/null 2>&1; then
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null | cut -c1-120
fi

echo
confirmar "Diagnostico concluido. Seguir para as etapas que ALTERAM o sistema?" || { echo "Encerrado sem alterar nada."; exit 0; }

# =============================================================================
#  ETAPA 3 - USUARIO DEDICADO
# =============================================================================
titulo "ETAPA 3 - Usuario dedicado '$USUARIO'"

if id "$USUARIO" >/dev/null 2>&1; then
  ok "Usuario $USUARIO ja existe."
else
  echo "Vou criar o usuario '$USUARIO' com pasta /home/$USUARIO e shell bash."
  echo "Motivo: o Claude Code nao deve rodar como root."
  echo "Em seguida o sistema vai pedir para VOCE digitar a senha dele (2 vezes)."
  if confirmar "Posso criar o usuario $USUARIO?"; then
    useradd -m -s /bin/bash "$USUARIO" && ok "Usuario criado."
    echo "Agora digite a senha do usuario $USUARIO:"
    passwd "$USUARIO"
  else
    erro "Sem o usuario comum nao da para continuar."; exit 1
  fi
fi

if getent group docker >/dev/null 2>&1; then
  if id -nG "$USUARIO" | tr ' ' '\n' | grep -qx docker; then
    ok "$USUARIO ja esta no grupo docker."
  else
    echo "Vou colocar $USUARIO no grupo 'docker' para ele rodar 'docker ps' sem sudo."
    echo "Atencao: quem esta no grupo docker tem, na pratica, poder de root no CT."
    if confirmar "Posso adicionar $USUARIO ao grupo docker?"; then
      usermod -aG docker "$USUARIO" && ok "Adicionado ao grupo docker."
    fi
  fi
  if como_usuario "docker ps" >/dev/null 2>&1; then
    ok "$USUARIO consegue rodar 'docker ps' sem sudo."
  else
    aviso "$USUARIO ainda nao consegue rodar 'docker ps' (normal se o grupo acabou de ser criado; faca logout/login)."
  fi
else
  aviso "Grupo 'docker' nao existe (Docker nao instalado?). Pulando."
fi

# =============================================================================
#  ETAPA 4 - DEPENDENCIAS
# =============================================================================
titulo "ETAPA 4 - Dependencias (curl, git, tmux)"

FALTANDO=()
for p in "${PACOTES_NECESSARIOS[@]}"; do
  command -v "$p" >/dev/null 2>&1 || FALTANDO+=("$p")
done
if [ ${#FALTANDO[@]} -eq 0 ]; then
  ok "curl, git e tmux ja instalados."
else
  echo "Faltam: ${FALTANDO[*]}"
  echo "Vou rodar: apt-get update && apt-get install -y ${FALTANDO[*]}"
  if confirmar "Posso instalar?"; then
    apt-get update && apt-get install -y "${FALTANDO[@]}" && ok "Instalado: ${FALTANDO[*]}"
  else
    erro "Sem curl/git/tmux nao da para continuar."; exit 1
  fi
fi

# =============================================================================
#  ETAPA 5 - CLAUDE CODE (como usuario comum)
# =============================================================================
titulo "ETAPA 5 - Instalar o Claude Code para $USUARIO"

if como_usuario "command -v claude" >/dev/null 2>&1; then
  ok "Claude Code ja instalado: $(como_usuario 'claude --version')"
else
  echo "Vou rodar, como $USUARIO, o instalador oficial:"
  echo "    curl -fsSL https://claude.ai/install.sh | bash"
  echo "Ele instala em /home/$USUARIO/.local/bin/claude (nada fora da pasta do usuario)."
  if confirmar "Posso instalar o Claude Code?"; then
    como_usuario "curl -fsSL https://claude.ai/install.sh | bash" || { erro "Instalador falhou."; exit 1; }
  else
    erro "Sem o Claude Code nao da para continuar."; exit 1
  fi
fi

# PATH: garantir ~/.local/bin no .bashrc do usuario
BASHRC="/home/$USUARIO/.bashrc"
if ! grep -q '\.local/bin' "$BASHRC" 2>/dev/null; then
  echo "Vou adicionar ~/.local/bin ao PATH no $BASHRC (uma linha no final)."
  if confirmar "Posso editar o $BASHRC?"; then
    printf '\n# Claude Code\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$BASHRC"
    chown "$USUARIO:$USUARIO" "$BASHRC"
    ok "PATH ajustado."
  fi
else
  ok "~/.local/bin ja esta no PATH do $USUARIO."
fi

VERSAO=$(como_usuario 'claude --version' 2>/dev/null | awk '{print $1}')
if [ -z "$VERSAO" ]; then
  erro "Nao consegui obter a versao do claude. Verifique o PATH."; exit 1
fi
if versao_maior_ou_igual "$VERSAO" "$VERSAO_MINIMA"; then
  ok "Claude Code versao $VERSAO (minimo para Remote Control: $VERSAO_MINIMA)."
else
  erro "Versao $VERSAO e menor que $VERSAO_MINIMA. Rode como $USUARIO: claude update"; exit 1
fi

# =============================================================================
#  ETAPA 6 - PASTA DO PROJETO
# =============================================================================
titulo "ETAPA 6 - Pasta do projeto ~/$PROJETO"

PASTA="/home/$USUARIO/$PROJETO"
if [ -d "$PASTA" ]; then
  ok "Pasta $PASTA ja existe."
else
  echo "Vou criar $PASTA (dono: $USUARIO)."
  if confirmar "Posso criar?"; then
    como_usuario "mkdir -p '$PASTA'" && ok "Pasta criada."
  fi
fi

# Arquivo do prompt: procura ao lado do script, em /root e em /tmp
ORIGEM_PROMPT=""
for c in "$(dirname "$0")/$ARQUIVO_PROMPT" "/root/$ARQUIVO_PROMPT" "/tmp/$ARQUIVO_PROMPT"; do
  [ -f "$c" ] && { ORIGEM_PROMPT="$c"; break; }
done
if [ -f "$PASTA/$ARQUIVO_PROMPT" ]; then
  ok "$ARQUIVO_PROMPT ja esta na pasta do projeto."
elif [ -n "$ORIGEM_PROMPT" ]; then
  cp "$ORIGEM_PROMPT" "$PASTA/$ARQUIVO_PROMPT" && chown "$USUARIO:$USUARIO" "$PASTA/$ARQUIVO_PROMPT"
  ok "Copiado $ORIGEM_PROMPT -> $PASTA/"
else
  aviso "Nao encontrei $ARQUIVO_PROMPT no servidor."
  aviso "Envie do seu computador com:  scp CAMINHO/$ARQUIVO_PROMPT $USUARIO@192.168.100.111:~/$PROJETO/"
fi

if [ -d "$PASTA/.git" ]; then
  ok "git ja iniciado em $PASTA."
else
  if confirmar "Posso rodar 'git init' em $PASTA?"; then
    como_usuario "cd '$PASTA' && git init -q" && ok "git init feito."
  fi
fi

# =============================================================================
#  ETAPA 7 - SESSAO TMUX
# =============================================================================
titulo "ETAPA 7 - Sessao tmux '$SESSAO_TMUX'"

if como_usuario "tmux has-session -t $SESSAO_TMUX" >/dev/null 2>&1; then
  ok "Sessao tmux '$SESSAO_TMUX' ja existe."
else
  echo "Vou criar uma sessao tmux desanexada, como $USUARIO, ja dentro de $PASTA:"
  echo "    tmux new-session -d -s $SESSAO_TMUX -c ~/$PROJETO"
  if confirmar "Posso criar a sessao tmux?"; then
    como_usuario "tmux new-session -d -s $SESSAO_TMUX -c '$PASTA'" && ok "Sessao criada."
  fi
fi

# =============================================================================
#  RESUMO
# =============================================================================
titulo "RESUMO"
cat <<RESUMO
Usuario:            $USUARIO
Pasta do projeto:   $PASTA
Sessao tmux:        $SESSAO_TMUX
Claude Code:        $(como_usuario 'claude --version' 2>/dev/null)
Arquivo do prompt:  $([ -f "$PASTA/$ARQUIVO_PROMPT" ] && echo "presente" || echo "FALTA enviar via scp")

O login do Claude NAO foi feito (precisa de voce no navegador).
Siga o CHECKLIST.md a partir do passo "O que VOCE faz agora".
RESUMO
