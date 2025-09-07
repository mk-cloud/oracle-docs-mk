CREATE OR REPLACE PACKAGE BODY      XXSRI_AGIS_INVOICE_DIAGNOSTICS IS
-- +===========================================================================================================+
-- | SunRun, Inc. 											                                            
-- | San Francisco, CA 										                                          
-- +============================================================================================================+
-- |                             											                                    
-- |Program Name : APPS.XXSRI_AGIS_INVOICE_DIAGNOSTICS      								               
-- |                                                                    						
-- | Description :  This is the package for Program SNRN: AGIS Invoice Analysis & Diagnosis
-- |                This program scans for various elibibility criteria and valid values                      
-- |                on AP side and AR side for a given AGIS Invoice   							     
-- |                                                                    										     
-- |Change Record:                                             										     
-- |===============                                  										    
-- |Version   Date         Author           Remarks                     								     
-- |=======   ==========  =============    ===================================================================== 	     
-- |1.0       04-0SEP-2020   Afzal Sharief     Initial code version    JIRA TICKET - ERPSUPPORT-10835                   
-- +============================================================================================================+



   G_ERROR                VARCHAR2 (10) := 'ERROR';
   G_SUCCESS              VARCHAR2 (10) := 'PROCESSED';
   G_WARNING              VARCHAR2 (10) := 'WARNING';
   --
   G_USER_ID              NUMBER := Apps.Fnd_Global.User_Id;
   G_ORG_ID               NUMBER := Apps.Fnd_Global.Org_Id;
   G_REQUEST_ID           NUMBER := Apps.Fnd_Global.Conc_Request_Id;
   G_PRG_APPL_ID          NUMBER := Apps.Fnd_Global.Prog_Appl_Id;
   G_PROGRAM_ID           NUMBER := Apps.Fnd_Global.Conc_Program_Id;


      --writes to concurrent output file
      PROCEDURE print_out(p_str IN VARCHAR2) IS
      BEGIN
        fnd_file.put_line(fnd_file.OUTPUT, p_str);
        dbms_output.put_line('Output :' || p_str);
      END print_out;
    
      ------------------------------------------------------------------------------------------------------
    
      --writes to concurrent log file
      PROCEDURE print_log(p_str IN VARCHAR2) IS
      BEGIN
        fnd_file.put_line(fnd_file.LOG, p_str);
        dbms_output.put_line('Log :' || p_str);
      END print_log;
    
    
      PROCEDURE print_both(p_str IN VARCHAR2) IS
      BEGIN
        print_out(p_str);
        print_log(p_str);
      END print_both;

  
    
    FUNCTION get_user_name(
        p_user_id fnd_user.user_id%TYPE
    )
    RETURN    fnd_user.user_name%TYPE  IS
    l_user_name fnd_user.user_name%TYPE;
    BEGIN
        SELECT user_name INTO l_user_name FROM fnd_user WHERE user_id = p_user_id;
        RETURN l_user_name;
    EXCEPTION
    WHEN OTHERS THEN
       RETURN 'EXCEPTION';
    END;
    

    PROCEDURE agis_invoice (
         ERRBUFF               OUT     VARCHAR2
        ,RETCODE               OUT     NUMBER
        ,P_AP_INVOICE          IN      VARCHAR2 DEFAULT NULL
        ) IS

 --       l_return_status varchar2(20) := FND_API.G_RET_STS_SUCCESS;
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2(2000);

        
        --____________________________________________________________________________
        l_created_by                    fnd_user.user_name%TYPE;
        
        l_run_date                      fnd_concurrent_requests.actual_completion_date%TYPE;
        l_request_id                    fnd_concurrent_requests.request_id%TYPE;
        l_status                        fnd_concurrent_requests.completion_text%TYPE;
        
        l_trx_date                      ra_customer_trx_all.trx_date%TYPE;
        
        l_ap_trx_date                   ap_invoices_all.invoice_date%TYPE;
        
        l_external_bank_account_id      apps.ap_checks_all.external_bank_account_id%TYPE;
        l_payment_date                  apps.ap_checks_all.check_date%TYPE;
        l_payment_amount                apps.ap_checks_all.amount%TYPE;
        l_bank_ac                       apps.ap_checks_all.bank_account_name%TYPE;
           
        l_bank_ac_num                   iby_ext_bank_accounts.bank_account_num%TYPE;
        l_int_bank_ac_id                ce_bank_accounts.bank_account_id%TYPE;
        l_receipt_name                  ar_receipt_methods.name%TYPE;
                       
                       
        l_receipt_#    		            ar_cash_receipts_all.receipt_number%TYPE;
        l_receipt_date                  ar_cash_receipts_all.receipt_date%TYPE;
        l_receipt_amt                   ar_cash_receipts_all.amount%TYPE;
        l_receipt_status                ar_cash_receipts_all.status%TYPE;
        
        
        l_date_order                    VARCHAR2(1);
        
        l_min_period_dt                 gl_period_statuses.start_date%TYPE;
        l_max_period_dt                 gl_period_statuses.end_date%TYPE;    
    
    BEGIN
          
  
    print_both('Analysis & Diagnostics for Invoice #....'||p_ap_invoice);
    print_both('');


    BEGIN
    
    SELECT 
    request_id "Request ID",
    actual_completion_date "Actual Completion Dt",
    completion_text "Status"
    INTO
    l_request_id, l_run_date, l_status 
    FROM fnd_concurrent_requests req, fnd_concurrent_programs_tl conctl
    WHERE req.concurrent_program_id  = conctl.concurrent_program_id
    AND conctl.user_concurrent_program_name = 'SNRN: Auto Receipts for AGIS Invoices'
    AND ROWNUM = 1
    ORDER BY actual_completion_date DESC;
    
    print_both('LAST RUN: - Request ID, Run Date, Status ....'||l_request_id||', '||l_run_date||', '||l_status);
    print_both('');

    EXCEPTION
    WHEN NO_DATA_FOUND THEN
            print_both('NO program RUNS FOUND ** ');   
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY PROGRAM RUNS FOUND TODAY - ** ');   
    WHEN OTHERS THEN
            print_both('EXCEPTION 145');    
    END;


    BEGIN
        l_trx_date := NULL;
        print_both('');
        print_both('(1) AR INVOICE :- ');
        print_both('__________________');
        print_both('');
        
        SELECT trx_date, created_by INTO l_trx_date, l_created_by 
        FROM ra_customer_trx_all 
        WHERE trx_number = p_ap_invoice
        AND status_trx = 'OP' AND nvl(complete_flag,'N') = 'Y';
        
        IF(l_trx_date IS NULL) THEN
            print_both('NO AR INVOICE FOUND - ** F A I L E D ** ');
        ELSE 
            print_both('FOUND - ** P A S S E D ** ');
            print_both('');
            print_both('INVOICE-DATE, CREATED BY ........ '||l_trx_date||', '|| get_user_name(l_created_by));
        END IF; 

    EXCEPTION
    WHEN NO_DATA_FOUND THEN
            print_both('NO AR INVOICE FOUND - ** F A I L E D ** ');   
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY AR INVOICES FOUND - ** F A I L E D ** ');   
    WHEN OTHERS THEN
            print_both('EXCEPTION 175');    
    END;
    
    BEGIN
        l_ap_trx_date := NULL;
        l_created_by := NULL;
    
        l_ap_trx_date := NULL;
        l_created_by := NULL;
        print_both('');
        print_both('');
        print_both('(2) PAYMENT CHECK :-');
        print_both('_____________________');
        print_both('');
        
        SELECT 
        aia.invoice_date, aia.created_by
        INTO l_ap_trx_date, l_created_by
            FROM 
            ap_invoice_payments_all app,
            ap_invoices_all aia,
            ar_payment_schedules_all psa,
            ra_customer_trx_all rcta
            WHERE 1=1
            AND aia.invoice_num = p_ap_invoice
            AND aia.pay_group_lookup_code = 'INTERCO' 
            AND rcta.trx_number = aia.invoice_num
            AND app.invoice_id = aia.invoice_id
            AND rcta.customer_trx_id = psa.customer_trx_id
            AND abs(app.amount - psa.amount_due_remaining) >= 0.05
            AND NVL(app.reversal_flag,'X') <> 'Y';
            
        IF(l_ap_trx_date IS NULL) THEN
                print_both('NO PAYMENT FOUND OR PAYMENT IS ZERO AMOUNT - ** F A I L E D ** ');
            ELSE 
                print_both('PAYMENT FOUND AND IS NON-ZERO - ** P A S S E D **');
                print_both('');
                print_both('INVOICE-DATE, CREATED BY ........ '||l_trx_date||', '|| get_user_name(l_created_by));
        END IF; 
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
                print_both('NO PAYMENT FOUND OR PAYMENT IS NOT ZERO AMOUNT - ** F A I L E D ** ');  
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY PAYMENT RECORDS FOUND - ** F A I L E D ** ');                   
    WHEN OTHERS THEN
            print_both('EXCEPTION ......221 ');   
    END;
    
    BEGIN

        l_external_bank_account_id           := NULL;
        l_payment_date                       := NULL;
        l_payment_amount                     := NULL;
        l_bank_ac                            := NULL;
        print_both('');
        print_both('');
        print_both('(3) AP SIDE PAYMENT BANK AC AND PAYMENT AT LINE (CHECK) LEVEL :-');
        print_both('________________________________________________________________');
        print_both('');
        SELECT 
           apc.external_bank_account_id,
           apc.check_date,
           apc.amount,
           apc.bank_account_name,
           apc.created_by
           INTO
           l_external_bank_account_id, l_payment_date, l_payment_amount, l_bank_ac, l_created_by
            FROM 
            ap_invoices_all aia,
            apps.ap_invoice_payments_all app,
            apps.ap_checks_all apc
            WHERE 1=1
            AND aia.invoice_num = p_ap_invoice
            AND aia.pay_group_lookup_code = 'INTERCO' 
            AND aia.invoice_id = app.invoice_id
            AND NVL(app.reversal_flag,'X') <> 'Y'
            AND apc.void_date IS NULL
            AND apc.check_id = app.check_id;
            
        IF(l_external_bank_account_id IS NULL) THEN
                print_both('NO AP SIDE PAYMENT BANK ACCOUNT OR PAYMENT NOT AT CHECK LEVEL - ** F A I L E D ** ');
            ELSE 
                print_both('PAYMENT BANK ACCOUNT FOUND ON AP SIDE AND PAYMENT AT CHECK LEVEL FOUND- ** P A S S E D ** ');
                print_both('');
                print_both('EXTERNAL BANK AC ID, PAYMENT DATE, PAYMENT AMOUNT, BANK ACCOUNT ........ '||
                l_external_bank_account_id||', '|| l_payment_date||', '||l_payment_amount||', '||l_bank_ac);
                print_both('CREATED BY ........ '||get_user_name(l_created_by));
        END IF; 
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
                print_both('NO AP SIDE PAYMENT BANK ACCOUNT OR PAYMENT NOT AT CHECK LEVEL - ** F A I L E D ** ');
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY CHECK LEVEL PAYMENT RECORDS FOUND - ** F A I L E D ** ');         
    WHEN OTHERS THEN
            print_both('EXCEPTION ...... 271');   
    END;
    
    
    BEGIN

        l_bank_ac_num           := NULL;
        l_created_by            := NULL;

        print_both('');
        print_both('');
        print_both('(4) AP SIDE SUPPLIER AND BANK ACCOUNTS MAPPING :-');
        print_both('_________________________________________________');
        print_both('');
        
        SELECT iby.bank_account_num, iby.created_by
        INTO   l_bank_ac_num, l_created_by
        FROM iby_ext_bank_accounts iby
        WHERE iby.ext_bank_account_id = l_external_bank_account_id;
            
        IF(l_bank_ac_num IS NULL) THEN
                print_both('NO AP SIDE SUPPLIER AND BANK ACCOUNTS MAPPING - ** F A I L E D ** ');
            ELSE 
                print_both('AP SIDE SUPPLIER AND BANK ACCOUNTS MAPPING FOUND- ** P A S S E D ** ');
                print_both('');
                print_both('BANK ACCOUNT NUMBER... '||
                l_bank_ac_num);
                print_both('CREATED BY ........ '||get_user_name(l_created_by));
        END IF; 
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
                print_both('NO AP SIDE SUPPLIER AND BANK ACCOUNTS MAPPING FOUND - ** F A I L E D ** ');
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY AP SIDE SUPPLIER AND BANK ACCOUNTS MAPPING FOUND - ** F A I L E D ** ');   
    WHEN OTHERS THEN
            print_both('EXCEPTION ......307 ');   
    END;
    
    BEGIN
 
        l_int_bank_ac_id            := NULL;
        l_created_by                := NULL;

        print_both('');
        print_both('');
        print_both('(5) AR SIDE INTERNAL BANK ACCOUNT CHECK :-');
        print_both('__________________________________________');
        print_both('');
        
        SELECT 
        ceb.bank_account_id, ceb.created_by
        INTO l_int_bank_ac_id, l_created_by
        FROM
        ce_bank_accounts ceb
        WHERE 
        ceb.bank_account_num = l_bank_ac_num
        AND ceb.end_date IS NULL;
            
        IF(l_int_bank_ac_id IS NULL) THEN
                print_both('NO AR SIDE INTERNAL BANK ACCOUNT FOUND - ** F A I L E D ** ');
            ELSE 
                print_both('AR SIDE INTERNAL BANK ACCOUNT FOUND- ** P A S S E D ** ');
                print_both('');
                print_both('INTERNAL BANK AC ID.... '||
                l_int_bank_ac_id);
                print_both('CREATED BY ........ '||get_user_name(l_created_by));
        END IF; 
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
                print_both('NO AR SIDE INTERNAL BANK ACCOUNT FOUND  - ** F A I L E D ** ');
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY AR SIDE INTERNAL BANK ACCOUNTS FOUND - ** F A I L E D ** ');                   
    WHEN OTHERS THEN
            print_both('EXCEPTION ......346 ');   
    END;
    
    BEGIN

        print_both('');
        print_both('');
        print_both('(6) DATES SEQUENCE AND ORDER :-');
        print_both('_______________________________');
        print_both('');

        IF (l_payment_date IS NOT NULL AND l_trx_date IS NOT NULL AND l_ap_trx_date IS NOT NULL) THEN
            print_both('');
            print_both('PAYMENT DATE , AR INVOICE DATE, AP INVOICE DATE... '||
            l_payment_date||', '|| l_trx_date||', '||l_ap_trx_date);
            print_both('');
            SELECT 'X' INTO l_date_order FROM DUAL
            WHERE ((l_payment_date >= l_trx_date) AND (l_trx_date >= l_ap_trx_date));
        
            IF(l_date_order = 'X') THEN
                print_both('PAYMENT DATE >= AR INVOICE DATE >= AP INVOICE DATE - ** P A S S E D ** ');
            ELSE 
               print_both('FAILED FOR - PAYMENT DATE >= AR INVOICE DATE >= AP INVOICE DT - ** F A I L E D ** ');
            END IF;   
        END IF; 
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
                print_both('FAILED FOR - PAYMENT DATE >= AR INVOICE DATE >= AP INVOICE DT - ** F A I L E D ** ');  
    WHEN OTHERS THEN
            print_both('EXCEPTION ......376 ');   
    END;
    
   BEGIN

        l_receipt_name              := NULL;
        l_created_by                := NULL;

        print_both('');
        print_both('');
        print_both('(7) PAYMENT DATE AND OPEN PERIODS CHECK :-');
        print_both('__________________________________________');
        print_both('');
        print_both('PAYMENT DATE ... '||l_payment_date);
        print_both('');         
        SELECT 
        MIN(gps.start_date), MAX(gps.end_date)
        INTO l_min_period_dt, l_max_period_dt
        FROM gl.gl_period_statuses gps,
        gl.gl_ledgers gls
        WHERE 1=1
        AND gps.closing_status IN ('O','F')
        AND gps.application_id = 222
        AND gls.NAME = 'US PRIMARY 3'
        AND gls.ledger_id = gps.set_of_books_id;
            
        IF(l_payment_date >= l_min_period_dt AND l_payment_date <= l_max_period_dt) THEN
                print_both('PAYMENT DATE IS WITHIN OPEN PERIOD(S) - ** P A S S E D ** ');
            ELSE 
                print_both('PAYMENT DATE IS NOT WITHIN OPEN PERIOD(S) - ** F A I L E D ** ');
                print_both('');
        END IF; 
    
    EXCEPTION                
    WHEN OTHERS THEN
            print_both('EXCEPTION ......411 ');   
    END;    
    
   BEGIN

        l_receipt_name              := NULL;
        l_created_by                := NULL;

        print_both('');
        print_both('');
        print_both('(8) RECEIPT METHOD CHECK :-');
        print_both('___________________________');
        print_both('');
        
        SELECT 
        arm.name, arm.created_by
        INTO l_receipt_name, l_created_by
        FROM
        ce_bank_acct_uses_all cbau,
        ar_receipt_method_accounts_all arma,
        ar_receipt_methods arm
        WHERE 1=1
        AND cbau.bank_account_id =  l_int_bank_ac_id
        AND cbau.end_date IS NULL
        AND cbau.bank_acct_use_id = arma.remit_bank_acct_use_id 
        AND arma.end_date IS NULL
        AND arma.receipt_method_id = arm.receipt_method_id;
            
        IF(l_receipt_name IS NULL) THEN
                print_both('NO RECEIPT METHOD FOUND - ** F A I L E D ** ');
            ELSE 
                print_both('RECEIPT METHOD FOUND- ** P A S S E D ** ');
                print_both('');
                print_both('RECEIPT METHOD..... '||
                l_receipt_name);
                print_both('CREATED BY ........ '||get_user_name(l_created_by));
        END IF; 
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
                print_both('NO RECEIPT METHOD - ** F A I L E D ** ');
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY RECEIPT METHODS FOUND - ** F A I L E D ** ');                 
    WHEN OTHERS THEN
            print_both('EXCEPTION ...... 455');   
    END;    
    
  BEGIN

        l_receipt_#             := NULL;
        l_receipt_date          := NULL;
        l_receipt_amt           := NULL;
        l_receipt_status        := NULL;
        l_created_by            := NULL;

        print_both('');
        print_both('');
        print_both('(9) EXISTING RECEIPT CHECK :-');
        print_both('_____________________________');
        print_both('');
        
        SELECT 
        acra.receipt_number, 
        acra.receipt_date,
        acra.amount,
        acra.status,
        acra.created_by
        INTO l_receipt_#, l_receipt_date, l_receipt_amt, l_receipt_status, l_created_by
        FROM
        ar_receivable_applications_all araa,
        ar_cash_receipts_all acra,
        ra_customer_trx_all rcta
        WHERE 1=1
        AND rcta.trx_number = p_ap_invoice
        AND araa.applied_customer_trx_id = rcta.customer_trx_id
        AND araa.application_type = 'CASH'
        AND araa.display = 'Y'
        AND araa.cash_receipt_id = acra.cash_receipt_id
        AND reversal_date IS NULL;        
            
        IF(l_receipt_# IS NOT NULL) THEN
                print_both('EXISTING RECEIPT FOUND - ** F A I L E D ** ');
                print_both('');
                print_both('RECEIPT #, RECEIPT DATE, AMOUNT, STATUS ........ '||
                l_receipt_#||', '|| l_receipt_date||', '||l_receipt_amt||', '||l_receipt_status);
                print_both('CREATED BY ........ '||get_user_name(l_created_by));
            ELSE 
                print_both('NO EXISTING RECEIPT FOUND- ** P A S S E D ** ');
        END IF; 
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
                print_both('NO EXISTING RECEIPT FOUND- ** P A S S E D ** ');
    WHEN TOO_MANY_ROWS THEN
            print_both('TOO MANY RECEIPTS FOUND - ** F A I L E D ** '); 
    WHEN OTHERS THEN
            print_both('EXCEPTION ...... 507');   
    END;    
    
    END agis_invoice;

END;                                                                 --package
/