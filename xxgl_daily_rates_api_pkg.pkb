-- =====================================================
-- Package Body: XXGL_DAILY_RATES_API_PKG (UPDATED)
-- Purpose: Implementation with GL_DAILY_RATES_INTERFACE insert
-- Author: Integration Team
-- Date: October 2025
-- Change: Added insert to GL_DAILY_RATES_INTERFACE after custom table
-- =====================================================

CREATE OR REPLACE PACKAGE BODY xxgl_daily_rates_api_pkg AS

    /*******************************************************
     * Global Constants
     *******************************************************/
    
    -- API Configuration
    g_base_url      CONSTANT VARCHAR2(200) := 'https://dev-eds-mdm.npe.us.equifax.com/api/eds/mdm/v1/chile-exchange/currency';
    g_api_key       CONSTANT VARCHAR2(100) := 'DWZleTuE9PVWmZePzSGSap9QSuJqUAR';
    
    -- Central Bank Series IDs
    g_usd_series    CONSTANT VARCHAR2(50)  := 'F073.TCO.PRE.Z.D';
    g_uf_series     CONSTANT VARCHAR2(50)  := 'F073.UFF.PRE.Z.D';
    
    -- Status Codes
    g_status_success CONSTANT VARCHAR2(1) := 'S';
    g_status_error   CONSTANT VARCHAR2(1) := 'E';
    
    /*******************************************************
     * Main Procedure: fetch_daily_rates
     *******************************************************/
    
    PROCEDURE fetch_daily_rates (
        p_conversion_date   IN  DATE DEFAULT TRUNC(SYSDATE),
        p_retcode          OUT VARCHAR2,
        p_errbuf           OUT VARCHAR2
    ) IS
        l_usd_rate         NUMBER;
        l_uf_rate          NUMBER;
        l_status           VARCHAR2(1);
        l_message          VARCHAR2(4000);
        l_interface_id_usd NUMBER;
        l_interface_id_uf  NUMBER;
        l_success_count    NUMBER := 0;
        l_error_count      NUMBER := 0;
        
    BEGIN
        fnd_file.put_line(fnd_file.log, RPAD('=', 80, '='));
        fnd_file.put_line(fnd_file.log, 'Daily Exchange Rate Load Process');
        fnd_file.put_line(fnd_file.log, 'Conversion Date: ' || TO_CHAR(p_conversion_date, 'DD-MON-YYYY'));
        fnd_file.put_line(fnd_file.log, 'Start Time: ' || TO_CHAR(SYSTIMESTAMP, 'DD-MON-YYYY HH24:MI:SS.FF3'));
        fnd_file.put_line(fnd_file.log, RPAD('=', 80, '='));
        
        fnd_file.put_line(fnd_file.log, '');
        fnd_file.put_line(fnd_file.log, 'Step 1: Fetching USD to CLP rate from Central Bank...');
        
        fetch_usd_clp_rate(
            p_conversion_date => p_conversion_date,
            x_conversion_rate => l_usd_rate,
            x_interface_id    => l_interface_id_usd,
            x_status          => l_status,
            x_message         => l_message
        );
        
        IF l_status = g_status_success THEN
            fnd_file.put_line(fnd_file.log, '  SUCCESS: 1 USD = ' || TO_CHAR(l_usd_rate, '999,999.99') || ' CLP');
            fnd_file.put_line(fnd_file.log, '  Interface Record ID: ' || l_interface_id_usd);
            l_success_count := l_success_count + 1;
        ELSE
            fnd_file.put_line(fnd_file.log, '  ERROR: ' || l_message);
            IF l_interface_id_usd IS NOT NULL THEN
                fnd_file.put_line(fnd_file.log, '  Interface Record ID: ' || l_interface_id_usd || ' (logged with error)');
            END IF;
            l_error_count := l_error_count + 1;
        END IF;
        
        fnd_file.put_line(fnd_file.log, '');
        fnd_file.put_line(fnd_file.log, 'Step 2: Fetching UF to CLP rate from Central Bank...');
        
        fetch_uf_clp_rate(
            p_conversion_date => p_conversion_date,
            x_conversion_rate => l_uf_rate,
            x_interface_id    => l_interface_id_uf,
            x_status          => l_status,
            x_message         => l_message
        );
        
        IF l_status = g_status_success THEN
            fnd_file.put_line(fnd_file.log, '  SUCCESS: 1 UF = ' || TO_CHAR(l_uf_rate, '999,999.99') || ' CLP');
            fnd_file.put_line(fnd_file.log, '  Interface Record ID: ' || l_interface_id_uf);
            l_success_count := l_success_count + 1;
        ELSE
            fnd_file.put_line(fnd_file.log, '  ERROR: ' || l_message);
            IF l_interface_id_uf IS NOT NULL THEN
                fnd_file.put_line(fnd_file.log, '  Interface Record ID: ' || l_interface_id_uf || ' (logged with error)');
            END IF;
            l_error_count := l_error_count + 1;
        END IF;
        
        -- NOTE: GLDRICCP submission removed - data is now in GL_DAILY_RATES_INTERFACE
        -- User can manually submit GLDRICCP or schedule it separately
        
        fnd_file.put_line(fnd_file.log, '');
        fnd_file.put_line(fnd_file.log, RPAD('=', 80, '='));
        fnd_file.put_line(fnd_file.log, 'Process Summary:');
        fnd_file.put_line(fnd_file.log, RPAD('-', 80, '-'));
        fnd_file.put_line(fnd_file.log, '  Total Currencies Attempted: 2 (USD, UF)');
        fnd_file.put_line(fnd_file.log, '  Successful API Calls: ' || l_success_count);
        fnd_file.put_line(fnd_file.log, '  Failed API Calls: ' || l_error_count);
        fnd_file.put_line(fnd_file.log, '  Records in GL_DAILY_RATES_INTERFACE: ' || l_success_count);
        fnd_file.put_line(fnd_file.log, '  End Time: ' || TO_CHAR(SYSTIMESTAMP, 'DD-MON-YYYY HH24:MI:SS.FF3'));
        fnd_file.put_line(fnd_file.log, RPAD('=', 80, '='));
        fnd_file.put_line(fnd_file.log, '');
        fnd_file.put_line(fnd_file.log, 'NOTE: Please submit GLDRICCP program to import rates to GL_DAILY_RATES');
        
        IF l_error_count = 0 THEN
            p_retcode := '0';
            p_errbuf := 'Daily exchange rates loaded successfully. Rates: ' || l_success_count;
        ELSIF l_success_count > 0 THEN
            p_retcode := '1';
            p_errbuf := 'Completed with warnings. Success: ' || l_success_count || ', Errors: ' || l_error_count;
        ELSE
            p_retcode := '2';
            p_errbuf := 'Failed to load exchange rates. All ' || l_error_count || ' attempts failed.';
        END IF;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_retcode := '2';
            p_errbuf := 'FATAL ERROR: ' || SQLERRM;
            fnd_file.put_line(fnd_file.log, '');
            fnd_file.put_line(fnd_file.log, RPAD('!', 80, '!'));
            fnd_file.put_line(fnd_file.log, 'FATAL ERROR: ' || SQLERRM);
            fnd_file.put_line(fnd_file.log, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            fnd_file.put_line(fnd_file.log, RPAD('!', 80, '!'));
    END fetch_daily_rates;
    
    /*******************************************************
     * Procedure: fetch_usd_clp_rate
     *******************************************************/
    
    PROCEDURE fetch_usd_clp_rate (
        p_conversion_date   IN  DATE,
        x_conversion_rate   OUT NUMBER,
        x_interface_id      OUT NUMBER,
        x_status           OUT VARCHAR2,
        x_message          OUT VARCHAR2
    ) IS
        l_json_body          CLOB;
        l_json_response      CLOB;
        l_series_id          VARCHAR2(50);
        l_key_family_id      VARCHAR2(50);
        l_format_date        VARCHAR2(10);
        l_request_timestamp  TIMESTAMP;
        l_response_timestamp TIMESTAMP;
        l_response_details   api_response_rec;
        l_process_status     VARCHAR2(30);
        l_error_message      VARCHAR2(4000);
        l_parse_status       VARCHAR2(1);
        l_parse_message      VARCHAR2(4000);
        
    BEGIN
        l_format_date := TO_CHAR(p_conversion_date, 'YYYY-MM-DD');
        
        l_json_body := '{
            "Data": {
                "firstDate": "' || l_format_date || '",
                "lastDate": "' || l_format_date || '",
                "seriesIds": "' || g_usd_series || '"
            }
        }';
        
        l_request_timestamp := SYSTIMESTAMP;
        
        BEGIN
            fnd_file.put_line(fnd_file.log, '  Calling API: ' || g_base_url);
            fnd_file.put_line(fnd_file.log, '  Series ID: ' || g_usd_series);
            
            l_json_response := call_rest_api_with_logging(
                p_url              => g_base_url,
                p_method           => 'POST',
                p_body             => l_json_body,
                x_response_details => l_response_details
            );
            
            l_response_timestamp := SYSTIMESTAMP;
            
            fnd_file.put_line(fnd_file.log, '  API Response Code: ' || l_response_details.status_code);
            fnd_file.put_line(fnd_file.log, '  API Duration: ' || ROUND(l_response_details.duration_ms, 2) || ' ms');
            
            IF l_response_details.status_code = 200 THEN
                parse_rate_response(
                    p_json_response   => l_json_response,
                    x_conversion_rate => x_conversion_rate,
                    x_series_id       => l_series_id,
                    x_key_family_id   => l_key_family_id,
                    x_status          => l_parse_status,
                    x_message         => l_parse_message
                );
                
                IF l_parse_status = g_status_success THEN
                    l_process_status := 'API_SUCCESS';
                    l_error_message := NULL;
                    x_status := g_status_success;
                    x_message := 'USD-CLP rate fetched successfully';
                ELSE
                    l_process_status := 'API_ERROR';
                    l_error_message := 'Parse error: ' || l_parse_message;
                    x_status := g_status_error;
                    x_message := l_error_message;
                END IF;
            ELSE
                l_process_status := 'API_ERROR';
                l_error_message := 'HTTP ' || l_response_details.status_code || ': ' || l_response_details.status_message;
                x_status := g_status_error;
                x_message := l_error_message;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                l_response_timestamp := SYSTIMESTAMP;
                l_response_details.error_message := SQLERRM;
                l_response_details.status_code := 0;
                l_response_details.status_message := 'EXCEPTION';
                l_response_details.duration_ms := EXTRACT(SECOND FROM (l_response_timestamp - l_request_timestamp)) * 1000;
                l_process_status := 'API_ERROR';
                l_error_message := 'API call exception: ' || SQLERRM;
                x_status := g_status_error;
                x_message := l_error_message;
                
                fnd_file.put_line(fnd_file.log, '  Exception during API call: ' || SQLERRM);
        END;
        
        insert_into_interface_with_log(
            p_from_currency        => 'USD',
            p_to_currency          => 'CLP',
            p_conversion_date      => p_conversion_date,
            p_conversion_rate      => x_conversion_rate,
            p_series_id            => l_series_id,
            p_key_family_id        => l_key_family_id,
            p_api_endpoint         => g_base_url,
            p_api_method           => 'POST',
            p_request_payload      => l_json_body,
            p_request_timestamp    => l_request_timestamp,
            p_response_payload     => l_response_details.response_payload,
            p_response_timestamp   => l_response_timestamp,
            p_response_status_code => l_response_details.status_code,
            p_response_status_message => l_response_details.status_message,
            p_api_duration_ms      => l_response_details.duration_ms,
            p_process_status       => l_process_status,
            p_error_message        => l_error_message,
            x_interface_id         => x_interface_id,
            x_status               => x_status,
            x_message              => x_message
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            x_status := g_status_error;
            x_message := 'Unexpected error in fetch_usd_clp_rate: ' || SQLERRM;
            fnd_file.put_line(fnd_file.log, '  EXCEPTION: ' || SQLERRM);
    END fetch_usd_clp_rate;
    
    /*******************************************************
     * Procedure: fetch_uf_clp_rate
     *******************************************************/
    
    PROCEDURE fetch_uf_clp_rate (
        p_conversion_date   IN  DATE,
        x_conversion_rate   OUT NUMBER,
        x_interface_id      OUT NUMBER,
        x_status           OUT VARCHAR2,
        x_message          OUT VARCHAR2
    ) IS
        l_json_body          CLOB;
        l_json_response      CLOB;
        l_series_id          VARCHAR2(50);
        l_key_family_id      VARCHAR2(50);
        l_format_date        VARCHAR2(10);
        l_request_timestamp  TIMESTAMP;
        l_response_timestamp TIMESTAMP;
        l_response_details   api_response_rec;
        l_process_status     VARCHAR2(30);
        l_error_message      VARCHAR2(4000);
        l_parse_status       VARCHAR2(1);
        l_parse_message      VARCHAR2(4000);
        
    BEGIN
        l_format_date := TO_CHAR(p_conversion_date, 'YYYY-MM-DD');
        
        l_json_body := '{
            "Data": {
                "firstDate": "' || l_format_date || '",
                "lastDate": "' || l_format_date || '",
                "seriesIds": "' || g_uf_series || '"
            }
        }';
        
        l_request_timestamp := SYSTIMESTAMP;
        
        BEGIN
            fnd_file.put_line(fnd_file.log, '  Calling API: ' || g_base_url);
            fnd_file.put_line(fnd_file.log, '  Series ID: ' || g_uf_series);
            
            l_json_response := call_rest_api_with_logging(
                p_url              => g_base_url,
                p_method           => 'POST',
                p_body             => l_json_body,
                x_response_details => l_response_details
            );
            
            l_response_timestamp := SYSTIMESTAMP;
            
            fnd_file.put_line(fnd_file.log, '  API Response Code: ' || l_response_details.status_code);
            fnd_file.put_line(fnd_file.log, '  API Duration: ' || ROUND(l_response_details.duration_ms, 2) || ' ms');
            
            IF l_response_details.status_code = 200 THEN
                parse_rate_response(
                    p_json_response   => l_json_response,
                    x_conversion_rate => x_conversion_rate,
                    x_series_id       => l_series_id,
                    x_key_family_id   => l_key_family_id,
                    x_status          => l_parse_status,
                    x_message         => l_parse_message
                );
                
                IF l_parse_status = g_status_success THEN
                    l_process_status := 'API_SUCCESS';
                    l_error_message := NULL;
                    x_status := g_status_success;
                    x_message := 'UF-CLP rate fetched successfully';
                ELSE
                    l_process_status := 'API_ERROR';
                    l_error_message := 'Parse error: ' || l_parse_message;
                    x_status := g_status_error;
                    x_message := l_error_message;
                END IF;
            ELSE
                l_process_status := 'API_ERROR';
                l_error_message := 'HTTP ' || l_response_details.status_code || ': ' || l_response_details.status_message;
                x_status := g_status_error;
                x_message := l_error_message;
            END IF;
            
        EXCEPTION
            WHEN OTHERS THEN
                l_response_timestamp := SYSTIMESTAMP;
                l_response_details.error_message := SQLERRM;
                l_response_details.status_code := 0;
                l_response_details.status_message := 'EXCEPTION';
                l_response_details.duration_ms := EXTRACT(SECOND FROM (l_response_timestamp - l_request_timestamp)) * 1000;
                l_process_status := 'API_ERROR';
                l_error_message := 'API call exception: ' || SQLERRM;
                x_status := g_status_error;
                x_message := l_error_message;
                
                fnd_file.put_line(fnd_file.log, '  Exception during API call: ' || SQLERRM);
        END;
        
        insert_into_interface_with_log(
            p_from_currency        => 'UF',
            p_to_currency          => 'CLP',
            p_conversion_date      => p_conversion_date,
            p_conversion_rate      => x_conversion_rate,
            p_series_id            => l_series_id,
            p_key_family_id        => l_key_family_id,
            p_api_endpoint         => g_base_url,
            p_api_method           => 'POST',
            p_request_payload      => l_json_body,
            p_request_timestamp    => l_request_timestamp,
            p_response_payload     => l_response_details.response_payload,
            p_response_timestamp   => l_response_timestamp,
            p_response_status_code => l_response_details.status_code,
            p_response_status_message => l_response_details.status_message,
            p_api_duration_ms      => l_response_details.duration_ms,
            p_process_status       => l_process_status,
            p_error_message        => l_error_message,
            x_interface_id         => x_interface_id,
            x_status               => x_status,
            x_message              => x_message
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            x_status := g_status_error;
            x_message := 'Unexpected error in fetch_uf_clp_rate: ' || SQLERRM;
            fnd_file.put_line(fnd_file.log, '  EXCEPTION: ' || SQLERRM);
    END fetch_uf_clp_rate;
    
    /*******************************************************
     * Function: call_rest_api_with_logging
     *******************************************************/
    
    FUNCTION call_rest_api_with_logging (
        p_url              IN VARCHAR2,
        p_method           IN VARCHAR2 DEFAULT 'GET',
        p_body             IN CLOB DEFAULT NULL,
        x_response_details OUT api_response_rec
    ) RETURN CLOB IS
        l_http_request   UTL_HTTP.req;
        l_http_response  UTL_HTTP.resp;
        l_response_text  VARCHAR2(32767);
        l_response_clob  CLOB;
        l_start_time     TIMESTAMP;
        l_end_time       TIMESTAMP;
        
    BEGIN
        l_start_time := SYSTIMESTAMP;
        
        DBMS_LOB.createtemporary(l_response_clob, FALSE);
        DBMS_LOB.createtemporary(x_response_details.response_payload, FALSE);
        
        l_http_request := UTL_HTTP.begin_request(
            url          => p_url,
            method       => p_method,
            http_version => 'HTTP/1.1'
        );
        
        UTL_HTTP.set_header(l_http_request, 'Content-Type', 'application/json');
        UTL_HTTP.set_header(l_http_request, 'x-api-key', g_api_key);
        UTL_HTTP.set_header(l_http_request, 'efx-client-correlation-id', '123');
        
        IF p_body IS NOT NULL THEN
            UTL_HTTP.write_text(l_http_request, p_body);
        END IF;
        
        l_http_response := UTL_HTTP.get_response(l_http_request);
        
        x_response_details.status_code := l_http_response.status_code;
        x_response_details.status_message := l_http_response.reason_phrase;
        
        BEGIN
            LOOP
                UTL_HTTP.read_text(l_http_response, l_response_text, 32767);
                DBMS_LOB.writeappend(l_response_clob, LENGTH(l_response_text), l_response_text);
                DBMS_LOB.writeappend(x_response_details.response_payload, LENGTH(l_response_text), l_response_text);
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.end_of_body THEN
                NULL;
        END;
        
        UTL_HTTP.end_response(l_http_response);
        
        l_end_time := SYSTIMESTAMP;
        x_response_details.duration_ms := EXTRACT(SECOND FROM (l_end_time - l_start_time)) * 1000;
        
        IF x_response_details.status_code = 200 THEN
            x_response_details.error_message := NULL;
        ELSE
            x_response_details.error_message := 'HTTP Status: ' || x_response_details.status_code || ' - ' || x_response_details.status_message;
        END IF;
        
        RETURN l_response_clob;
        
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                IF l_http_response.status_code IS NOT NULL THEN
                    UTL_HTTP.end_response(l_http_response);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
            
            l_end_time := SYSTIMESTAMP;
            x_response_details.duration_ms := EXTRACT(SECOND FROM (l_end_time - l_start_time)) * 1000;
            x_response_details.status_code := 0;
            x_response_details.status_message := 'EXCEPTION';
            x_response_details.error_message := SQLERRM;
            
            RAISE;
    END call_rest_api_with_logging;
    
    /*******************************************************
     * Procedure: parse_rate_response
     *******************************************************/
    
    PROCEDURE parse_rate_response (
        p_json_response    IN  CLOB,
        x_conversion_rate  OUT NUMBER,
        x_series_id        OUT VARCHAR2,
        x_key_family_id    OUT VARCHAR2,
        x_status           OUT VARCHAR2,
        x_message          OUT VARCHAR2
    ) IS
        l_json_obj  JSON_OBJECT_T;
        
    BEGIN
        IF p_json_response IS NULL OR DBMS_LOB.getlength(p_json_response) = 0 THEN
            x_status := g_status_error;
            x_message := 'Empty JSON response received';
            RETURN;
        END IF;
        
        l_json_obj := JSON_OBJECT_T.parse(p_json_response);
        
        x_key_family_id := l_json_obj.get_string('keyFamilyId');
        x_series_id := l_json_obj.get_string('seriesId');
        x_conversion_rate := l_json_obj.get_number('value');
        
        IF x_conversion_rate IS NULL THEN
            x_status := g_status_error;
            x_message := 'Conversion rate is NULL in API response';
        ELSIF x_conversion_rate <= 0 THEN
            x_status := g_status_error;
            x_message := 'Invalid conversion rate: ' || x_conversion_rate || ' (must be > 0)';
        ELSE
            x_status := g_status_success;
            x_message := 'Rate parsed successfully: ' || x_conversion_rate;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            x_status := g_status_error;
            x_message := 'JSON parsing error: ' || SQLERRM;
            x_conversion_rate := NULL;
            x_series_id := NULL;
            x_key_family_id := NULL;
    END parse_rate_response;
    
    /*******************************************************
     * Procedure: insert_into_interface_with_log (UPDATED)
     * Added: Insert to GL_DAILY_RATES_INTERFACE after custom table
     *******************************************************/
    
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
    ) IS
        l_inverse_rate  NUMBER;
        l_gl_interface_inserted VARCHAR2(1) := 'N';
        
    BEGIN
        -- Get next sequence value
        SELECT xxgl_daily_rates_int_s.NEXTVAL
        INTO x_interface_id
        FROM dual;
        
        -- Calculate inverse conversion rate
        IF p_conversion_rate IS NOT NULL AND p_conversion_rate > 0 THEN
            l_inverse_rate := 1 / p_conversion_rate;
        ELSE
            l_inverse_rate := NULL;
        END IF;
        
        -- =====================================================
        -- STEP 1: Insert into custom interface table
        -- =====================================================
        INSERT INTO xxgl_daily_rates_int (
            interface_id,
            from_currency,
            to_currency,
            conversion_date,
            conversion_type,
            conversion_rate,
            inverse_conversion_rate,
            source_system,
            series_id,
            key_family_id,
            api_endpoint,
            api_method,
            request_payload,
            request_timestamp,
            response_payload,
            response_timestamp,
            response_status_code,
            response_status_message,
            api_call_duration_ms,
            retry_count,
            process_status,
            error_code,
            error_message,
            error_stack,
            processed_date,
            creation_date,
            created_by,
            last_update_date,
            last_updated_by,
            last_update_login
        ) VALUES (
            x_interface_id,
            p_from_currency,
            p_to_currency,
            TRUNC(p_conversion_date),
            'Spot',
            p_conversion_rate,
            l_inverse_rate,
            'CENTRAL_BANK_CHILE',
            p_series_id,
            p_key_family_id,
            p_api_endpoint,
            p_api_method,
            p_request_payload,
            p_request_timestamp,
            p_response_payload,
            p_response_timestamp,
            p_response_status_code,
            p_response_status_message,
            p_api_duration_ms,
            0,
            p_process_status,
            CASE WHEN p_error_message IS NOT NULL THEN 'API_ERROR' ELSE NULL END,
            p_error_message,
            CASE WHEN p_error_message IS NOT NULL THEN DBMS_UTILITY.FORMAT_ERROR_BACKTRACE ELSE NULL END,
            CASE WHEN p_process_status = 'API_SUCCESS' THEN SYSDATE ELSE NULL END,
            SYSDATE,
            NVL(fnd_global.user_id, -1),
            SYSDATE,
            NVL(fnd_global.user_id, -1),
            NVL(fnd_global.login_id, -1)
        );
        
        fnd_file.put_line(fnd_file.log, '  Custom interface record created: ID = ' || x_interface_id);
        
        -- =====================================================
        -- STEP 2: Insert into GL_DAILY_RATES_INTERFACE
        -- Only if API call was successful
        -- =====================================================
        IF p_process_status = 'API_SUCCESS' AND p_conversion_rate IS NOT NULL AND p_conversion_rate > 0 THEN
            BEGIN
                INSERT INTO gl_daily_rates_interface (
                    from_currency,
                    to_currency,
                    conversion_date,
                    conversion_type,
                    conversion_rate,
                    inverse_conversion_rate,
                    user_conversion_type,
                    status_code,
                    mode_flag,
                    creation_date,
                    created_by,
                    last_update_date,
                    last_updated_by,
                    last_update_login
                ) VALUES (
                    p_from_currency,
                    p_to_currency,
                    TRUNC(p_conversion_date),
                    'Spot',
                    p_conversion_rate,
                    l_inverse_rate,
                    'User',
                    'I',  -- I = Insert
                    'I',  -- I = Insert mode
                    SYSDATE,
                    NVL(fnd_global.user_id, -1),
                    SYSDATE,
                    NVL(fnd_global.user_id, -1),
                    NVL(fnd_global.login_id, -1)
                );
                
                l_gl_interface_inserted := 'Y';
                fnd_file.put_line(fnd_file.log, '  GL_DAILY_RATES_INTERFACE record created successfully');
                
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX THEN
                    -- Rate already exists in GL interface, update it
                    UPDATE gl_daily_rates_interface
                    SET conversion_rate = p_conversion_rate,
                        inverse_conversion_rate = l_inverse_rate,
                        status_code = 'I',
                        last_update_date = SYSDATE,
                        last_updated_by = NVL(fnd_global.user_id, -1),
                        last_update_login = NVL(fnd_global.login_id, -1)
                    WHERE from_currency = p_from_currency
                      AND to_currency = p_to_currency
                      AND conversion_date = TRUNC(p_conversion_date)
                      AND conversion_type = 'Spot';
                    
                    l_gl_interface_inserted := 'Y';
                    fnd_file.put_line(fnd_file.log, '  GL_DAILY_RATES_INTERFACE record updated (already existed)');
                    
                WHEN OTHERS THEN
                    -- Log error but don't fail the main process
                    fnd_file.put_line(fnd_file.log, '  WARNING: Failed to insert into GL_DAILY_RATES_INTERFACE: ' || SQLERRM);
                    l_gl_interface_inserted := 'N';
            END;
        ELSE
            fnd_file.put_line(fnd_file.log, '  GL_DAILY_RATES_INTERFACE insert skipped (API call failed or invalid rate)');
        END IF;
        
        x_status := g_status_success;
        x_message := 'Interface record created successfully. ID: ' || x_interface_id || 
                     ', GL Interface: ' || l_gl_interface_inserted;
        
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            -- Update existing custom interface record (retry scenario)
            UPDATE xxgl_daily_rates_int
            SET conversion_rate = p_conversion_rate,
                inverse_conversion_rate = l_inverse_rate,
                series_id = p_series_id,
                key_family_id = p_key_family_id,
                request_payload = p_request_payload,
                request_timestamp = p_request_timestamp,
                response_payload = p_response_payload,
                response_timestamp = p_response_timestamp,
                response_status_code = p_response_status_code,
                response_status_message = p_response_status_message,
                api_call_duration_ms = p_api_duration_ms,
                retry_count = retry_count + 1,
                process_status = p_process_status,
                error_code = CASE WHEN p_error_message IS NOT NULL THEN 'API_ERROR' ELSE NULL END,
                error_message = p_error_message,
                error_stack = CASE WHEN p_error_message IS NOT NULL THEN DBMS_UTILITY.FORMAT_ERROR_BACKTRACE ELSE NULL END,
                processed_date = CASE WHEN p_process_status = 'API_SUCCESS' THEN SYSDATE ELSE processed_date END,
                last_update_date = SYSDATE,
                last_updated_by = NVL(fnd_global.user_id, -1),
                last_update_login = NVL(fnd_global.login_id, -1)
            WHERE from_currency = p_from_currency
              AND to_currency = p_to_currency
              AND conversion_date = TRUNC(p_conversion_date)
            RETURNING interface_id INTO x_interface_id;
            
            fnd_file.put_line(fnd_file.log, '  Custom interface record updated (retry): ID = ' || x_interface_id);
            
            -- Also try to insert/update GL interface on retry if successful
            IF p_process_status = 'API_SUCCESS' AND p_conversion_rate IS NOT NULL AND p_conversion_rate > 0 THEN
                BEGIN
                    INSERT INTO gl_daily_rates_interface (
                        from_currency,
                        to_currency,
                        conversion_date,
                        conversion_type,
                        conversion_rate,
                        inverse_conversion_rate,
                        user_conversion_type,
                        status_code,
                        mode_flag,
                        creation_date,
                        created_by,
                        last_update_date,
                        last_updated_by,
                        last_update_login
                    ) VALUES (
                        p_from_currency,
                        p_to_currency,
                        TRUNC(p_conversion_date),
                        'Spot',
                        p_conversion_rate,
                        l_inverse_rate,
                        'User',
                        'I',
                        'I',
                        SYSDATE,
                        NVL(fnd_global.user_id, -1),
                        SYSDATE,
                        NVL(fnd_global.user_id, -1),
                        NVL(fnd_global.login_id, -1)
                    );
                    
                    fnd_file.put_line(fnd_file.log, '  GL_DAILY_RATES_INTERFACE record created on retry');
                    
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN
                        UPDATE gl_daily_rates_interface
                        SET conversion_rate = p_conversion_rate,
                            inverse_conversion_rate = l_inverse_rate,
                            status_code = 'I',
                            last_update_date = SYSDATE,
                            last_updated_by = NVL(fnd_global.user_id, -1)
                        WHERE from_currency = p_from_currency
                          AND to_currency = p_to_currency
                          AND conversion_date = TRUNC(p_conversion_date)
                          AND conversion_type = 'Spot';
                        
                        fnd_file.put_line(fnd_file.log, '  GL_DAILY_RATES_INTERFACE record updated on retry');
                        
                    WHEN OTHERS THEN
                        fnd_file.put_line(fnd_file.log, '  WARNING: Failed to insert/update GL_DAILY_RATES_INTERFACE on retry: ' || SQLERRM);
                END;
            END IF;
            
            x_status := g_status_success;
            x_message := 'Interface record updated (retry). ID: ' || x_interface_id;
            
        WHEN OTHERS THEN
            x_status := g_status_error;
            x_message := 'Error inserting/updating interface record: ' || SQLERRM;
            RAISE;
    END insert_into_interface_with_log;
    
    /*******************************************************
     * Procedure: update_gl_load_status
     *******************************************************/
    
    PROCEDURE update_gl_load_status (
        p_interface_id      IN NUMBER,
        p_request_id        IN NUMBER,
        p_gl_status         IN VARCHAR2,
        p_error_message     IN VARCHAR2 DEFAULT NULL
    ) IS
    BEGIN
        UPDATE xxgl_daily_rates_int
        SET gl_load_request_id = p_request_id,
            gl_load_status = p_gl_status,
            gl_load_date = SYSDATE,
            error_message = CASE 
                WHEN p_error_message IS NOT NULL THEN p_error_message 
                ELSE error_message 
            END,
            last_update_date = SYSDATE,
            last_updated_by = NVL(fnd_global.user_id, -1),
            last_update_login = NVL(fnd_global.login_id, -1)
        WHERE interface_id = p_interface_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            fnd_file.put_line(fnd_file.log, '  Warning: Interface record ' || p_interface_id || ' not found for GL status update');
        END IF;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, '  Warning: Failed to update GL status for interface ' || p_interface_id || ': ' || SQLERRM);
    END update_gl_load_status;
    
    /*******************************************************
     * Procedure: submit_gldriccp_program
     *******************************************************/
    
    PROCEDURE submit_gldriccp_program (
        p_conversion_date   IN  DATE,
        x_request_id        OUT NUMBER,
        x_status            OUT VARCHAR2,
        x_message           OUT VARCHAR2
    ) IS
        l_application       VARCHAR2(30) := 'SQLGL';
        l_program_name      VARCHAR2(30) := 'GLDRICCP';
        l_description       VARCHAR2(100);
        l_user_id           NUMBER;
        l_resp_id           NUMBER;
        l_resp_appl_id      NUMBER;
        
    BEGIN
        l_user_id := NVL(fnd_global.user_id, -1);
        l_resp_id := NVL(fnd_global.resp_id, -1);
        l_resp_appl_id := NVL(fnd_global.resp_appl_id, 101);
        
        fnd_global.apps_initialize(
            user_id      => l_user_id,
            resp_id      => l_resp_id,
            resp_appl_id => l_resp_appl_id
        );
        
        l_description := 'Daily Rates Import - ' || TO_CHAR(p_conversion_date, 'DD-MON-YYYY');
        
        x_request_id := fnd_request.submit_request(
            application => l_application,
            program     => l_program_name,
            description => l_description,
            start_time  => NULL,
            sub_request => FALSE
        );
        
        IF x_request_id = 0 OR x_request_id IS NULL THEN
            x_status := g_status_error;
            x_message := 'Failed to submit GLDRICCP program. Request ID: 0';
        ELSE
            x_status := g_status_success;
            x_message := 'GLDRICCP program submitted successfully. Request ID: ' || x_request_id;
        END IF;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            x_status := g_status_error;
            x_message := 'Error submitting GLDRICCP: ' || SQLERRM;
            x_request_id := NULL;
    END submit_gldriccp_program;
    
    /*******************************************************
     * Procedure: get_interface_records
     *******************************************************/
    
    PROCEDURE get_interface_records (
        p_conversion_date   IN  DATE,
        p_process_status    IN  VARCHAR2 DEFAULT NULL
    ) IS
        CURSOR c_interface IS
            SELECT 
                interface_id,
                from_currency || ' -> ' || to_currency AS currency_pair,
                conversion_date,
                conversion_rate,
                process_status,
                response_status_code,
                response_status_message,
                ROUND(api_call_duration_ms, 2) AS api_duration_ms,
                retry_count,
                error_message,
                TO_CHAR(request_timestamp, 'DD-MON-YYYY HH24:MI:SS.FF3') AS request_time,
                TO_CHAR(response_timestamp, 'DD-MON-YYYY HH24:MI:SS.FF3') AS response_time,
                gl_load_status,
                gl_load_request_id,
                TO_CHAR(gl_load_date, 'DD-MON-YYYY HH24:MI:SS') AS gl_load_time
            FROM xxgl_daily_rates_int
            WHERE conversion_date = p_conversion_date
              AND (p_process_status IS NULL OR process_status = p_process_status)
            ORDER BY interface_id;
            
        l_record_count  NUMBER := 0;
        
    BEGIN
        fnd_file.put_line(fnd_file.output, RPAD('=', 100, '='));
        fnd_file.put_line(fnd_file.output, 'EXCHANGE RATE INTERFACE RECORDS');
        fnd_file.put_line(fnd_file.output, 'Date: ' || TO_CHAR(p_conversion_date, 'DD-MON-YYYY'));
        IF p_process_status IS NOT NULL THEN
            fnd_file.put_line(fnd_file.output, 'Filter: Status = ' || p_process_status);
        END IF;
        fnd_file.put_line(fnd_file.output, RPAD('=', 100, '='));
        fnd_file.put_line(fnd_file.output, '');
        
        FOR rec IN c_interface LOOP
            l_record_count := l_record_count + 1;
            
            fnd_file.put_line(fnd_file.output, 'Record #' || l_record_count);
            fnd_file.put_line(fnd_file.output, RPAD('-', 100, '-'));
            fnd_file.put_line(fnd_file.output, '  Interface ID        : ' || rec.interface_id);
            fnd_file.put_line(fnd_file.output, '  Currency Pair       : ' || rec.currency_pair);
            fnd_file.put_line(fnd_file.output, '  Conversion Rate     : ' || TO_CHAR(rec.conversion_rate, '999,999.99'));
            fnd_file.put_line(fnd_file.output, '  Process Status      : ' || rec.process_status);
            fnd_file.put_line(fnd_file.output, '  HTTP Status         : ' || rec.response_status_code || ' - ' || rec.response_status_message);
            fnd_file.put_line(fnd_file.output, '  API Duration        : ' || rec.api_duration_ms || ' ms');
            fnd_file.put_line(fnd_file.output, '  Retry Count         : ' || rec.retry_count);
            fnd_file.put_line(fnd_file.output, '  Request Time        : ' || rec.request_time);
            fnd_file.put_line(fnd_file.output, '  Response Time       : ' || rec.response_time);
            
            IF rec.error_message IS NOT NULL THEN
                fnd_file.put_line(fnd_file.output, '  Error Message       : ' || rec.error_message);
            END IF;
            
            IF rec.gl_load_request_id IS NOT NULL THEN
                fnd_file.put_line(fnd_file.output, '  GL Load Request     : ' || rec.gl_load_request_id);
                fnd_file.put_line(fnd_file.output, '  GL Load Status      : ' || rec.gl_load_status);
                fnd_file.put_line(fnd_file.output, '  GL Load Time        : ' || rec.gl_load_time);
            END IF;
            
            fnd_file.put_line(fnd_file.output, '');
        END LOOP;
        
        fnd_file.put_line(fnd_file.output, RPAD('=', 100, '='));
        fnd_file.put_line(fnd_file.output, 'Total Records: ' || l_record_count);
        fnd_file.put_line(fnd_file.output, RPAD('=', 100, '='));
        
        IF l_record_count = 0 THEN
            fnd_file.put_line(fnd_file.output, '');
            fnd_file.put_line(fnd_file.output, 'No records found for the specified criteria.');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.output, '');
            fnd_file.put_line(fnd_file.output, 'ERROR: ' || SQLERRM);
    END get_interface_records;

END xxgl_daily_rates_api_pkg;
/

SHOW ERRORS PACKAGE BODY xxgl_daily_rates_api_pkg;

PROMPT
PROMPT =====================================================
PROMPT Package Body created successfully
PROMPT =====================================================
PROMPT
PROMPT Next step: Run 05_test_execution.sql to test
PROMPT =====================================================
