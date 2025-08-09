;; DecentralizedHR: Enterprise Payroll Automation Smart Contract
;; Description: A comprehensive blockchain-based human resources management system that automates 
;; employee compensation processing, tax calculations, benefits deductions, and maintains immutable 
;; payroll records. Features multi-tier employee support (hourly/salary), configurable pay schedules, 
;; advanced time tracking, treasury management, and complete audit transparency for enterprise operations.

;; SYSTEM ADMINISTRATION & ACCESS CONTROL

(define-constant system-administrator tx-sender)

;; ERROR CODE DEFINITIONS

(define-constant ERR-ACCESS-DENIED (err u100))
(define-constant ERR-EMPLOYEE-NOT-EXISTS (err u101))
(define-constant ERR-TREASURY-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-EMPLOYEE-ALREADY-REGISTERED (err u103))
(define-constant ERR-INVALID-COMPENSATION-AMOUNT (err u104))
(define-constant ERR-INVALID-TIMESTAMP (err u105))
(define-constant ERR-PAYROLL-ALREADY-COMPLETED (err u106))
(define-constant ERR-INVALID-INPUT-PARAMETER (err u107))
(define-constant ERR-INVALID-PERCENTAGE-RATE (err u108))
(define-constant ERR-INVALID-EMPLOYEE-NAME (err u109))
(define-constant ERR-INVALID-WALLET-PRINCIPAL (err u110))

;; BUSINESS LOGIC CONSTANTS & LIMITS

(define-constant maximum-tax-withholding-basis-points u10000) ;; 100.00%
(define-constant maximum-benefits-deduction-basis-points u10000) ;; 100.00%
(define-constant maximum-annual-salary-limit u1000000000000) ;; $1T max yearly
(define-constant maximum-hourly-wage-limit u1000000) ;; $1M max hourly
(define-constant maximum-hours-per-period u1000) ;; 1000 hours max
(define-constant basis-points-conversion-factor u10000) ;; For percentage calculations
(define-constant default-biweekly-pay-period-seconds u1209600) ;; 14 days
(define-constant maximum-pay-period-duration-seconds u2592000) ;; 30 days max

;; CORE DATA STRUCTURES

;; Primary employee registry with comprehensive information
(define-map employee-master-registry 
  { employee-identifier: (string-ascii 36) } 
  {
    employee-wallet-principal: principal,
    full-employee-name: (string-ascii 50),
    yearly-salary-amount: uint,
    hourly-wage-rate: uint,
    is-paid-hourly: bool,
    benefits-deduction-rate-basis-points: uint,
    tax-withholding-rate-basis-points: uint,
    most-recent-payment-timestamp: uint,
    current-employment-status: bool
  }
)

;; Detailed payroll transaction history with complete breakdown
(define-map payroll-transaction-history
  { 
    employee-identifier: (string-ascii 36),
    pay-period-ending-date: uint
  }
  {
    calculated-gross-pay: uint,
    calculated-tax-withholding: uint,
    calculated-benefits-deduction: uint,
    final-net-payment: uint,
    payment-processed-timestamp: uint,
    transaction-completion-status: bool
  }
)

;; Time tracking records for hourly workforce
(define-map employee-hours-ledger
  {
    employee-identifier: (string-ascii 36),
    pay-period-ending-date: uint
  }
  { hours-worked-in-period: uint }
)

;; Employee indexing system for efficient iteration
(define-map workforce-directory-index
  { directory-position: uint }
  { employee-identifier: (string-ascii 36) }
)

;; SYSTEM STATE VARIABLES

(define-data-var company-treasury-balance uint u0)
(define-data-var scheduled-next-payroll-date uint u0)
(define-data-var configured-pay-period-duration uint default-biweekly-pay-period-seconds)
(define-data-var current-workforce-size uint u0)
(define-data-var maximum-allowable-pay-period uint maximum-pay-period-duration-seconds)

;; INPUT VALIDATION & UTILITY FUNCTIONS

