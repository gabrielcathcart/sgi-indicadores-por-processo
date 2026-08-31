-- Staging do log de eventos operacionais. Tipagem + normalizacao. Mantem o
-- grao de origem (1 linha por evento por atendimento).

with fonte as (
    select * from {{ ref('urgencia_eventos_raw') }}
)

select
    evento_id,
    atendimento_id,
    lower(trim(tipo_evento))                       as tipo_evento,
    cast(dt_evento as timestamp)                   as dt_evento,
    cast(sequencia_evento as integer)              as sequencia_evento,
    lower(trim(origem_registro))                   as origem_registro,
    cast(flag_timestamp_estimado as boolean)       as flag_timestamp_estimado
from fonte
