-- Esquema do banco vetorial (Supabase / PostgreSQL com pgvector)
-- Dimensao 3072 = tamanho dos vetores do modelo gemini-embedding-001.
-- Se trocar o modelo de embeddings, ajuste a dimensao aqui e reindexe tudo.

create extension if not exists vector;

drop function if exists match_documents(vector, int, jsonb);
drop table if exists documents;

create table documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(3072)
);

-- Busca por similaridade (distancia de cosseno), usada pelo n8n
create function match_documents (
  query_embedding vector(3072),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Faz a API do Supabase reconhecer a funcao
notify pgrst, 'reload schema';
