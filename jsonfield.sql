-- =============================================================================
-- Simple JSON Field Cleaner Function
-- Purpose: Single function to clean text for safe JSON usage
-- =============================================================================

CREATE OR REPLACE FUNCTION clean_json_field(p_input VARCHAR2) 
RETURN VARCHAR2 
DETERMINISTIC
IS
    l_output VARCHAR2(32767);
BEGIN
    -- Handle NULL input
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    l_output := p_input;
    
    -- Replace problematic characters in one go
    l_output := REPLACE(l_output, '\', '\\');     -- Escape backslashes first
    l_output := REPLACE(l_output, '"', '\"');     -- Escape double quotes
    l_output := REPLACE(l_output, CHR(8), '\b');  -- Backspace
    l_output := REPLACE(l_output, CHR(9), '\t');  -- Tab
    l_output := REPLACE(l_output, CHR(10), '\n'); -- Line feed
    l_output := REPLACE(l_output, CHR(12), '\f'); -- Form feed
    l_output := REPLACE(l_output, CHR(13), '\r'); -- Carriage return
    l_output := REPLACE(l_output, '/', '\/');     -- Forward slash
    
    -- Replace smart quotes and dashes
    l_output := REPLACE(l_output, '–', '-');      -- En dash
    l_output := REPLACE(l_output, '—', '-');      -- Em dash
    l_output := REPLACE(l_output, ''', '''');     -- Smart single quotes
    l_output := REPLACE(l_output, ''', '''');
    l_output := REPLACE(l_output, '"', '"');      -- Smart double quotes
    l_output := REPLACE(l_output, '"', '"');
    l_output := REPLACE(l_output, '…', '...');    -- Ellipsis
    l_output := REPLACE(l_output, CHR(160), ' '); -- Non-breaking space
    
    -- Clean up multiple spaces and trim
    l_output := REGEXP_REPLACE(l_output, ' +', ' ');
    l_output := TRIM(l_output);
    
    RETURN l_output;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Fallback: return safe characters only
        RETURN REGEXP_REPLACE(p_input, '[^A-Za-z0-9 .,\-()]', '');
END clean_json_field;
/

-- Test the function
SELECT 
    clean_json_field('Oracle Tuning Pack – Processor Perpetual Software "Update" License & Support') AS cleaned_text
FROM dual;
