# Tarefa: preparar meu servidor para rodar o Claude Code com Remote Control

## Contexto

- Sou o João. Não sou desenvolvedor. Explique cada passo em português simples, em poucas linhas.
- Você está rodando no meu computador, na mesma rede local do servidor. Use o terminal e acesse o servidor por SSH.
- Servidor de destino: **CT 101**, um LXC no Proxmox, IP **192.168.100.111**, que roda meu stack Docker.
  - **Não mexa no host do Proxmox (192.168.100.113).**
  - **Não altere containers, volumes nem o `docker-compose.yml` existentes.**
- Objetivo: deixar o Claude Code instalado no CT 101 e rodando uma sessão com Remote Control chamada **"Fiscaliza CG"**, dentro da pasta `~/fiscaliza-cg` do usuário comum `joao`, para eu controlar pelo app do Claude no celular.
- Nesta pasta do workspace estão os arquivos de apoio:
  - `preparar-ct101.sh`: script que faz as etapas 2 a 7 com confirmação a cada mudança. Use-o como referência dos comandos; prefira rodar as etapas uma a uma como descrito abaixo, porque assim você me pergunta no chat antes de cada mudança.
  - `CHECKLIST.md`: guia dos passos finais que eu mesmo faço.
  - `prompt_claude_code_fiscaliza_cg.md`: arquivo que deve ir para `~/fiscaliza-cg` no servidor. Se ele não estiver nesta pasta, me pergunte onde salvei.

## Regras de segurança (obrigatórias)

1. **Antes de qualquer comando que altere o sistema** (instalar pacote, criar usuário, mudar grupo, editar arquivo, criar pasta), diga em uma ou duas linhas o que vai fazer e por quê, e **espere meu OK** no chat.
2. **Nunca peça, digite nem grave senhas** em arquivos ou comandos. Comandos que pedem senha (`ssh-copy-id`, `passwd`, login do Claude) **eu mesmo rodo** no terminal: me passe o comando exato e espere eu avisar que terminei.
3. Não use `sshpass` nem truques para passar senha. Se o SSH pedir senha, pare e me oriente a configurar chave (passo 1).
4. **Não reinicie o CT 101 nem o Docker.** Não rode `docker compose down/up`, `systemctl restart docker`, `reboot` ou similares.
5. Rode comandos no servidor sempre no formato `ssh root@192.168.100.111 'comando'` (ou `ssh joao@...` quando a etapa pedir o usuário comum). Comandos que precisam de terminal interativo, me passe para eu rodar.
6. Se algo der errado, pare, mostre a mensagem de erro e me pergunte. Não tente "consertar" removendo ou reinstalando coisas por conta própria.
7. Ao final de cada etapa, mostre em uma linha o resultado (ex.: "Etapa 4: curl e git já existiam, tmux instalado").

## Passos

### 1. Verificar acesso

- Teste: `ssh -o BatchMode=yes -o ConnectTimeout=5 root@192.168.100.111 'hostname; id'`.
- Se funcionar sem senha, siga em frente com `root`.
- Se falhar pedindo senha, me oriente assim e espere eu confirmar:
  - Se eu não tiver chave: `ssh-keygen -t ed25519` (dar Enter em tudo).
  - Depois: `ssh-copy-id root@192.168.100.111` (eu digito a senha).
  - Teste de novo.
- Se `root` não entrar de jeito nenhum, me pergunte qual usuário eu uso e se ele tem `sudo`.

### 2. Diagnóstico (somente leitura, não precisa de OK)

Rode no servidor e me mostre um resumo curto de:

```
cat /etc/os-release
uname -m; free -h; df -h /
awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd
curl --version | head -1; git --version; tmux -V; docker --version; docker compose version
su - joao -c 'claude --version' 2>/dev/null || echo "claude nao instalado para joao"
ss -tlnp
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

Diga: sistema e versão, arquitetura, RAM livre, disco livre, se existe usuário comum, o que falta entre curl/git/tmux, se o Docker está rodando e quais containers existem (só referência).

### 3. Usuário dedicado `joao` (só se não existir)

- Proponha criar e espere meu OK: `useradd -m -s /bin/bash joao`.
- Depois me peça para rodar **eu mesmo** no terminal: `ssh -t root@192.168.100.111 'passwd joao'`. Espere eu avisar.
- Com meu OK, coloque no grupo docker: `usermod -aG docker joao`. Avise que estar no grupo docker equivale, na prática, a poder de root dentro do CT.
- Confirme: `su - joao -c 'docker ps'` deve funcionar sem sudo.
- O Claude Code vai rodar com esse usuário, nunca como root.

### 4. Dependências

- Só instale o que faltar entre `curl`, `git` e `tmux`. Com meu OK:
  `apt-get update && apt-get install -y <os-que-faltam>`.

### 5. Instalar o Claude Code (como `joao`)

- Instalador oficial (confirmado na documentação em https://code.claude.com/docs/en/setup). Com meu OK, rode como `joao`:
  `su - joao -c 'curl -fsSL https://claude.ai/install.sh | bash'`
- Ele instala em `/home/joao/.local/bin/claude`. Garanta o PATH: se `/home/joao/.bashrc` ainda não tiver `.local/bin`, com meu OK adicione ao final:
  `export PATH="$HOME/.local/bin:$PATH"`
- Confirme: `su - joao -c 'claude --version'`. Precisa ser **2.1.51 ou superior**. Se for menor: `su - joao -c 'claude update'`.
- **Não faça o login do Claude.** É interativo e precisa de mim no navegador.

### 6. Pasta do projeto

- Com meu OK: `su - joao -c 'mkdir -p ~/fiscaliza-cg'`.
- Copie o arquivo do meu computador: `scp prompt_claude_code_fiscaliza_cg.md joao@192.168.100.111:~/fiscaliza-cg/` (se o `scp` como `joao` pedir senha, copie como `root` para `/root/` e depois mova com `mv /root/prompt_claude_code_fiscaliza_cg.md /home/joao/fiscaliza-cg/ && chown joao:joao /home/joao/fiscaliza-cg/prompt_claude_code_fiscaliza_cg.md`).
- Com meu OK: `su - joao -c 'cd ~/fiscaliza-cg && git init'`.

### 7. Sessão tmux

- Com meu OK, crie a sessão desanexada como `joao`:
  `su - joao -c 'tmux new-session -d -s fiscaliza -c ~/fiscaliza-cg'`
- Confirme com `su - joao -c 'tmux ls'`.

### 8. Me entregue este checklist (não execute, é para eu fazer)

1. Entrar no servidor: `ssh joao@192.168.100.111`
2. Entrar na sessão: `tmux attach -t fiscaliza`
3. Rodar `claude`, abrir o link de login que aparecer, autorizar e colar o código de volta se for pedido. Sair com `/exit`.
4. Iniciar a sessão remota: `claude --remote-control "Fiscaliza CG"` (na primeira vez, responder sim para confiar na pasta e ativar o Remote Control).
5. Sair do tmux sem matar a sessão: `Ctrl+B`, soltar, depois `D`.
6. No celular: app do Claude, aba Code, abrir a sessão "Fiscaliza CG" e enviar como primeira mensagem:
   "Leia o arquivo prompt_claude_code_fiscaliza_cg.md nesta pasta e siga as instruções, começando pela Fase 0."
7. Se o servidor reiniciar: `ssh joao@192.168.100.111`, depois `tmux new-session -d -s fiscaliza -c ~/fiscaliza-cg`, `tmux attach -t fiscaliza`, `claude --continue`. Se a sessão não voltar no app, digitar dentro do Claude: `/remote-control Fiscaliza CG`.

### 9. Resumo final

Ao terminar, me mostre:

- o que foi instalado ou alterado no servidor (lista curta);
- o usuário e a pasta usados;
- o checklist do passo 8;
- como desinstalar tudo, se eu quiser desfazer:

```
su - joao -c 'tmux kill-session -t fiscaliza'
rm -f  /home/joao/.local/bin/claude
rm -rf /home/joao/.local/share/claude /home/joao/.claude /home/joao/.claude.json
rm -rf /home/joao/fiscaliza-cg      # opcional
userdel -r joao                     # opcional
apt-get remove -y tmux              # opcional, só se foi instalado agora
```
