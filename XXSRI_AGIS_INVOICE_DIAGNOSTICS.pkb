PROCEDURE update_cai (
    pcustomertrxid               IN NUMBER,
    pdocumentid                  IN VARCHAR2,
    pdocumentstatus              IN VARCHAR2,
    presponsedate                IN VARCHAR2,
    presultcode                  IN VARCHAR2,
    psourcesystem                IN VARCHAR2,
    ptaxagencydocobservations    IN VARCHAR2,
    ptaxagencysequence           IN VARCHAR2,
    pretcode                     OUT VARCHAR2,
    xretcode                     OUT VARCHAR2,
    xretmessage                  OUT VARCHAR2
) AS

    lv_exists         NUMBER;
    lv_trx_num        ra_customer_trx_all.trx_number%TYPE;
    o_return_status   VARCHAR2(1);
    o_msg_count       NUMBER;
    o_msg_data        VARCHAR2(2000);
    l_err_msg         VARCHAR2(1000);
    l_msg_index_out   NUMBER;
    lv_error_message  VARCHAR2(2000);
    
    lv_mail_dl        VARCHAR2(2000);
    lv_from           VARCHAR2(50) := 'oracle@equifax.com';
    lv_recipient      VARCHAR2(2000);
    lv_subject        VARCHAR2(300);
    lv_mail_host      VARCHAR2(50) := 'mail.equifax.com';
    lv_mail_conn      utl_smtp.connection;
    lv_boundary       VARCHAR2(50) := '----*#abc1234321cba#*--';
    lv_count          NUMBER := 1;
    lv_count1         NUMBER := 1;
    lv_val            NUMBER := 1;
    lv_mail           VARCHAR2(4000);
    lv_text_msg       VARCHAR2(200) := 'This is an automated email. Please donot reply to this mail';
    raw_data_sub      RAW(500);
    raw_data          RAW(32767);
    raw_data_html     RAW(32767);
    lv_instance       VARCHAR2(100);
    lv_html           VARCHAR2(32767);
    lv_html_tbl       VARCHAR2(2000);
    lv_html_lines     VARCHAR2(20000);
    lv_st_count       NUMBER;
    lv_first          VARCHAR2(500);
    lv_full           VARCHAR2(4000);
    lv_temp           VARCHAR2(4000);
    lv_request_id     NUMBER;
    lv_trx_number     xxar_arg_afip_outbound_log.trx_number%TYPE;
    lv_comments       xxar_arg_afip_outbound_log.comments%TYPE;
    lv_afip_val_code  xxar_arg_afip_outbound_log.afip_val_code%TYPE;
    lv_afip_val_msg   xxar_arg_afip_outbound_log.afip_val_msg%TYPE;
    lv_source_system  xxar_arg_afip_outbound_log.source_system%TYPE;
    lv_retry_ver      xxar_arg_afip_outbound_log.retry_version%TYPE;
    lc_complete_flag  VARCHAR2(1);

