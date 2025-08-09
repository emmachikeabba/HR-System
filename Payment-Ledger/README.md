# DecentralizedHR: Enterprise Payroll Automation Smart Contract

## Overview

DecentralizedHR is a comprehensive blockchain-based human resources management system built on the Stacks blockchain using Clarity smart contract language. This enterprise-grade solution automates employee compensation processing, tax calculations, benefits deductions, and maintains immutable payroll records with complete audit transparency.

## Key Features

### **Enterprise-Ready Functionality**
- Multi-tier employee support (hourly and salary-based compensation)
- Configurable pay schedules and periods
- Advanced time tracking for hourly workers
- Treasury management with deposit/withdrawal controls
- Complete audit trail with immutable records

### **Security & Access Control**
- Administrator-only access for sensitive operations
- Input validation and error handling
- Duplicate payment prevention
- Treasury balance verification

### **Comprehensive Payroll Processing**
- Automated gross pay calculations
- Tax withholding computations
- Benefits deduction processing
- Net pay determination
- Batch payroll processing capabilities

## System Architecture

### Core Data Structures

1. **Employee Master Registry**: Central repository of all employee information
2. **Payroll Transaction History**: Immutable record of all payment transactions
3. **Employee Hours Ledger**: Time tracking for hourly employees
4. **Workforce Directory Index**: Efficient employee indexing system

### Configuration Constants

- Maximum tax withholding: 100%
- Maximum benefits deduction: 100%
- Maximum annual salary: $1 trillion
- Maximum hourly wage: $1 million
- Maximum hours per period: 1,000 hours
- Default pay period: 14 days (biweekly)

## Installation & Deployment

### Prerequisites
- Stacks blockchain environment
- Clarity development tools
- Administrator wallet for deployment

### Deployment Steps
1. Deploy the smart contract to the Stacks blockchain
2. Initialize the system using `initialize-comprehensive-payroll-system`
3. Set up treasury funding with `deposit-funds-to-treasury`
4. Configure pay period duration if needed

## Usage Guide

### 1. Employee Management

#### Register New Employee
```clarity
(register-new-employee 
  employee-id
  wallet-principal
  employee-name
  yearly-salary
  hourly-rate
  is-hourly
  benefits-percentage
  tax-percentage)
```

#### Update Employee Information
```clarity
(update-employee-comprehensive-information 
  employee-id
  updated-wallet
  updated-name
  updated-salary
  updated-hourly-rate
  updated-hourly-status
  updated-benefits
  updated-tax)
```

#### Activate/Deactivate Employees
```clarity
(deactivate-employee-employment-status employee-id)
(reactivate-employee-employment-status employee-id)
```

### 2. Time Tracking (Hourly Employees)

#### Submit Work Hours
```clarity
(submit-employee-work-hours 
  employee-id 
  pay-period-end-date 
  hours-worked)
```

### 3. Treasury Management

#### Deposit Funds
```clarity
(deposit-funds-to-treasury amount)
```

#### Withdraw Funds (Admin Only)
```clarity
(withdraw-funds-from-treasury amount)
```

### 4. Payroll Processing

#### Process Individual Payment
```clarity
(execute-individual-employee-payment 
  employee-id 
  pay-period-end-date)
```

#### Execute Batch Payroll
```clarity
(execute-comprehensive-payroll-batch pay-period-end-date)
```

## Data Retrieval Functions

### Employee Information
- `fetch-employee-complete-profile`: Get full employee details
- `fetch-employee-by-directory-position`: Access employee by index
- `verify-employee-registration-exists`: Check if employee exists
- `verify-active-employment-status`: Check employment status

### Payroll Data
- `fetch-payroll-transaction-details`: Get payment history
- `fetch-employee-hours-for-period`: Retrieve time tracking data
- `calculate-employee-payment-breakdown`: Preview payment calculations

### System Information
- `fetch-current-treasury-balance`: Get treasury balance
- `fetch-scheduled-payroll-date`: Next payroll date
- `fetch-pay-period-configuration`: Current pay period settings
- `fetch-total-workforce-count`: Active employee count

## Error Codes

| Code | Description |
|------|-------------|
| 100 | Access denied |
| 101 | Employee not found |
| 102 | Insufficient treasury balance |
| 103 | Employee already registered |
| 104 | Invalid compensation amount |
| 105 | Invalid timestamp |
| 106 | Payroll already completed |
| 107 | Invalid input parameter |
| 108 | Invalid percentage rate |
| 109 | Invalid employee name |
| 110 | Invalid wallet principal |

## Security Considerations

### Access Control
- All administrative functions require system administrator privileges
- Employee data modifications are restricted to authorized personnel
- Treasury operations have strict validation and balance checks

### Data Validation
- Comprehensive input validation for all parameters
- Boundary checks for compensation amounts and percentages
- Timestamp validation for scheduling operations

### Financial Controls
- Treasury balance verification before payments
- Duplicate payment prevention mechanisms
- Immutable transaction records for audit compliance

## Business Logic

### Compensation Calculation
The system supports two employee types:

**Hourly Employees:**
- Gross Pay = Hourly Rate × Hours Worked
- Requires time tracking submissions

**Salaried Employees:**
- Gross Pay = Annual Salary ÷ Pay Periods per Year
- Fixed compensation per pay period

### Deduction Processing
1. **Tax Withholding**: Applied as percentage of gross pay
2. **Benefits Deduction**: Applied as percentage of gross pay
3. **Net Pay**: Gross Pay - Tax Withholding - Benefits Deduction

## Integration Examples

### Setting Up a New Employee
```clarity
;; Register hourly employee
(register-new-employee 
  "EMP001"
  'SP1234567890ABCDEF
  "John Doe"
  u0          ;; No salary for hourly
  u25000      ;; $25/hour (in microSTX)
  true        ;; Is hourly
  u500        ;; 5% benefits
  u2000)      ;; 20% tax withholding
```

### Processing Payroll
```clarity
;; Submit hours for hourly employee
(submit-employee-work-hours "EMP001" u1640995200 u80)

;; Process payment
(execute-individual-employee-payment "EMP001" u1640995200)
```

## Maintenance & Monitoring

### Regular Tasks
- Monitor treasury balance
- Review payroll schedules
- Validate employee status updates
- Audit transaction history

### System Health Checks
- Verify scheduled payroll dates
- Check employee directory consistency
- Monitor transaction completion rates

## Compliance & Auditing

### Audit Trail
- All transactions are permanently recorded on-chain
- Immutable payroll history for compliance reporting
- Transparent calculation methods for regulatory review

### Reporting Capabilities
- Employee payment history retrieval
- Treasury transaction logs
- Time tracking records for labor compliance

## Support & Troubleshooting

### Common Issues
1. **Insufficient Treasury Balance**: Ensure adequate funding before payroll
2. **Invalid Timestamps**: Use future dates for pay period endings
3. **Duplicate Payments**: System prevents double-processing automatically

### Best Practices
- Regular treasury balance monitoring
- Consistent pay period scheduling
- Proper employee status management
- Timely hours submission for hourly workers