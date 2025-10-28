-- =====================================================
-- Script: 01_create_interface_table.sql
-- Purpose: Create custom interface table for daily exchange rates
-- Author: Integration Team
-- Date: October 2025
-- =====================================================

-- =====================================================
-- Drop existing objects (if needed for re-installation)
-- =====================================================
-- DROP TABLE xxgl_daily_rates_int CASCADE CONSTRAINTS;
-- DROP SEQUENCE xxgl_daily_rates_int_s;

-- =====================================================
-- Create Sequence
-- =====================================================
CREATE SEQUENCE xxgl_daily_rates_int_s
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- =====================================================
-- Create Interface Table
-- =====================================================
CREATE TABLE xxgl_daily_rates_int (
    -- Primary Key
    interface_id                NUMBER NOT NULL,
    
    -- Exchange Rate Details
    from_currency               VARCHAR2(15) NOT NULL,
    to_currency                 VARCHAR2(15) NOT NULL,
    conversion_date             DATE NOT NULL,
    conversion_type             VARCHAR2(30) DEFAULT 'Spot',
    conversion_rate             NUMBER,
    inverse_conversion_rate     NUMBER,
    
    -- Source Information
    source_system               VARCHAR2(50) DEFAULT 'CENTRAL_BANK_CHILE',
    series_id                   VARCHAR2(50),
    key_family_id               VARCHAR2(50),
    
    -- API Call Details
    api_endpoint                VARCHAR2(500),
    api_method                  VARCHAR2(10),
    request_payload             CLOB,
    request_timestamp           TIMESTAMP(6),
    response_payload            CLOB,
    response_timestamp          TIMESTAMP(6),
    response_status_code        NUMBER,
    response_status_message     VARCHAR2(500),
    api_call_duration_ms        NUMBER,
    
    -- Processing Status
    retry_count                 NUMBER DEFAULT 0,
    process_status              VARCHAR2(30),
    error_code                  VARCHAR2(50),
    error_message               VARCHAR2(4000),
    error_stack                 VARCHAR2(4000),
    processed_date              DATE,
    
    -- GL Integration Status
    gl_load_request_id          NUMBER,
    gl_load_status              VARCHAR2(30),
    gl_load_date                DATE,
    
    -- Audit Columns
    creation_date               DATE NOT NULL,
    created_by                  NUMBER NOT NULL,
    last_update_date            DATE NOT NULL,
    last_updated_by             NUMBER NOT NULL,
    last_update_login           NUMBER,
    
    -- Constraints
    CONSTRAINT xxgl_daily_rates_int_pk 
        PRIMARY KEY (interface_id),
    CONSTRAINT xxgl_daily_rates_int_uk 
        UNIQUE (from_currency, to_currency, conversion_date)
);

-- =====================================================
-- Create Indexes for Performance
-- =====================================================

-- Index on conversion date (most common query filter)
CREATE INDEX xxgl_daily_rates_int_n1 
ON xxgl_daily_rates_int(conversion_date);

-- Index on process status (for monitoring)
CREATE INDEX xxgl_daily_rates_int_n2 
ON xxgl_daily_rates_int(process_status);

-- Index on currency pair and date (for lookups)
CREATE INDEX xxgl_daily_rates_int_n3 
ON xxgl_daily_rates_int(from_currency, to_currency, conversion_date);

-- Index on GL load status (for GL integration queries)
CREATE INDEX xxgl_daily_rates_int_n4 
ON xxgl_daily_rates_int(gl_load_status, gl_load_date);

-- =====================================================
-- Add Table Comments
-- =====================================================
COMMENT ON TABLE xxgl_daily_rates_int IS 
'Custom interface table for daily exchange rates from Central Bank of Chile API. Stores full request/response details and feeds GL_DAILY_RATES_INTERFACE.';

COMMENT ON COLUMN xxgl_daily_rates_int.interface_id IS 
'Primary key, generated from xxgl_daily_rates_int_s sequence';

COMMENT ON COLUMN xxgl_daily_rates_int.conversion_rate IS 
'Exchange rate: 1 unit of from_currency = X units of to_currency';

COMMENT ON COLUMN xxgl_daily_rates_int.inverse_conversion_rate IS 
'Inverse rate: 1 / conversion_rate';

COMMENT ON COLUMN xxgl_daily_rates_int.series_id IS 
'Central Bank series identifier (e.g., F073.TCO.PRE.Z.D for USD)';

COMMENT ON COLUMN xxgl_daily_rates_int.api_call_duration_ms IS 
'API call duration in milliseconds';

COMMENT ON COLUMN xxgl_daily_rates_int.process_status IS 
'Values: API_SUCCESS, API_ERROR, PENDING, PROCESSED';

COMMENT ON COLUMN xxgl_daily_rates_int.gl_load_status IS 
'Status of GL_DAILY_RATES import via GLDRICCP program';

COMMENT ON COLUMN xxgl_daily_rates_int.gl_load_request_id IS 
'Concurrent request ID of GLDRICCP program that imported this rate';

-- =====================================================
-- Grant Permissions (adjust as needed)
-- =====================================================
-- GRANT SELECT, INSERT, UPDATE, DELETE ON xxgl_daily_rates_int TO apps;
-- GRANT SELECT ON xxgl_daily_rates_int_s TO apps;

-- =====================================================
-- Verification Query
-- =====================================================
SELECT 
    'Table created successfully' AS status,
    COUNT(*) AS row_count
FROM xxgl_daily_rates_int;

-- Show table structure
DESC xxgl_daily_rates_int;

-- Show indexes
SELECT 
    index_name,
    column_name,
    column_position
FROM user_ind_columns
WHERE table_name = 'XXGL_DAILY_RATES_INT'
ORDER BY index_name, column_position;

PROMPT 
PROMPT =====================================================
PROMPT Table xxgl_daily_rates_int created successfully
PROMPT Sequence xxgl_daily_rates_int_s created successfully
PROMPT Indexes created successfully
PROMPT =====================================================
PROMPT 
PROMPT Next step: Run 02_package_specification.sql
PROMPT =====================================================