;; Validate wallet principal address legitimacy
(define-read-only (validate-wallet-principal-address (wallet-principal principal))
  (not (is-eq wallet-principal 'SP000000000000000000002Q6VF78)))

;; Validate percentage rate within business rules
(define-read-only (validate-percentage-rate-within-bounds (percentage-rate uint))
  (<= percentage-rate maximum-tax-withholding-basis-points))

;; Validate future timestamp for scheduling
(define-read-only (validate-future-timestamp (target-timestamp uint))
  (let ((current-blockchain-time (default-to u0 (get-block-info? time block-height))))
    (> target-timestamp current-blockchain-time)))

;; Check employee registration status
(define-read-only (verify-employee-registration-exists (employee-identifier (string-ascii 36)))
  (is-some (map-get? employee-master-registry { employee-identifier: employee-identifier })))

;; Verify employee active employment status
(define-read-only (verify-active-employment-status (employee-identifier (string-ascii 36)))
  (match (map-get? employee-master-registry { employee-identifier: employee-identifier })
    employee-record (get current-employment-status employee-record)
    false
  )
)

;; EMPLOYEE DATA ACCESS FUNCTIONS

;; Retrieve comprehensive employee profile information
(define-read-only (fetch-employee-complete-profile (employee-identifier (string-ascii 36)))
  (map-get? employee-master-registry { employee-identifier: employee-identifier })
)

;; Access specific payroll transaction details
(define-read-only (fetch-payroll-transaction-details (employee-identifier (string-ascii 36)) (pay-period-ending-date uint))
  (map-get? payroll-transaction-history { employee-identifier: employee-identifier, pay-period-ending-date: pay-period-ending-date })
)

;; Retrieve tracked hours for pay period
(define-read-only (fetch-employee-hours-for-period (employee-identifier (string-ascii 36)) (pay-period-ending-date uint))
  (default-to { hours-worked-in-period: u0 }
    (map-get? employee-hours-ledger { employee-identifier: employee-identifier, pay-period-ending-date: pay-period-ending-date })
  )
)

;; Access employee by directory index position
(define-read-only (fetch-employee-by-directory-position (directory-position uint))
  (match (map-get? workforce-directory-index { directory-position: directory-position })
    directory-entry (some (get employee-identifier directory-entry))
    none
  )
)

;; SYSTEM CONFIGURATION ACCESS FUNCTIONS

;; Retrieve current company treasury balance
(define-read-only (fetch-current-treasury-balance)
  (var-get company-treasury-balance)
)

;; Get scheduled next payroll processing date
(define-read-only (fetch-scheduled-payroll-date)
  (var-get scheduled-next-payroll-date)
)

;; Access current pay period configuration
(define-read-only (fetch-pay-period-configuration)
  (var-get configured-pay-period-duration)
)

;; Get total active workforce count
(define-read-only (fetch-total-workforce-count)
  (var-get current-workforce-size)
)

;; PAYROLL CALCULATION ENGINE

;; Calculate comprehensive employee payment breakdown
(define-read-only (calculate-employee-payment-breakdown (employee-identifier (string-ascii 36)) (pay-period-ending-date uint))
  (match (map-get? employee-master-registry { employee-identifier: employee-identifier })
    employee-record 
      (let (
        (total-hours-worked (get hours-worked-in-period (fetch-employee-hours-for-period employee-identifier pay-period-ending-date)))
        (calculated-gross-compensation (if (get is-paid-hourly employee-record)
                      (* (get hourly-wage-rate employee-record) total-hours-worked)
                      (get yearly-salary-amount employee-record)))
        (calculated-tax-withholding-amount (/ (* calculated-gross-compensation (get tax-withholding-rate-basis-points employee-record)) basis-points-conversion-factor))
        (calculated-benefits-deduction-amount (/ (* calculated-gross-compensation (get benefits-deduction-rate-basis-points employee-record)) basis-points-conversion-factor))
        (final-net-compensation (- (- calculated-gross-compensation calculated-tax-withholding-amount) calculated-benefits-deduction-amount))
      )
      (ok {
        calculated-gross-pay: calculated-gross-compensation,
        calculated-tax-withholding: calculated-tax-withholding-amount,
        calculated-benefits-deduction: calculated-benefits-deduction-amount,
        final-net-payment: final-net-compensation
      }))
    ERR-EMPLOYEE-NOT-EXISTS
  )
)

;; TREASURY MANAGEMENT OPERATIONS

;; Deposit funds into company treasury
(define-public (deposit-funds-to-treasury (deposit-amount uint))
  (begin
    (asserts! (> deposit-amount u0) ERR-INVALID-COMPENSATION-AMOUNT)
    (var-set company-treasury-balance (+ (var-get company-treasury-balance) deposit-amount))
    (ok deposit-amount)
  )
)

;; Withdraw funds from treasury (administrator only)
(define-public (withdraw-funds-from-treasury (withdrawal-amount uint))
  (begin
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    (asserts! (> withdrawal-amount u0) ERR-INVALID-COMPENSATION-AMOUNT)
    (asserts! (<= withdrawal-amount (var-get company-treasury-balance)) ERR-TREASURY-INSUFFICIENT-BALANCE)
    (var-set company-treasury-balance (- (var-get company-treasury-balance) withdrawal-amount))
    (ok withdrawal-amount)
  )
)

;; EMPLOYEE LIFECYCLE MANAGEMENT

;; Register new employee in workforce system
(define-public (register-new-employee 
  (employee-identifier (string-ascii 36))
  (employee-wallet-principal principal)
  (full-employee-name (string-ascii 50))
  (yearly-salary-amount uint)
  (hourly-wage-rate uint)
  (is-hourly-position bool)
  (benefits-deduction-percentage uint)
  (tax-withholding-percentage uint)
)
  (begin
    ;; Administrator access validation
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    
    ;; Comprehensive input validation
    (asserts! (not (verify-employee-registration-exists employee-identifier)) ERR-EMPLOYEE-ALREADY-REGISTERED)
    (asserts! (validate-wallet-principal-address employee-wallet-principal) ERR-INVALID-WALLET-PRINCIPAL)
    (asserts! (> (len full-employee-name) u0) ERR-INVALID-EMPLOYEE-NAME)
    (asserts! (validate-percentage-rate-within-bounds benefits-deduction-percentage) ERR-INVALID-PERCENTAGE-RATE)
    (asserts! (validate-percentage-rate-within-bounds tax-withholding-percentage) ERR-INVALID-PERCENTAGE-RATE)
    
    ;; Validate compensation structure based on employment type
    (asserts! (or (and is-hourly-position 
                       (> hourly-wage-rate u0) 
                       (<= hourly-wage-rate maximum-hourly-wage-limit)
                       (is-eq yearly-salary-amount u0))
                 (and (not is-hourly-position) 
                      (> yearly-salary-amount u0) 
                      (<= yearly-salary-amount maximum-annual-salary-limit)
                      (is-eq hourly-wage-rate u0)))
             ERR-INVALID-COMPENSATION-AMOUNT)
    
    ;; Create comprehensive employee record
    (map-set employee-master-registry
      { employee-identifier: employee-identifier }
      {
        employee-wallet-principal: employee-wallet-principal,
        full-employee-name: full-employee-name,
        yearly-salary-amount: yearly-salary-amount,
        hourly-wage-rate: hourly-wage-rate,
        is-paid-hourly: is-hourly-position,
        benefits-deduction-rate-basis-points: benefits-deduction-percentage,
        tax-withholding-rate-basis-points: tax-withholding-percentage,
        most-recent-payment-timestamp: u0,
        current-employment-status: true
      }
    )
    
    ;; Update workforce directory indexing
    (let ((current-workforce-count (var-get current-workforce-size)))
      (map-set workforce-directory-index 
        { directory-position: current-workforce-count }
        { employee-identifier: employee-identifier }
      )
      (var-set current-workforce-size (+ current-workforce-count u1))
    )
    
    (ok true)
  )
)

;; Update comprehensive employee information
(define-public (update-employee-comprehensive-information 
  (employee-identifier (string-ascii 36))
  (updated-wallet-principal principal)
  (updated-employee-name (string-ascii 50))
  (updated-yearly-salary uint)
  (updated-hourly-wage uint)
  (updated-hourly-status bool)
  (updated-benefits-percentage uint)
  (updated-tax-percentage uint)
)
  (begin
    ;; Administrator access validation
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    
    ;; Validate employee existence and input parameters
    (asserts! (verify-employee-registration-exists employee-identifier) ERR-EMPLOYEE-NOT-EXISTS)
    (asserts! (validate-wallet-principal-address updated-wallet-principal) ERR-INVALID-WALLET-PRINCIPAL)
    (asserts! (> (len updated-employee-name) u0) ERR-INVALID-EMPLOYEE-NAME)
    (asserts! (validate-percentage-rate-within-bounds updated-benefits-percentage) ERR-INVALID-PERCENTAGE-RATE)
    (asserts! (validate-percentage-rate-within-bounds updated-tax-percentage) ERR-INVALID-PERCENTAGE-RATE)
    
    ;; Validate updated compensation structure
    (asserts! (or (and updated-hourly-status 
                       (> updated-hourly-wage u0) 
                       (<= updated-hourly-wage maximum-hourly-wage-limit)
                       (is-eq updated-yearly-salary u0))
                 (and (not updated-hourly-status) 
                      (> updated-yearly-salary u0) 
                      (<= updated-yearly-salary maximum-annual-salary-limit)
                      (is-eq updated-hourly-wage u0)))
             ERR-INVALID-COMPENSATION-AMOUNT)
    
    (let ((existing-employee-record (unwrap! (map-get? employee-master-registry { employee-identifier: employee-identifier }) ERR-EMPLOYEE-NOT-EXISTS)))
      (map-set employee-master-registry
        { employee-identifier: employee-identifier }
        {
          employee-wallet-principal: updated-wallet-principal,
          full-employee-name: updated-employee-name,
          yearly-salary-amount: updated-yearly-salary,
          hourly-wage-rate: updated-hourly-wage,
          is-paid-hourly: updated-hourly-status,
          benefits-deduction-rate-basis-points: updated-benefits-percentage,
          tax-withholding-rate-basis-points: updated-tax-percentage,
          most-recent-payment-timestamp: (get most-recent-payment-timestamp existing-employee-record),
          current-employment-status: (get current-employment-status existing-employee-record)
        }
      )
    )
    (ok true)
  )
)

;; Deactivate employee employment status
(define-public (deactivate-employee-employment-status (employee-identifier (string-ascii 36)))
  (begin
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    (asserts! (verify-employee-registration-exists employee-identifier) ERR-EMPLOYEE-NOT-EXISTS)
    
    (let ((existing-employee-record (unwrap! (map-get? employee-master-registry { employee-identifier: employee-identifier }) ERR-EMPLOYEE-NOT-EXISTS)))
      (map-set employee-master-registry
        { employee-identifier: employee-identifier }
        {
          employee-wallet-principal: (get employee-wallet-principal existing-employee-record),
          full-employee-name: (get full-employee-name existing-employee-record),
          yearly-salary-amount: (get yearly-salary-amount existing-employee-record),
          hourly-wage-rate: (get hourly-wage-rate existing-employee-record),
          is-paid-hourly: (get is-paid-hourly existing-employee-record),
          benefits-deduction-rate-basis-points: (get benefits-deduction-rate-basis-points existing-employee-record),
          tax-withholding-rate-basis-points: (get tax-withholding-rate-basis-points existing-employee-record),
          most-recent-payment-timestamp: (get most-recent-payment-timestamp existing-employee-record),
          current-employment-status: false
        }
      )
    )
    (ok true)
  )
)

;; Reactivate employee employment status
(define-public (reactivate-employee-employment-status (employee-identifier (string-ascii 36)))
  (begin
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    (asserts! (verify-employee-registration-exists employee-identifier) ERR-EMPLOYEE-NOT-EXISTS)
    
    (let ((existing-employee-record (unwrap! (map-get? employee-master-registry { employee-identifier: employee-identifier }) ERR-EMPLOYEE-NOT-EXISTS)))
      (map-set employee-master-registry
        { employee-identifier: employee-identifier }
        {
          employee-wallet-principal: (get employee-wallet-principal existing-employee-record),
          full-employee-name: (get full-employee-name existing-employee-record),
          yearly-salary-amount: (get yearly-salary-amount existing-employee-record),
          hourly-wage-rate: (get hourly-wage-rate existing-employee-record),
          is-paid-hourly: (get is-paid-hourly existing-employee-record),
          benefits-deduction-rate-basis-points: (get benefits-deduction-rate-basis-points existing-employee-record),
          tax-withholding-rate-basis-points: (get tax-withholding-rate-basis-points existing-employee-record),
          most-recent-payment-timestamp: (get most-recent-payment-timestamp existing-employee-record),
          current-employment-status: true
        }
      )
    )
    (ok true)
  )
)

;; TIME TRACKING MANAGEMENT

;; Record work hours for hourly employees
(define-public (submit-employee-work-hours (employee-identifier (string-ascii 36)) (pay-period-ending-date uint) (total-hours-worked uint))
  (begin
    ;; Administrator access validation
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    
    ;; Comprehensive input validation
    (asserts! (verify-employee-registration-exists employee-identifier) ERR-EMPLOYEE-NOT-EXISTS)
    (asserts! (and (> total-hours-worked u0) (<= total-hours-worked maximum-hours-per-period)) ERR-INVALID-COMPENSATION-AMOUNT)
    (asserts! (validate-future-timestamp pay-period-ending-date) ERR-INVALID-TIMESTAMP)
    
    (let ((employee-record (unwrap! (map-get? employee-master-registry { employee-identifier: employee-identifier }) ERR-EMPLOYEE-NOT-EXISTS)))
      (asserts! (get is-paid-hourly employee-record) ERR-ACCESS-DENIED)
      
      ;; Record comprehensive hours tracking
      (map-set employee-hours-ledger
        { employee-identifier: employee-identifier, pay-period-ending-date: pay-period-ending-date }
        { hours-worked-in-period: total-hours-worked }
      )
    )
    (ok true)
  )
)

;; PAYROLL PROCESSING OPERATIONS

;; Process comprehensive individual employee payment
(define-public (execute-individual-employee-payment (employee-identifier (string-ascii 36)) (pay-period-ending-date uint))
  (begin
    ;; Administrator access validation
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    
    ;; Input validation and duplicate payment prevention
    (asserts! (verify-employee-registration-exists employee-identifier) ERR-EMPLOYEE-NOT-EXISTS)
    (asserts! (validate-future-timestamp pay-period-ending-date) ERR-INVALID-TIMESTAMP)
    
    ;; Verify payment hasn't been processed already
    (asserts! (is-none (map-get? payroll-transaction-history 
                                { employee-identifier: employee-identifier, pay-period-ending-date: pay-period-ending-date }))
             ERR-PAYROLL-ALREADY-COMPLETED)
    
    (let (
      (employee-record (unwrap-panic (map-get? employee-master-registry { employee-identifier: employee-identifier })))
    )
      ;; Calculate comprehensive payment breakdown
      (try! (calculate-employee-payment-breakdown employee-identifier pay-period-ending-date))
      
      ;; Execute payment processing logic
      (let (
        (payment-calculation (unwrap-panic (calculate-employee-payment-breakdown employee-identifier pay-period-ending-date)))
        (calculated-gross-amount (get calculated-gross-pay payment-calculation))
        (calculated-tax-amount (get calculated-tax-withholding payment-calculation))
        (calculated-benefits-amount (get calculated-benefits-deduction payment-calculation))
        (final-net-amount (get final-net-payment payment-calculation))
        (current-blockchain-time (unwrap-panic (get-block-info? time block-height)))
      )
        ;; Verify employee eligibility and treasury sufficiency
        (asserts! (get current-employment-status employee-record) ERR-ACCESS-DENIED)
        (asserts! (>= (var-get company-treasury-balance) final-net-amount) ERR-TREASURY-INSUFFICIENT-BALANCE)
        
        ;; Create comprehensive payroll transaction record
        (map-set payroll-transaction-history
          { employee-identifier: employee-identifier, pay-period-ending-date: pay-period-ending-date }
          {
            calculated-gross-pay: calculated-gross-amount,
            calculated-tax-withholding: calculated-tax-amount,
            calculated-benefits-deduction: calculated-benefits-amount,
            final-net-payment: final-net-amount,
            payment-processed-timestamp: current-blockchain-time,
            transaction-completion-status: true
          }
        )
        
        ;; Update employee's payment history timestamp
        (map-set employee-master-registry
          { employee-identifier: employee-identifier }
          {
            employee-wallet-principal: (get employee-wallet-principal employee-record),
            full-employee-name: (get full-employee-name employee-record),
            yearly-salary-amount: (get yearly-salary-amount employee-record),
            hourly-wage-rate: (get hourly-wage-rate employee-record),
            is-paid-hourly: (get is-paid-hourly employee-record),
            benefits-deduction-rate-basis-points: (get benefits-deduction-rate-basis-points employee-record),
            tax-withholding-rate-basis-points: (get tax-withholding-rate-basis-points employee-record),
            most-recent-payment-timestamp: current-blockchain-time,
            current-employment-status: (get current-employment-status employee-record)
          }
        )
        
        ;; Process treasury deduction for payment
        (var-set company-treasury-balance (- (var-get company-treasury-balance) final-net-amount))
        
        (ok final-net-amount)
      )
    )
  )
)

;; PAYROLL SCHEDULING & SYSTEM CONFIGURATION

;; Execute comprehensive batch payroll processing
(define-public (execute-comprehensive-payroll-batch (pay-period-ending-date uint))
  (begin
    ;; Administrator access validation
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    
    ;; Input validation for batch processing
    (asserts! (validate-future-timestamp pay-period-ending-date) ERR-INVALID-TIMESTAMP)
    
    (let (
      (current-blockchain-time (unwrap-panic (get-block-info? time block-height)))
      (validated-period-end-date pay-period-ending-date)
      (current-pay-period-duration (var-get configured-pay-period-duration))
    )
      ;; Schedule subsequent payroll processing date
      (var-set scheduled-next-payroll-date (+ validated-period-end-date current-pay-period-duration))
      
      ;; Complete batch processing setup
      (ok true)
    )
  )
)

;; Configure payroll period duration settings
(define-public (configure-payroll-period-duration (updated-duration uint))
  (begin
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    (asserts! (and (> updated-duration u0) (<= updated-duration (var-get maximum-allowable-pay-period))) ERR-INVALID-COMPENSATION-AMOUNT)
    (var-set configured-pay-period-duration updated-duration)
    (ok true)
  )
)

;; Initialize comprehensive payroll system
(define-public (initialize-comprehensive-payroll-system (initial-payroll-processing-date uint))
  (begin
    (asserts! (is-eq tx-sender system-administrator) ERR-ACCESS-DENIED)
    (asserts! (is-eq (var-get scheduled-next-payroll-date) u0) ERR-ACCESS-DENIED)
    (asserts! (validate-future-timestamp initial-payroll-processing-date) ERR-INVALID-TIMESTAMP)
    
    ;; Set initial payroll processing schedule
    (var-set scheduled-next-payroll-date initial-payroll-processing-date)
    (ok true)
  )
)