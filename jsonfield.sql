-- =============================================================================
-- Oracle PL/SQL Function: clean_json_field
-- Purpose: Clean and escape text fields for safe JSON usage
-- =============================================================================

-- 1. BASIC JSON ESCAPE FUNCTION
-- =============================================================================
CREATE OR REPLACE FUNCTION escape_json_string(p_input VARCHAR2) 
RETURN VARCHAR2 
DETERMINISTIC
IS
    l_output VARCHAR2(32767);
BEGIN
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    l_output := p_input;
    
    -- Escape backslashes first (must be done before other escapes)
    l_output := REPLACE(l_output, '\', '\\');
    
    -- Escape double quotes
    l_output := REPLACE(l_output, '"', '\"');
    
    -- Escape control characters
    l_output := REPLACE(l_output, CHR(8), '\b');   -- Backspace
    l_output := REPLACE(l_output, CHR(9), '\t');   -- Tab
    l_output := REPLACE(l_output, CHR(10), '\n');  -- Line feed
    l_output := REPLACE(l_output, CHR(12), '\f');  -- Form feed
    l_output := REPLACE(l_output, CHR(13), '\r');  -- Carriage return
    
    -- Handle forward slash (optional but recommended)
    l_output := REPLACE(l_output, '/', '\/');
    
    RETURN l_output;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return safe fallback
        RETURN REGEXP_REPLACE(p_input, '[^A-Za-z0-9 ]', '');
END escape_json_string;
/

-- 2. MAIN CLEAN JSON FIELD FUNCTION
-- =============================================================================
CREATE OR REPLACE FUNCTION clean_json_field(
    p_input VARCHAR2,
    p_remove_special_chars VARCHAR2 DEFAULT 'Y'
) RETURN VARCHAR2 
DETERMINISTIC
IS
    l_output VARCHAR2(32767);
BEGIN
    -- Handle NULL input
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    l_output := p_input;
    
    -- Remove or replace problematic characters
    IF NVL(p_remove_special_chars, 'Y') = 'Y' THEN
        
        -- Remove non-printable control characters
        l_output := REGEXP_REPLACE(l_output, '[[:cntrl:]]', ' ');
        
        -- Replace smart quotes and dashes with regular ones
        l_output := REPLACE(l_output, '–', '-');  -- En dash to hyphen
        l_output := REPLACE(l_output, '—', '-');  -- Em dash to hyphen
        l_output := REPLACE(l_output, ''', ''''); -- Left single quote
        l_output := REPLACE(l_output, ''', ''''); -- Right single quote
        l_output := REPLACE(l_output, '"', '"');  -- Left double quote
        l_output := REPLACE(l_output, '"', '"');  -- Right double quote
        l_output := REPLACE(l_output, '…', '...');-- Ellipsis
        
        -- Replace other problematic Unicode characters
        l_output := REPLACE(l_output, '®', '(R)'); -- Registered trademark
        l_output := REPLACE(l_output, '™', '(TM)');-- Trademark
        l_output := REPLACE(l_output, '©', '(C)'); -- Copyright
        l_output := REPLACE(l_output, '°', ' deg');-- Degree symbol
        
        -- Handle various space characters
        l_output := REPLACE(l_output, CHR(160), ' '); -- Non-breaking space
        l_output := REPLACE(l_output, CHR(194)||CHR(160), ' '); -- UTF-8 NBSP
        
        -- Replace multiple spaces with single space
        l_output := REGEXP_REPLACE(l_output, ' {2,}', ' ');
        
        -- Remove leading and trailing spaces
        l_output := TRIM(l_output);
        
        -- Handle empty strings
        IF LENGTH(TRIM(l_output)) = 0 THEN
            RETURN NULL;
        END IF;
    END IF;
    
    -- Apply JSON escaping
    l_output := escape_json_string(l_output);
    
    RETURN l_output;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Fallback: return only alphanumeric and basic punctuation
        RETURN REGEXP_REPLACE(NVL(p_input, ''), '[^A-Za-z0-9 .,\-()]', '');
END clean_json_field;
/

-- 3. ENHANCED VERSION WITH MORE OPTIONS
-- =============================================================================
CREATE OR REPLACE FUNCTION clean_json_field_enhanced(
    p_input VARCHAR2,
    p_max_length NUMBER DEFAULT 4000,
    p_remove_special_chars VARCHAR2 DEFAULT 'Y',
    p_preserve_line_breaks VARCHAR2 DEFAULT 'N'
) RETURN VARCHAR2 
DETERMINISTIC
IS
    l_output VARCHAR2(32767);
    l_max_len NUMBER := LEAST(NVL(p_max_length, 4000), 32767);
BEGIN
    -- Handle NULL input
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    l_output := p_input;
    
    -- Truncate if too long
    IF LENGTH(l_output) > l_max_len THEN
        l_output := SUBSTR(l_output, 1, l_max_len - 3) || '...';
    END IF;
    
    -- Clean special characters
    IF NVL(p_remove_special_chars, 'Y') = 'Y' THEN
        
        -- Handle line breaks
        IF NVL(p_preserve_line_breaks, 'N') = 'Y' THEN
            -- Keep line breaks as \n
            l_output := REPLACE(l_output, CHR(13)||CHR(10), '\n');
            l_output := REPLACE(l_output, CHR(10), '\n');
            l_output := REPLACE(l_output, CHR(13), '\n');
        ELSE
            -- Replace line breaks with spaces
            l_output := REPLACE(l_output, CHR(13)||CHR(10), ' ');
            l_output := REPLACE(l_output, CHR(10), ' ');
            l_output := REPLACE(l_output, CHR(13), ' ');
        END IF;
        
        -- Remove other control characters
        l_output := REGEXP_REPLACE(l_output, '[[:cntrl:]]', ' ');
        
        -- Replace problematic Unicode characters
        l_output := REPLACE(l_output, '–', '-');   -- En dash
        l_output := REPLACE(l_output, '—', '-');   -- Em dash
        l_output := REPLACE(l_output, ''', '''');  -- Smart quotes
        l_output := REPLACE(l_output, ''', '''');
        l_output := REPLACE(l_output, '"', '"');
        l_output := REPLACE(l_output, '"', '"');
        l_output := REPLACE(l_output, '…', '...');
        l_output := REPLACE(l_output, '®', '(R)');
        l_output := REPLACE(l_output, '™', '(TM)');
        l_output := REPLACE(l_output, '©', '(C)');
        l_output := REPLACE(l_output, '°', ' deg');
        l_output := REPLACE(l_output, '±', '+/-');
        l_output := REPLACE(l_output, '×', 'x');
        l_output := REPLACE(l_output, '÷', '/');
        
        -- Handle various space characters
        l_output := REPLACE(l_output, CHR(160), ' '); -- Non-breaking space
        l_output := REPLACE(l_output, CHR(194)||CHR(160), ' '); -- UTF-8 NBSP
        
        -- Clean up multiple spaces
        l_output := REGEXP_REPLACE(l_output, ' {2,}', ' ');
        l_output := TRIM(l_output);
    END IF;
    
    -- Apply JSON escaping
    l_output := escape_json_string(l_output);
    
    RETURN l_output;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Emergency fallback
        RETURN REGEXP_REPLACE(SUBSTR(NVL(p_input, ''), 1, 100), '[^A-Za-z0-9 ]', '');
END clean_json_field_enhanced;
/

-- 4. VALIDATION FUNCTION
-- =============================================================================
CREATE OR REPLACE FUNCTION validate_json_string(p_json_string VARCHAR2)
RETURN VARCHAR2
DETERMINISTIC
IS
    l_test_json VARCHAR2(32767);
BEGIN
    -- Create a simple JSON object to test the string
    l_test_json := '{"test":"' || p_json_string || '"}';
    
    -- Try to validate using Oracle's JSON functions (12c+)
    BEGIN
        IF JSON_VALID(l_test_json) = 1 THEN
            RETURN 'VALID';
        ELSE
            RETURN 'INVALID';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR: ' || SUBSTR(SQLERRM, 1, 100);
    END;
END validate_json_string;
/

-- 5. UTILITY FUNCTION FOR MASS CLEANING
-- =============================================================================
CREATE OR REPLACE FUNCTION clean_all_text_fields(
    p_field1 VARCHAR2 DEFAULT NULL,
    p_field2 VARCHAR2 DEFAULT NULL,
    p_field3 VARCHAR2 DEFAULT NULL,
    p_field4 VARCHAR2 DEFAULT NULL,
    p_field5 VARCHAR2 DEFAULT NULL,
    p_separator VARCHAR2 DEFAULT '|'
) RETURN VARCHAR2
DETERMINISTIC
IS
    l_result VARCHAR2(32767);
BEGIN
    l_result := clean_json_field(p_field1);
    
    IF p_field2 IS NOT NULL THEN
        l_result := l_result || p_separator || clean_json_field(p_field2);
    END IF;
    
    IF p_field3 IS NOT NULL THEN
        l_result := l_result || p_separator || clean_json_field(p_field3);
    END IF;
    
    IF p_field4 IS NOT NULL THEN
        l_result := l_result || p_separator || clean_json_field(p_field4);
    END IF;
    
    IF p_field5 IS NOT NULL THEN
        l_result := l_result || p_separator || clean_json_field(p_field5);
    END IF;
    
    RETURN l_result;
END clean_all_text_fields;
/

-- 6. GRANTS (Execute as needed)
-- =============================================================================
-- GRANT EXECUTE ON clean_json_field TO PUBLIC;
-- GRANT EXECUTE ON escape_json_string TO PUBLIC;
-- GRANT EXECUTE ON clean_json_field_enhanced TO PUBLIC;

-- 7. TEST CASES
-- =============================================================================

-- Test with your problematic data
SELECT 
    'Original: ' || 'Oracle Tuning Pack – Processor Perpetual Software Update License & Support' AS original,
    'Cleaned: ' || clean_json_field('Oracle Tuning Pack – Processor Perpetual Software Update License & Support') AS cleaned,
    'Valid: ' || validate_json_string(clean_json_field('Oracle Tuning Pack – Processor Perpetual Software Update License & Support')) AS is_valid
FROM dual
UNION ALL
SELECT 
    'Original: ' || 'Abend-AID with Primary Language=COBOL' AS original,
    'Cleaned: ' || clean_json_field('Abend-AID with Primary Language=COBOL') AS cleaned,
    'Valid: ' || validate_json_string(clean_json_field('Abend-AID with Primary Language=COBOL')) AS is_valid
FROM dual
UNION ALL
SELECT 
    'Original: ' || 'Test "quotes" and' || CHR(10) || 'line breaks' AS original,
    'Cleaned: ' || clean_json_field('Test "quotes" and' || CHR(10) || 'line breaks') AS cleaned,
    'Valid: ' || validate_json_string(clean_json_field('Test "quotes" and' || CHR(10) || 'line breaks')) AS is_valid
FROM dual;

-- Performance test
SELECT 
    clean_json_field('Test string with special chars: "quotes", –dashes–, and ™symbols®') AS result
FROM dual;

-- Test JSON generation
SELECT JSON_OBJECT(
    'productDescription' VALUE clean_json_field('Oracle Tuning Pack – Processor Perpetual Software'),
    'additionalInfo' VALUE clean_json_field('Abend-AID with Primary Language=COBOL'),
    RETURNING CLOB
) AS test_json
FROM dual;
