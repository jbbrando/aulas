# Tarefa: melhorar o visual e a usabilidade do Fiscaliza CG

## Contexto

- Sou o João. Não sou desenvolvedor. Explique cada passo em português simples, em poucas linhas.
- Leia primeiro `docs/prompt_claude_code_fiscaliza_cg.md` (briefing do projeto) e `CONTINUAR.md`. As regras de lá continuam valendo: linguagem simples, arquivos completos, perguntar antes de decisões grandes ou destrutivas, e ao final de cada etapa rodar, testar, me mostrar o resultado e dizer como eu verifico sozinho.
- O site já funciona. O problema é estética e usabilidade. Hoje a página Início tem: sidebar escura sem ícones e sem destaque claro da página atual; cinco cards de KPI em que número e rótulo têm quase o mesmo peso; um gráfico de barras com as cores padrão do Chart.js (azul e laranja) em que a barra de 2022 nem aparece; nenhum estado vazio ou de erro; e um layout que não foi pensado para celular.
- O público é o cidadão comum de Campo Grande. Tudo tem que ser entendido por quem nunca viu uma licitação. O aviso "Tudo aqui é sinal para verificar, nunca acusação. Confira sempre a fonte." é obrigatório e precisa aparecer perto de todo alerta.

## Regras desta tarefa

1. **Não mude nada de coleta, banco de dados ou regras de cálculo.** Só a camada visual: HTML, CSS, JavaScript do front, templates e textos de interface. Se algum número parecer errado, me avise, mas não mexa.
2. **Faça um commit no Git ao final de cada etapa** (1 a 6) com mensagem em português descrevendo o que mudou. Antes de começar, confirme que a árvore de trabalho está limpa; se não estiver, me pergunte.
3. **Antes de cada etapa, diga em duas ou três linhas o que vai fazer e espere meu OK.** Dentro da etapa, não precisa pedir OK a cada arquivo.
4. **Tire screenshots antes e depois** de cada mudança visual e me mostre. Nunca altere CSS "no escuro".
5. Nada de framework novo. Se o site usa Bootstrap ou CSS puro, continue com isso. Pode adicionar no máximo uma fonte do Google Fonts e uma biblioteca de ícones leve (por exemplo, Lucide ou Bootstrap Icons).
6. Se alguma skill ou plugin não puder ser instalado, não trave: me diga o comando ou o menu que eu preciso usar, e siga com o que estiver disponível. As regras que a skill traria devem ir para a skill do projeto (etapa 2).

## Etapa 1: instalar e conferir skills e plugins

Verifique o que já está disponível (`/skills` ou a lista de skills da sessão) e instale o que faltar. Lista desejada, em ordem de prioridade:

| Nome | Origem | Para que serve aqui |
|---|---|---|
| `frontend-design` | plugin oficial da Anthropic (marketplace `claude-plugins-official`) | direção visual: hierarquia, tipografia, cor, espaçamento |
| `dataviz` | skill embutida do Claude Code | gráficos, cards de KPI e dashboards |
| VectorLab UI/UX Skills | diretório de plugins da Anthropic (claude.ai) | `typography`, `spacing`, `colour-palette`, `empty-states`, `errors`, `page-patterns`, `viewports`, `ux-audit` |
| Design (Anthropic) | diretório de plugins da Anthropic (claude.ai) | `design-critique`, `design-system`, `accessibility-review`, `ux-copy` |
| `ux-ui-audit` | diretório de plugins da Anthropic (claude.ai) | auditoria medida no navegador: contraste, alvos de toque, foco |
| `skill-creator` | plugin `anthropic-skills` | criar a skill própria do projeto |
| `run` | skill embutida do Claude Code | subir o site e tirar screenshots |

Como instalar:
- Tente primeiro pela linha de comando: `claude plugin install <nome>@claude-plugins-official` ou `/plugin install <nome>`. Se o plugin estiver só no diretório do claude.ai, me diga para habilitar em Configurações > Plugins no app do Claude e me avise qual nome procurar.
- Depois de instalar, rode `/skills` de novo e me mostre a lista final: o que foi instalado, o que ficou de fora e por quê.
- Garanta que o Chromium ou o Playwright funcionam para screenshots. Se precisar instalar o Playwright no projeto, pergunte antes.

## Etapa 2: criar a skill própria do projeto

Use a `skill-creator` para criar `.claude/skills/fiscaliza-design/SKILL.md`. Ela deve ser carregada automaticamente sempre que eu pedir qualquer mudança de tela, e deve conter:

