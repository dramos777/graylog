-- Define a função Process que será chamada pelo Fluent Bit
function Process(tag, timestamp, record)
    -- Garante que cada registro tenha a chave 'short_message'
    if record['short_message'] == nil then
        record['short_message'] = record['log'] or "No log message available"
    end
    
    -- Retorna 0 para indicar que o registro deve ser processado
    return 0, timestamp, record
end