BEGIN
    lv_exists := 0;
    
    BEGIN
        -- Check if transaction exists
        SELECT COUNT(*)
        INTO lv_exists,
             lv_trx_num
        FROM xxefx_ar_eio_chi_outbound_log
        WHERE tracking_seq_num = pcustomertrxid
        GROUP BY trx_number;
        
    EXCEPTION
        WHEN OTHERS THEN
            xretcode := '400';
            xretmessage := 'No AR transaction number exists in Oracle with Customer TRX ID: ' || pcustomertrxid;
    END;
    
    dbms_output.put_line('lv_exists ' || lv_exists);
    
    IF lv_exists = 1 THEN
        dbms_output.put_line(lv_trx_num || '(trx_id - ' || pcustomertrxid || ') Exists in Oracle');
        
        /************************** Customer Update Based on Document Status **************************/
        
        -- Scenario #1: SII APPROVED Documents (APROBADO)
        IF UPPER(pdocumentstatus) IN ('APPROVED', 'APROBADO') THEN
            BEGIN
                -- Update staging table for SII APPROVED status
                UPDATE xxefx_ar_brm_chi_trx_int_stg
                SET 
                    document_id = pdocumentid,
                    sii_response_date = to_date(presponsedate, 'YYYY-MM-DD'),
                    sii_result_code = presultcode,
                    sii_doc_status = pdocumentstatus,
                    sii_caf_number = ptaxagencysequence,
                    source_system = psourcesystem,
                    invoice_error_desc = ptaxagencydocobservations,
                    eio_reced_status = 'Y',
                    record_status = 'SII APPROVED'
                WHERE tracking_seq_num = pcustomertrxid;
                
                xretcode := '200';
                xretmessage := 'Document SII APPROVED - Updates completed successfully';
                
            EXCEPTION
                WHEN OTHERS THEN
                    xretcode := '105';
                    xretmessage := 'Exception in SII APPROVED status update: ' || sqlerrm;
                    
                    -- Update with EIO ERROR status in case of exception
                    BEGIN
                        UPDATE xxefx_ar_brm_chi_trx_int_stg
                        SET record_status = 'EIO ERROR'
                        WHERE tracking_seq_num = pcustomertrxid;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL; -- Ignore secondary errors
                    END;
            END;
            
        -- Scenario #2: SII REJECTED by Government
        ELSIF UPPER(pdocumentstatus) = 'REJECTED' THEN
            BEGIN
                -- Update staging table for SII REJECTED status
                UPDATE xxefx_ar_brm_chi_trx_int_stg
                SET 
                    document_id = pdocumentid,
                    sii_response_date = to_date(presponsedate, 'YYYY-MM-DD'),
                    sii_result_code = presultcode,
                    sii_doc_status = pdocumentstatus,
                    sii_caf_number = ptaxagencysequence,
                    sii_reject_entity = substr(psourcesystem, 1, 150),
                    sii_reject_date = to_date(presponsedate, 'YYYY-MM-DD'),
                    source_system = psourcesystem,
                    invoice_error_desc = ptaxagencydocobservations,
                    eio_reced_status = 'Y',
                    record_status = 'SII REJECTED'
                WHERE tracking_seq_num = pcustomertrxid;
                
                xretcode := '200';
                xretmessage := 'Document SII REJECTED - Updates completed successfully';
                
            EXCEPTION
                WHEN OTHERS THEN
                    xretcode := '105';
                    xretmessage := 'Exception in SII REJECTED status update: ' || sqlerrm;
                    
                    -- Update with EIO ERROR status in case of exception
                    BEGIN
                        UPDATE xxefx_ar_brm_chi_trx_int_stg
                        SET record_status = 'EIO ERROR'
                        WHERE tracking_seq_num = pcustomertrxid;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL; -- Ignore secondary errors
                    END;
            END;
            
        -- Scenario #3: CUSTOMER REJECTED
        ELSIF UPPER(pdocumentstatus) = 'CUSTOMER_REJECTED' THEN
            BEGIN
                -- Update staging table for Customer rejection - Only Customer fields
                UPDATE xxefx_ar_brm_chi_trx_int_stg
                SET 
                    customer_response = 'REJECTED',
                    customer_response_date = to_date(presponsedate, 'YYYY-MM-DD'),
                    customer_rejection_reason = ptaxagencydocobservations,
                    source_system = psourcesystem,
                    eio_reced_status = 'Y',
                    record_status = 'SII REJECTED'
                WHERE tracking_seq_num = pcustomertrxid;
                
                xretcode := '200';
                xretmessage := 'Document CUSTOMER REJECTED - Updates completed successfully';
                
            EXCEPTION
                WHEN OTHERS THEN
                    xretcode := '105';
                    xretmessage := 'Exception in CUSTOMER REJECTED status update: ' || sqlerrm;
                    
                    -- Update with EIO ERROR status in case of exception
                    BEGIN
                        UPDATE xxefx_ar_brm_chi_trx_int_stg
                        SET record_status = 'EIO ERROR'
                        WHERE tracking_seq_num = pcustomertrxid;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL; -- Ignore secondary errors
                    END;
            END;
            
        -- Handle any other status
        ELSE
            BEGIN
                -- Update with basic information for unknown status
                UPDATE xxefx_ar_brm_chi_trx_int_stg
                SET 
                    document_id = pdocumentid,
                    sii_response_date = to_date(presponsedate, 'YYYY-MM-DD'),
                    sii_result_code = presultcode,
                    sii_doc_status = pdocumentstatus,
                    source_system = psourcesystem,
                    invoice_error_desc = ptaxagencydocobservations,
                    eio_reced_status = 'Y',
                    record_status = 'EIO ERROR'
                WHERE tracking_seq_num = pcustomertrxid;
                
                xretcode := '200';
                xretmessage := 'Document status: ' || pdocumentstatus || ' - Basic updates completed';
                
            EXCEPTION
                WHEN OTHERS THEN
                    xretcode := '105';
                    xretmessage := 'Exception in general status update: ' || sqlerrm;
                    
                    -- Update with EIO ERROR status in case of exception
                    BEGIN
                        UPDATE xxefx_ar_brm_chi_trx_int_stg
                        SET record_status = 'EIO ERROR'
                        WHERE tracking_seq_num = pcustomertrxid;
                    EXCEPTION
                        WHEN OTHERS THEN
                            NULL; -- Ignore secondary errors
                    END;
            END;
            
        END IF;
        
    END IF;
    
    xretcode := '200';
    xretmessage := 'OK';
    
EXCEPTION
    WHEN OTHERS THEN
        xretcode := '401';
        xretmessage := 'Unexpected Error updating the CAI Details: ' || sqlcode || ' - ' || sqlerrm;
        
END update_cai;
