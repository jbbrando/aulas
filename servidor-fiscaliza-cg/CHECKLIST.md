# Claude Code com Remote Control no CT 101 — guia do João

Servidor: **CT 101** (LXC no Proxmox), IP **192.168.100.111**.
Usuário que vai rodar o Claude: **joao**. Pasta do projeto: **~/fiscaliza-cg**.

> Importante: o Claude da nuvem (esta sessão) não alcança a sua rede local.
> Por isso os passos abaixo são feitos por você, no seu computador e no servidor.
> O script `preparar-ct101.sh` faz o trabalho pesado e pede seu OK antes de cada mudança.

---

## Parte A — Acesso ao servidor (no SEU computador)

1. Teste o acesso. Primeiro tente como root, que é o padrão num CT do Proxmox:
   ```
   ssh root@192.168.100.111
   ```
   Se pedir senha, digite a senha do CT. Se entrar, você já sabe o usuário: `root`.
   Se der "Permission denied", tente outro usuário que você tenha criado.

2. (Opcional, mas recomendado) Chave SSH para não digitar senha toda vez:
   ```
   ssh-keygen -t ed25519
   ssh-copy-id root@192.168.100.111
   ```
   O primeiro comando só é preciso se você ainda não tem chave (pode dar Enter em tudo).
   O segundo pede a senha do servidor uma única vez.

3. Saia do servidor com `exit`.

## Parte B — Enviar os arquivos (no SEU computador)

Troque `CAMINHO/` pela pasta onde você salvou cada arquivo.

```
scp CAMINHO/preparar-ct101.sh root@192.168.100.111:/root/
scp CAMINHO/prompt_claude_code_fiscaliza_cg.md root@192.168.100.111:/root/
```

## Parte C — Rodar o script (no SERVIDOR)

```
ssh root@192.168.100.111
bash /root/preparar-ct101.sh
```

O script faz, nesta ordem, e **pergunta antes de cada mudança**:

| Etapa | O que faz | Por quê |
|---|---|---|
| Diagnóstico | Mostra sistema, RAM, disco, usuários, versões, portas e containers | Só leitura, nada muda |
| 3. Usuário | Cria `joao` e põe no grupo `docker`. **Você digita a senha** | O Claude não deve rodar como root |
| 4. Pacotes | `apt-get install curl git tmux` (só o que faltar) | Instalador, git e sessão persistente |
| 5. Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash`, como `joao` | Instalador oficial, versão mais nova |
| 5. PATH | Adiciona `~/.local/bin` no `.bashrc` do joao | Para o comando `claude` funcionar |
| 6. Pasta | Cria `~/fiscaliza-cg`, copia o prompt, roda `git init` | Pasta de trabalho da sessão |
| 7. tmux | `tmux new-session -d -s fiscaliza -c ~/fiscaliza-cg` | Sessão que sobrevive ao fechar o SSH |

Responda `s` para aceitar cada etapa. Nenhuma senha é gravada em arquivo.
O script **não** mexe em containers, volumes, `docker-compose.yml`, nem reinicia nada.

Se o arquivo do prompt não estava em `/root/`, o script avisa. Envie depois com:
```
scp CAMINHO/prompt_claude_code_fiscaliza_cg.md joao@192.168.100.111:~/fiscaliza-cg/
```

---

## Parte D — O que VOCÊ faz agora (login e sessão remota)

1. Entrar no servidor como o usuário comum:
   ```
   ssh joao@192.168.100.111
   ```
2. Entrar na sessão tmux:
   ```
   tmux attach -t fiscaliza
   ```
3. Fazer login no Claude (uma vez só):
   ```
   claude
   ```
   Aparece um link. Abra no navegador do seu computador ou celular, autorize,
   e cole o código de volta no terminal se for pedido. Depois saia com `/exit`.
   (Precisa de plano Pro, Max, Team ou Enterprise. Chave de API não serve para Remote Control.)
4. Iniciar a sessão com Remote Control:
   ```
   claude --remote-control "Fiscaliza CG"
   ```
   Na primeira vez ele pergunta se confia na pasta e se quer ativar o Remote Control. Responda sim.
5. Sair do tmux **sem** matar a sessão: aperte `Ctrl+B`, solte, depois aperte `D`.
   Pode fechar o SSH; o Claude continua rodando.
6. No celular: abrir o app do Claude → **Code** → abrir a sessão **"Fiscaliza CG"** e enviar:
   > Leia o arquivo prompt_claude_code_fiscaliza_cg.md nesta pasta e siga as instruções, começando pela Fase 0.
7. Se o servidor reiniciar (a sessão tmux some), refaça:
   ```
   ssh joao@192.168.100.111
   tmux new-session -d -s fiscaliza -c ~/fiscaliza-cg
   tmux attach -t fiscaliza
   claude --continue
   ```
   `claude --continue` retoma a última conversa da pasta e reconecta o Remote Control.
   Se o app não mostrar a sessão de novo, digite dentro do Claude: `/remote-control Fiscaliza CG`.
   Depois `Ctrl+B`, `D` para sair do tmux.

---

## Como desfazer tudo (no SERVIDOR, como root)

```
# 1. Encerrar a sessão tmux do joao
su - joao -c 'tmux kill-session -t fiscaliza'

# 2. Remover o Claude Code e suas configurações (só da pasta do joao)
rm -f  /home/joao/.local/bin/claude
rm -rf /home/joao/.local/share/claude /home/joao/.claude /home/joao/.claude.json

# 3. (Opcional) Apagar a pasta do projeto
rm -rf /home/joao/fiscaliza-cg

# 4. (Opcional) Apagar o usuário e a pasta home dele
userdel -r joao

# 5. (Opcional) Remover os pacotes, se foram instalados pelo script
apt-get remove -y tmux        # curl e git costumam ser usados por outras coisas; só remova se tiver certeza
```

Nada disso toca no Docker, nos containers ou no host do Proxmox.
