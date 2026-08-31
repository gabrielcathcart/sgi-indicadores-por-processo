-- Guarda de privacidade: nenhuma coluna com nome tipico de dado pessoal /
-- identificador direto pode existir nos modelos de staging, intermediate,
-- marts ou analytics.
--
-- Usa regexp_matches (POSIX, nao ancorado) porque o SIMILAR TO do DuckDB nao
-- casa '%token%' de forma confiavel para esta finalidade.
--
-- Allowlist (nao sao PII):
--   paciente_id_pseudonimo  -> chave sintetica ("PAC" + contador)
--   dia_semana_nome         -> rotulo de calendario (Seg..Dom)
--   cor_nome                -> rotulo da paleta de Manchester
select table_schema, table_name, column_name
from information_schema.columns
where table_schema in ('staging', 'intermediate', 'marts', 'analytics')
  and regexp_matches(
        lower(column_name),
        'nome|nm_|cpf|cns|cartao_sus|prontuario|passaporte|(^|_)rg(_|$)|telefone|celular|e_?mail|endereco|logradouro|bairro|(^|_)cep(_|$)|nascimento'
      )
  and lower(column_name) not in (
        'paciente_id_pseudonimo',
        'dia_semana_nome',
        'cor_nome'
      )
