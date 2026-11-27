# Assistente do ECA com Banco de Dados Vetorial e RAG

![n8n](https://img.shields.io/badge/Orquestra%C3%A7%C3%A3o-n8n-EA4B71?logo=n8n&logoColor=white)
![Supabase](https://img.shields.io/badge/Banco-Supabase-3ECF8E?logo=supabase&logoColor=white)
![pgvector](https://img.shields.io/badge/Vetorial-pgvector-336791?logo=postgresql&logoColor=white)
![Google Gemini](https://img.shields.io/badge/IA-Google%20Gemini-4285F4?logo=googlegemini&logoColor=white)
![Embeddings 3072](https://img.shields.io/badge/Embeddings-3072%20dimens%C3%B5es-orange)
![ECA Arts. 1 a 169](https://img.shields.io/badge/ECA-Arts.%201%20a%20169-8A2BE2)

Trabalho de Composição da 3ª avaliação da disciplina de **Projeto de Banco de Dados**, do curso de Engenharia de Software do Centro Universitário Santo Agostinho (UNIFSA).

## Sobre o projeto

Este projeto é um assistente que responde perguntas sobre o Estatuto da Criança e do Adolescente (ECA, Lei 8.069/1990). Em vez de depender apenas do conhecimento do modelo de IA, o sistema guarda os artigos da lei em um banco de dados vetorial, localiza por similaridade semântica os trechos mais relevantes para cada pergunta e entrega esses trechos ao modelo como contexto. A resposta é gerada somente a partir do que foi recuperado, com citação dos artigos usados.

O tema do trabalho é Banco de Dados Vetorial e RAG (Retrieval-Augmented Generation), e a solução foi construída com o n8n como orquestrador.

## Objetivo

Demonstrar, em uma aplicação com finalidade prática, os conceitos estudados em sala:

- armazenamento de embeddings em um banco de dados vetorial;
- busca por similaridade semântica;
- geração de respostas com IA a partir do contexto recuperado (RAG).

## Atendimento aos requisitos do trabalho

| Requisito | Como foi atendido |
|---|---|
| Banco de dados vetorial | Supabase (PostgreSQL com a extensão pgvector) |
| Geração de embeddings | Modelo `gemini-embedding-001` do Google, vetores de 3072 dimensões |
| Recuperação de informações | Função SQL `match_documents`, busca por distância de cosseno |
| Implementação de RAG | Agente de IA no n8n que consulta o banco antes de responder |
| Interface de interação | Chat do n8n |
| Tecnologias livres / bônus | n8n usado na ingestão e no agente de consulta |

## Como funciona

O sistema tem dois workflows no n8n.

**1. Ingestão (`embedding_ECA.json`)**: executado uma vez para montar a base.

```
Formulário (envio do PDF)
  -> Extração do texto do PDF
  -> Limpeza e divisão por artigo (nó Code)
  -> Divisão em chunks (Recursive Character Text Splitter)
  -> Geração dos embeddings (Gemini)
  -> Inserção no Supabase (tabela documents)
```

**2. Consulta (`agent.json`)**: executado a cada pergunta.

```
Pergunta no chat
  -> AI Agent (Gemini)
  -> Ferramenta buscar_eca
       -> embedding da pergunta (Gemini)
       -> busca dos 4 trechos mais similares no Supabase
  -> Resposta gerada com base nos trechos recuperados, citando os artigos
```

O agente recebe uma instrução de sistema que o obriga a consultar a ferramenta em toda pergunta, responder apenas com base nos trechos retornados, citar os artigos e informar quando a resposta não estiver na base.

## Tecnologias utilizadas

- n8n (orquestração dos workflows e interface de chat)
- Supabase com PostgreSQL e pgvector (banco de dados vetorial)
- Google Gemini (modelo de embeddings e modelo de linguagem)
- JavaScript (limpeza e divisão do texto no nó Code)
- SQL (esquema da tabela e função de busca)

## Estrutura do repositório

```
.
├── README.md
├── sql/
│   └── schema.sql             Tabela e função de busca do Supabase
├── workflows/
│   ├── embedding_ECA.json     Workflow de ingestão
│   └── agent.json             Workflow do chat (RAG)
└── data/
    └── lei_8069_eca.pdf       Texto do ECA usado como base
```

## Base de conhecimento

- **Fonte:** texto compilado da Lei 8.069/1990, publicado pelo Planalto, em PDF.
- **Cobertura:** artigos 1 a 169, o que corresponde a 186 artigos, incluindo os com letra (por exemplo, 11-A e 19-B). Ficam de fora os artigos a partir do 170 (procedimentos judiciais, crimes e infrações administrativas). Perguntas sobre esses temas retornam que a informação não foi encontrada.
- **Tratamento do texto:** o texto compilado traz as redações antigas junto com a vigente e várias notas legislativas. O nó Code remove as notas, mantém a última ocorrência de cada artigo (a redação vigente), descarta artigos revogados e as disposições finais (artigos 263 em diante) e gera um item por artigo, com o número do artigo salvo no metadata.
- **Chunks:** artigos longos são divididos em pedaços de até 2000 caracteres, com sobreposição de 100. A base final tem 451 chunks.

## Banco de dados

A tabela `documents` guarda o texto, o metadata (número do artigo) e o embedding de cada chunk:

| Coluna | Tipo |
|---|---|
| id | bigserial |
| content | text |
| metadata | jsonb |
| embedding | vector(3072) |

A função `match_documents` recebe o embedding da pergunta e devolve os chunks mais próximos, ordenados pela distância de cosseno. Não foi criado índice vetorial (HNSW ou IVFFlat), porque o pgvector limita índices a 2000 dimensões e o volume de dados é pequeno, então a busca exata é rápida.

O script completo está em [`sql/schema.sql`](sql/schema.sql).

## Como executar

### Pré-requisitos

- Conta no Supabase (plano gratuito)
- Chave de API do Google Gemini, obtida no Google AI Studio
- n8n em execução local, por exemplo via Docker:

```bash
docker run -it --rm --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

O n8n fica disponível em `http://localhost:5678`.

### Passo a passo

1. **Banco de dados:** crie um projeto no Supabase, abra o SQL Editor e execute o conteúdo de `sql/schema.sql`.
2. **Importar os workflows:** no n8n, use a opção de importar de arquivo e carregue `workflows/embedding_ECA.json` e `workflows/agent.json`.
3. **Credenciais:** crie no n8n a credencial do Supabase (Project URL e chave `service_role`) e a credencial do Google Gemini (PaLM) com a sua chave de API. Associe-as aos nós dos dois workflows. As chaves ficam apenas no n8n e não fazem parte do repositório.
4. **Ingestão:** abra o workflow `embedding ECA`, execute-o, acesse a URL do formulário e envie o PDF de `data/lei_8069_eca.pdf`. O nó Code possui as variáveis `INICIO` e `LIMITE`, que permitem enviar os artigos em lotes caso o limite do plano gratuito da API seja atingido (`LIMITE = 0` processa todos).
5. **Conferência:** no Supabase, execute `select count(*) from documents;` para verificar que os chunks foram inseridos.
6. **Uso:** abra o workflow `agent`, clique em abrir o chat e faça perguntas.

## Exemplos de perguntas

- Qual a idade mínima para começar a trabalhar?
- O que é o Conselho Tutelar?
- Quais são os requisitos para a adoção?
- Pergunta fora do tema (por exemplo, "Quem ganhou a Copa de 2022?"): o assistente informa que não encontrou a resposta no ECA.

## Limitações

- A base cobre os artigos 1 a 169 do ECA.
- O conteúdo reflete a versão do texto presente no PDF utilizado e pode não incluir alterações legislativas posteriores.
- A aplicação tem finalidade educacional e não substitui orientação jurídica.
- A execução é local, com o n8n rodando na máquina do autor.

## Vídeo demonstrativo

[\[LINK DO VIDEO NO YOUTUBE\]](https://youtu.be/0ITUkEXHtsk?si=1vcSIf2js-p_xDJ9)

O vídeo apresenta a tabela com os embeddings no Supabase, o workflow de ingestão, o chat respondendo perguntas e os logs do agente mostrando a busca vetorial e os trechos recuperados.

## Autores

Artur França de Paula Araújo, Pedro Henrique Silva Rufino -  
Engenharia de Software, Centro Universitário Santo Agostinho (UNIFSA)
