{#
    Helpers reutilizados pelos modelos de urgencia. Mantidos aqui so quando
    evitam repeticao real entre >1 modelo.
#}

{# Diferenca em minutos (inteiro) entre dois timestamps. NULL se qualquer um
   for NULL. Pode ser NEGATIVA (sequencia invalida) -- de proposito: o dado
   bruto nao e "corrigido"; a invalidez e sinalizada por flag. #}
{% macro diff_min(inicio, fim) -%}
    case
        when {{ inicio }} is null or {{ fim }} is null then null
        else round(date_diff('second', {{ inicio }}, {{ fim }}) / 60.0)::int
    end
{%- endmacro %}


{# Nome pt-BR do dia da semana a partir de um numero ISO (1=segunda ... 7=domingo). #}
{% macro dia_semana_nome(iso_expr) -%}
    case {{ iso_expr }}
        when 1 then 'Segunda' when 2 then 'Terca' when 3 then 'Quarta'
        when 4 then 'Quinta'  when 5 then 'Sexta' when 6 then 'Sabado'
        when 7 then 'Domingo'
    end
{%- endmacro %}


{# Faixa etaria analitica do portfolio (corte parametrizado em dbt_project.yml).
   Convencao deste projeto -- nao e regra clinica/regulatoria. #}
{% macro faixa_etaria(idade_expr) -%}
    case
        when {{ idade_expr }} is null then null
        when {{ idade_expr }} < {{ var('idade_corte_pediatrico_anos') }} then 'Pediatrico'
        else 'Adulto'
    end
{%- endmacro %}


{# Lista canonica (nome, coluna_inicio, coluna_fim, aplicabilidade) dos 7
   indicadores de tempo. Usada pelo mart e pelos modelos de analytics para nao
   repetir a definicao. `aplic` in ('TODOS','IMAGEM','INTERNACAO'). #}
{% macro indicadores_tempo() %}
    {{ return([
        ('tempo_entrada_triagem',                'dt_retirada_senha',    'dt_inicio_triagem',    'TODOS'),
        ('tempo_triagem',                        'dt_inicio_triagem',    'dt_fim_triagem',       'TODOS'),
        ('tempo_triagem_consulta',               'dt_fim_triagem',       'dt_inicio_consulta',   'TODOS'),
        ('tempo_consulta',                       'dt_abertura_evolucao', 'dt_prescricao',        'TODOS'),
        ('tempo_solicitacao_realizacao_imagem',  'dt_solicitacao_imagem','dt_realizacao_imagem', 'IMAGEM'),
        ('tempo_reavaliacao',                    'dt_realizacao_imagem', 'dt_conduta',           'IMAGEM'),
        ('tempo_finalizacao_aih_internacao',     'dt_finalizacao_aih',   'dt_internacao_efetiva','INTERNACAO')
    ]) }}
{% endmacro %}