- **Paleta com significado fixo.** Uma cor para "com licitação", outra para "sem licitação", três níveis de alerta (grave, atenção, informativo), neutros para texto e fundo. As cores de alerta não podem competir com as cores do gráfico. Valide o contraste (WCAG AA no mínimo). Use a `dataviz` para escolher a paleta dos gráficos.
- **Tipografia e espaçamento.** Uma fonte, escala de tamanhos definida, espaçamento em múltiplos de 4 ou 8 px.
- **Regras de texto.** Linguagem simples, nenhuma sigla sem explicação na primeira vez (PNCP, CNPJ, dispensa, inexigibilidade), valores sempre abreviados ("R$ 2,7 bi", "R$ 830 mi"), datas por extenso curtas ("12 mar 2026"), e o aviso de "sinal, não acusação" junto de todo alerta.
- **Componentes padrão** com HTML e classes prontas: card de KPI (número grande, rótulo abaixo, variação opcional), cabeçalho de página (título + uma frase explicando o que a página mostra), tabela com ordenação e paginação, filtro de período, badge de nível de alerta, estado vazio, estado de erro, estado de carregando.
- **Mobile primeiro.** Sidebar vira menu no celular, tabelas viram lista de cards abaixo de 768 px, nada de rolagem horizontal.
- **Acessibilidade.** Foco visível no teclado, alvos de toque com pelo menos 44 px, textos alternativos, contraste validado.

Me mostre a skill pronta e espere meu OK antes de seguir.

## Etapa 3: diagnóstico antes de mexer

1. Suba o site com a skill `run` e tire screenshots de **todas** as páginas (Início, Alertas, Empresas, Licitações, Concorrência, Preços, Pessoas, Notícias, Rede) em desktop (1366 px) e celular (390 px). Guarde em `docs/screenshots/antes/`.
2. Rode a `design-critique` e a `ux-ui-audit` na página Início e na página Alertas.
3. Me entregue um resumo de uma página, em linguagem simples, com os 10 problemas mais importantes, em ordem de impacto para o cidadão. Para cada um, diga em uma linha o que vai fazer.

Espere meu OK na lista antes de implementar.

## Etapa 4: implementar as melhorias

Siga a ordem abaixo. Em cada item, use a skill do projeto e as skills indicadas, tire screenshot antes e depois, e me mostre.

1. **Base visual** (`frontend-design`, `typography`, `spacing`, `colour-palette`): aplicar a paleta, a fonte e a escala da skill do projeto em todo o site. Sidebar com ícones, página atual destacada, nome do projeto com um subtítulo de uma linha explicando o que é.
2. **Página Início** (`dataviz`): refazer os cards de KPI com hierarquia clara; refazer o gráfico anual com a paleta do projeto, totais em cima das barras, tooltip explicando "com" e "sem licitação", e 2022 visível ou com nota explicando por que é pequeno. Adicionar embaixo do gráfico uma frase em linguagem simples dizendo o que ele mostra.
3. **Alertas** (`ux-copy`, `page-patterns`): cada alerta com badge de nível, título em uma frase que um leigo entende, "por que isso é um sinal" e "como verificar" com link para a fonte no PNCP. Aviso de "sinal, não acusação" sempre visível.
4. **Páginas de lista** (Empresas, Licitações, Preços, Pessoas): cabeçalho com explicação, filtros no topo, tabela com ordenação, e versão em cards no celular.
5. **Estados** (`empty-states`, `errors`): estado vazio, de erro e de carregando em toda página que busca dados. Busca sem resultado deve sugerir o que tentar.
6. **Celular** (`viewports`): revisar tudo em 390 px. Menu, tabelas, gráficos e busca têm que funcionar com o polegar.
7. **Acessibilidade** (`accessibility-review`, `ux-ui-audit`): corrigir tudo que a auditoria apontar como contraste, foco e alvo de toque.

## Etapa 5: verificar

1. Screenshots de todas as páginas, desktop e celular, em `docs/screenshots/depois/`.
2. Rodar de novo `ux-ui-audit` e `design-critique` nas mesmas páginas da etapa 3 e me mostrar o antes e depois dos números (contraste, alvos de toque, problemas encontrados).
3. Rodar os testes que já existem no projeto e confirmar que a coleta e o banco não foram tocados (`git diff --stat` só com arquivos de front).

## Etapa 6: fechamento

- Commit final e atualização do `CONTINUAR.md` com o que mudou e o que ficou pendente.
- Me explique em dez linhas, sem termos técnicos, o que mudou e como eu confiro sozinho no celular e no computador.
- Pare e espere. Não comece outra fase.
