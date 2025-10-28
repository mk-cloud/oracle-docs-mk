-- =====================================================
-- Package Specification: XXGL_DAILY_RATES_API_PKG
-- Purpose: Daily exchange rate API integration with Central Bank of Chile
-- Author: Integration Team
-- Date: October 2025
-- =====================================================

CREATE OR REPLACE PACKAGE xxgl_daily_rates_api_pkg AS

    /*******************************************************
     * RECORD TYPES
     *******************************************************/
    
    -- API Response record type for structured response handling
    TYPE api_response_rec IS RECORD (
        status_code         NUMBER,
        status_message      VARCHAR2(500),
        response_payload    CLOB,
        duration_ms         NUMBER,
        error_message       VARCHAR2(4000)
    );

    /*******************************************************
     * MAIN PROCEDURES
     *******************************************************/
    
    /**
     * Main procedure to fetch daily exchange rates
     * Calls Central Bank API for USD and UF rates
     * Inserts into custom interface and GL_DAILY_RATES_INTERFACE
     * 
     * @param p_conversion_date Date for which to fetch rates (default: today)
     * @param p_retcode Return code: 0=Success, 1=Warning, 2=Error
     * @param p_errbuf Error buffer with message
     */
    PROCEDURE fetch_daily_rates (
        p_conversion_date   IN  DATE DEFAULT TRUNC(SYSDATE),
        p_retcode          OUT VARCHAR2,
        p_errbuf           OUT VARCHAR2
    );
    
    /**
     * Fetch USD to CLP exchange rate from Central Bank API
     * 
     * @param p_conversion_date Date for the exchange rate
     * @param x_conversion_rate Retrieved conversion rate
     * @param x_interface_id Generated interface record ID
     * @param x_status Status: S=Success, E=Error
     * @param x_message Status message
     */
    PROCEDURE fetch_usd_clp_rate (
        p_conversion_date   IN  DATE,
        x_conversion_rate   OUT NUMBER,
        x_interface_id      OUT NUMBER,
        x_status           OUT VARCHAR2,
        x_message          OUT VARCHAR2
    );
    
    /**
     * Fetch UF to CLP exchange rate from Central Bank API
     * 
     * @param p_conversion_date Date for the exchange rate
     * @param x_conversion_rate Retrieved conversion rate
     * @param x_interface_id Generated interface record ID
     * @param x_status Status: S=Success, E=Error
     * @param x_message Status message
     */
    PROCEDURE fetch_uf_clp_rate (
        p_conversion_date   IN  DATE,
        x_conversion_rate   OUT NUMBER,
        x_interface_id      OUT NUMBER,
        x_status           OUT VARCHAR2,
        x_message          OUT VARCHAR2
    );

    /*******************************************************
     * UTILITY PROCEDURES
     *******************************************************/
    
    /**
     * Call REST API with full logging
     * Handles HTTP request/response and tracks performance
     * 
     * @param p_url API endpoint URL
     * @param p_method HTTP method (GET, POST, etc.)
     * @param p_body Request body (for POST/PUT)
     * @param x_response_details Structured response details
     * @return Response payload as CLOB
     */
    FUNCTION call_rest_api_with_logging (
        p_url              IN VARCHAR2,
        p_method           IN VARCHAR2 DEFAULT 'GET',
        p_body             IN CLOB DEFAULT NULL,
        x_response_details OUT api_response_rec
    ) RETURN CLOB;
    
    /**
     * Parse JSON response from Central Bank API
     * Extracts conversion rate and metadata
     * 
     * @param p_json_response JSON response from API
     * @param x_conversion_rate Extracted conversion rate
     * @param x_series_id Central Bank series ID
     * @param x_key_family_id Central Bank key family ID
     * @param x_status Parse status: S=Success, E=Error
     * @param x_message Parse message
     */
    PROCEDURE parse_rate_response (
        p_json_response    IN  CLOB,
        x_conversion_rate  OUT NUMBER,
        x_series_id        OUT VARCHAR2,
        x_key_family_id    OUT VARCHAR2,
        x_status           OUT VARCHAR2,
        x_message          OUT VARCHAR2
    );
    
    /**
     * Insert rate into custom interface table and GL_DAILY_RATES_INTERFACE
     * Logs full API request/response details
     * Handles duplicate records (updates on retry)
     * 
     * @param p_from_currency Source currency code
     * @param p_to_currency Target currency code
     * @param p_conversion_date Conversion date
     * @param p_conversion_rate Exchange rate
     * @param p_series_id Central Bank series ID
     * @param p_key_family_id Central Bank key family ID
     * @param p_api_endpoint API URL
     * @param p_api_method HTTP method
     * @param p_request_payload Request JSON
     * @param p_request_timestamp Request timestamp
     * @param p_response_payload Response JSON
     * @param p_response_timestamp Response timestamp
     * @param p_response_status_code HTTP status code
     * @param p_response_status_message HTTP status message
     * @param p_api_duration_ms API call duration in milliseconds
     * @param p_process_status Processing status (API_SUCCESS, API_ERROR)
     * @param p_error_message Error message if applicable
     * @param x_interface_id Generated interface record ID
     * @param x_status Operation status
     * @param x_message Operation message
     */
    PROCEDURE insert_into_interface_with_log (
        p_from_currency     IN VARCHAR2,
        p_to_currency       IN VARCHAR2,
        p_conversion_date   IN DATE,
        p_conversion_rate   IN NUMBER,
        p_series_id         IN VARCHAR2,
        p_key_family_id     IN VARCHAR2,
        p_api_endpoint      IN VARCHAR2,
        p_api_method        IN VARCHAR2,
        p_request_payload   IN CLOB,
        p_request_timestamp IN TIMESTAMP,
        p_response_payload  IN CLOB,
        p_response_timestamp IN TIMESTAMP,
        p_response_status_code IN NUMBER,
        p_response_status_message IN VARCHAR2,
        p_api_duration_ms   IN NUMBER,
        p_process_status    IN VARCHAR2,
        p_error_message     IN VARCHAR2 DEFAULT NULL,
        x_interface_id      OUT NUMBER,
        x_status            OUT VARCHAR2,
        x_message           OUT VARCHAR2
    );
    
    /**
     * Update GL load status in custom interface table
     * Called after GLDRICCP program execution
     * 
     * @param p_interface_id Interface record ID
     * @param p_request_id GLDRICCP concurrent request ID
     * @param p_gl_status GL load status
     * @param p_error_message Error message if applicable
     */
    PROCEDURE update_gl_load_status (
        p_interface_id      IN NUMBER,
        p_request_id        IN NUMBER,
        p_gl_status         IN VARCHAR2,
        p_error_message     IN VARCHAR2 DEFAULT NULL
    );
    
    /**
     * Submit GLDRICCP concurrent program
     * Imports rates from GL_DAILY_RATES_INTERFACE to GL_DAILY_RATES
     * 
     * @param p_conversion_date Date for the rates
     * @param x_request_id Concurrent request ID
     * @param x_status Submission status
     * @param x_message Submission message
     */
    PROCEDURE submit_gldriccp_program (
        p_conversion_date   IN  DATE,
        x_request_id        OUT NUMBER,
        x_status            OUT VARCHAR2,
        x_message           OUT VARCHAR2
    );

    /*******************************************************
     * REPORTING PROCEDURES
     *******************************************************/
    
    /**
     * Retrieve and display interface records for a date
     * Outputs to concurrent program output file
     * 
     * @param p_conversion_date Date to query
     * @param p_process_status Filter by status (optional)
     */
    PROCEDURE get_interface_records (
        p_conversion_date   IN  DATE,
        p_process_status    IN  VARCHAR2 DEFAULT NULL
    );

END xxgl_daily_rates_api_pkg;
/

SHOW ERRORS PACKAGE xxgl_daily_rates_api_pkg;

PROMPT
PROMPT =====================================================
PROMPT Package Specification created successfully
PROMPT =====================================================
PROMPT
PROMPT Next step: Run 03_package_body_updated.sql
PROMPT =====================================================
