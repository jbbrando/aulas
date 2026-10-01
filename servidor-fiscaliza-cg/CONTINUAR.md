# Continuação — Fiscaliza CG (handoff de sessão)

Leia primeiro `docs/prompt_claude_code_fiscaliza_cg.md`: é o briefing completo do projeto,
com regras de trabalho, fases, red flags e restrições. Siga-o à risca: responda em português
do Brasil, explique em linguagem simples (não sou desenvolvedor), entregue arquivos
completos, pergunte antes de decisões grandes ou destrutivas, e ao final de cada fase rode,
teste, mostre o resultado e diga como eu verifico sozinho.

## Onde estamos: final da Fase 0 (falta confirmar que subiu)

### Ambiente (já verificado)
- Servidor: CT 101 (LXC Proxmox, 192.168.100.111). Projeto em `~/fiscaliza-cg`, com
  compose próprio. Não mexer nos outros containers.
- Porta 3000 = AdGuard e Grafana = 3003. Escolhida **3010** para o Metabase (estava livre).
- Postgres sem porta exposta (só na rede Docker `fiscaliza-net`).
- O DNS durante o `docker build` falha neste host (resolv.conf só com IPv6), mas os
  containers em execução resolvem normalmente. Solução adotada: `build.network: host` no
  serviço `coletor`. O DNS do daemon Docker não foi alterado.

### O que a API do PNCP mostrou (já testado)
- A base `https://pncp.gov.br/api/consulta` funciona sem autenticação. O IBGE **5002704**
  é Campo Grande (confirmado).
- `/v1/contratacoes/publicacao` exige `codigoModalidadeContratacao` e aceita
  `codigoMunicipioIbge` e `cnpj`. O filtro por município traz também órgãos federais e
  estaduais sediados em CG (ex.: Comando da Marinha). Filtrar por `orgaoEntidade.esferaId == "M"`.
- `/v1/contratos` e `/v1/atas` **não filtram por município**, só por `cnpjOrgao`. Por isso
  a descoberta de entidades (Fase 1a) é a base de toda a coleta.
- Também existem `/v1/contratacoes/atualizacao` e `/v1/contratos/atualizacao`, úteis para
  a coleta incremental diária.
- Detalhes ficam em outra base, `https://pncp.gov.br/api/pncp`, por exemplo
  `/v1/orgaos/{cnpj}/compras/{ano}/{sequencial}/itens` (testado, funciona).
- A API responde **HTTP 204** (sem corpo) quando não há resultados, e o cliente trata isso
  como "vazio".
- Contratos da Prefeitura (CNPJ 03501509000106): nada em set/2025, mas há registros em 2024
  e no 1º semestre de 2025. O primeiro contrato só foi publicado no PNCP em dez/2024.
  Provavelmente muitos contratos saem por fundos e secretarias com CNPJ próprio, o que
  reforça a importância da Fase 1a.

### Arquivos criados
- `docker-compose.yml`: postgres:16-alpine, coletor (build ./coletor, Python 3.12) e
  metabase/metabase:v0.63.19 na porta 3010, com fuso America/Campo_Grande.
- `.env.example` e `.env` (senhas aleatórias, chmod 600, fora do Git). `.gitignore` criado.
- `db/init/01_bancos.sh`: roda só no 1º start. Cria o banco `metabase`, o usuário
  somente-leitura `metabase_leitura` e o fuso do banco.
- `db/migracoes/001_inicial.sql`: tabelas `raw_pncp` (JSON bruto por fonte+chave, com
  hash), `entidades` e `execucoes_coleta`. As migrações são aplicadas pelo coletor e
  ficam registradas em `migracoes_aplicadas`.
- `coletor/`:
  - `Dockerfile` e `requirements.txt` (httpx, psycopg3, APScheduler, PyYAML, pytest).
  - `fiscaliza/config.py`: lê o .env.
  - `fiscaliza/logs.py`: logs no terminal e em `logs/coletor.log`, com rotação diária.
  - `fiscaliza/db.py`: conexão e migrações.
  - `fiscaliza/pncp.py`: `ClientePNCP` com pausa entre chamadas, retry com backoff
    (429/5xx/rede), 204 tratado como None e `paginar()`.
  - `fiscaliza/__main__.py`: comandos `testar`, `migrar` e `agendador`. A rotina diária
    das 03:30 ainda é um placeholder, a ser preenchida na Fase 1b.
  - `tests/test_pncp.py`: testes do cliente com respostas simuladas.
- O briefing foi movido para `docs/`.
- Ainda **não houve nenhum commit no Git** (branch atual `master`).

## Próximos passos
1. Conferir se o stack subiu: `docker compose ps`, `docker compose logs coletor`. Se o
   build falhou, corrigir.
2. Rodar `docker compose exec coletor python -m fiscaliza testar` e
   `docker compose exec coletor python -m pytest -q`.
3. Abrir `http://192.168.100.111:3010` e fazer o setup inicial do Metabase. Conectar ao
   banco `fiscaliza` com o usuário `metabase_leitura` (host `postgres`, porta 5432).
4. Escrever o README inicial para leigo (ainda não existe): como subir, testar, ver logs,
   e o aviso de que os dados de 2022–2023 no PNCP podem estar incompletos.
5. Mostrar o resultado da Fase 0, me explicar como verificar sozinho e propor um commit
   inicial.
6. **Fase 1a**: descoberta de entidades. Varrer `/v1/contratacoes/publicacao` por
   `codigoMunicipioIbge=5002704` em todas as modalidades, de 04/04/2022 até hoje, filtrar
   `esferaId == "M"`, gravar na tabela `entidades` e **parar para me mostrar a lista**,
   para eu decidir quais incluir.
