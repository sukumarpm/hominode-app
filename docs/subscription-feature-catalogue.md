# Hominode Subscription Feature Catalogue

Status: Working product definition
Plans: Essential / Plus / Pro

> Essential is the entry/basic commercial plan.
> Subscription belongs to the community, not to an individual admin.

---

## 1. Core Community Features

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Community management | communityManagement | Yes | Yes | Yes |
| Building / tower management | buildingManagement | Yes | Yes | Yes |
| Unit / flat management | unitManagement | Yes | Yes | Yes |
| Resident management | residentManagement | Yes | Yes | Yes |
| Family members | familyManagement | Yes | Yes | Yes |
| Resident vehicles | vehicleManagement | Yes | Yes | Yes |
| Resident approval workflow | residentApproval | Yes | Yes | Yes |
| Notices / announcements | announcements | Yes | Yes | Yes |
| Documents / circulars | documents | Yes | Yes | Yes |
| Complaints / service requests | complaints | Yes | Yes | Yes |
| Emergency / SOS | emergencySOS | Yes | Yes | Yes |

---

## 2. Security & Visitor Management

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Visitor pre-approval | visitorPreApproval | Yes | Yes | Yes |
| Visitor gate entry / exit | visitorGateManagement | Yes | Yes | Yes |
| Visitor history | visitorHistory | Yes | Yes | Yes |
| Delivery / service-person access | deliveryAccess | Yes | Yes | Yes |
| Security staff access | securityAccess | Yes | Yes | Yes |
| Manual vehicle number lookup | vehicleLookup | No | Yes | Yes |
| Camera plate recognition / ANPR | plateRecognition | No | No | Yes* |

\* May also have usage charges/add-on pricing.

---

## 3. Billing & Resident Payments

Billing is a primary selling feature and is included in Essential.

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Maintenance billing | maintenanceBilling | Yes | Yes | Yes |
| Resident dues / outstanding bills | residentDues | Yes | Yes | Yes |
| Payment-proof / receipt upload | paymentProofUpload | Yes | Yes | Yes |
| Admin payment verification | paymentVerification | Yes | Yes | Yes |
| Resident payment history | paymentHistory | Yes | Yes | Yes |
| Payment receipt record | paymentReceipt | Yes | Yes | Yes |
| Online payment gateway | onlinePayments | No | Yes | Yes |
| Automatic online-payment reconciliation | onlinePayments | No | Yes | Yes |
| Failed / pending online payment handling | onlinePayments | No | Yes | Yes |
| Refund / reversal handling | onlinePayments | No | Yes | Yes |
| Advanced settlement / finance analytics | advancedPaymentReconciliation | No | No | Yes |

Online payment and normal automatic reconciliation are one commercial capability.
Hominode must not offer online payment while requiring admins to manually reconcile normal successful gateway payments.

---

## 4. Community Bank Accounts

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Community bank accounts | communityBankAccounts | 1 | Up to 2 | Multiple |
| Bank account approval workflow | bankAccountApproval | Yes | Yes | Yes |
| Bank-account immutable history | bankAccountAudit | Yes | Yes | Yes |
| Advanced audit reports | advancedAuditReports | No | Yes | Yes |
| Running-balance management | bankBalanceManagement | No | TBD | Yes |

### Bank Account Governance

A community may have one or more bank accounts.

Adding or editing sensitive bank-account details requires:

- A proposer
- At least 3 levels of approval
- Approvers from distinct community personalities/roles
- Example roles:
  - Community Admin
  - Designated Owner
  - Association / Committee Member
- A proposer cannot complete the approval alone
- Changes remain pending until all required approvals are completed
- Every proposal, approval, rejection and change must be permanently auditable
- Other authorized community users may view approved bank-account details
- General users must never see the running account balance

Potential account purposes:

- Collection Account
- Disbursement / Expense Account
- Reserve Fund
- Sinking Fund
- Parking Collection Account
- Facility Collection Account

---

## 5. Facilities & Community Engagement

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Facility directory | facilityDirectory | Yes | Yes | Yes |
| Facility booking | facilityBooking | No | Yes | Yes |
| Facility booking administration | facilityBookingAdmin | No | Yes | Yes |
| Events | events | No | Yes | Yes |
| Polls / voting | polls | No | Yes | Yes |
| Community wall | communityWall | No | Yes | Yes |
| Resident-management messaging | communityMessaging | No | Yes | Yes |
| Domestic staff management | domesticStaff | No | Yes | Yes |
| Resident marketplace | marketplace | No | Yes | Yes |

---

## 6. Community Asset Management

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Community asset register | assetManagement | No | Yes | Yes |
| Asset warranty / AMC | assetWarrantyTracking | No | Yes | Yes |
| Basic maintenance reminders | assetMaintenanceReminders | No | Yes | Yes |
| Preventive maintenance scheduling | assetPreventiveMaintenance | No | No | Yes |
| Detailed maintenance history | assetMaintenanceHistory | No | No | Yes |
| Asset lifecycle / downtime | assetLifecycle | No | No | Yes |
| Asset cost analytics | assetAnalytics | No | No | Yes |
| Asset QR identification | assetQrTracking | No | No | Yes |

Example assets:

- Elevators
- Water pumps / motors
- CCTV
- Generators
- Fire-safety equipment
- Gate barriers
- Electrical equipment
- Gym / clubhouse equipment

---

## 7. Parking

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Parking-slot management | parkingManagement | No | Yes | Yes |
| Paid parking | paidParking | No | Yes | Yes |
| Parking payment tracking | parkingPayments | No | Yes | Yes |
| Parking allocation / waiting list | parkingAllocation | No | No | Yes |
| Advanced parking analytics | parkingAnalytics | No | No | Yes |

---

## 8. Vendor / Supplier Management

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Vendor / supplier master | vendorManagement | No | No | Yes |
| Vendor contracts / AMC | vendorContracts | No | No | Yes |
| Supplier invoices / bills | vendorBilling | No | No | Yes |
| Supplier payment tracking | vendorPayments | No | No | Yes |
| Expense reporting | expenseReporting | No | No | Yes |

Examples:

- Elevator contractor
- Security agency
- Cleaning company
- CCTV supplier
- Generator maintenance
- Pest control
- Gardening
- Plumbing / electrical contractors

---

## 9. Notifications & Automation

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| App push notifications | pushNotifications | Yes | Yes | Yes |
| WhatsApp notifications | whatsappNotifications | No | No | Yes* |
| Automated WhatsApp bill reminders | automatedBillReminders | No | No | Yes* |
| Email payment confirmation / receipt | emailPaymentReceipt | No | No | Yes |
| Advanced notification rules | advancedNotifications | No | No | Yes |

\* WhatsApp/provider usage fees may be charged separately.

---

## 10. Audit & Governance

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Mandatory security audit trail | securityAuditTrail | Yes | Yes | Yes |
| Bank-account approval history | bankAccountAudit | Yes | Yes | Yes |
| Advanced audit search/filter | advancedAuditReports | No | Yes | Yes |
| Audit PDF/CSV export | advancedAuditReports | No | Yes | Yes |
| Generic multi-level approvals | multiLevelApproval | No | No | Yes |
| Advanced governance workflows | advancedGovernance | No | No | Yes |

Security-critical audit records are never restricted by subscription.

---

## 11. Unit Ownership Transfer

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Basic unit ownership transfer | unitOwnershipTransfer | Yes | Yes | Yes |
| Effective-date transfer | advancedOwnershipTransfer | No | Yes | Yes |
| Dues settlement during transfer | advancedOwnershipTransfer | No | Yes | Yes |
| Parking / vehicle reassignment | advancedOwnershipTransfer | No | Yes | Yes |
| Association approval workflow | advancedOwnershipTransfer | No | Yes | Yes |
| Transfer document checklist | advancedOwnershipTransfer | No | Yes | Yes |

The physical unit must remain the same when ownership changes.
Historical ownership must be preserved rather than deleting the unit and recreating it.

Private data belonging to a previous owner must not automatically become visible to the new owner.

---

## 12. Reports & Analytics

| Feature | Entitlement | Essential | Plus | Pro |
|---|---|:---:|:---:|:---:|
| Basic operational reports | basicReports | Limited | Yes | Yes |
| CSV exports | csvExport | No | Yes | Yes |
| Advanced dashboards | advancedAnalytics | No | No | Yes |
| Collection analytics | collectionAnalytics | No | No | Yes |
| Visitor analytics | visitorAnalytics | No | No | Yes |
| Complaint analytics | complaintAnalytics | No | No | Yes |
| Facility analytics | facilityAnalytics | No | No | Yes |
| Finance analytics | financeAnalytics | No | No | Yes |

---

## 13. Future / Deferred

### Resident Credit Balance

Possible future feature:

residentCreditBalance

Example:

Resident overpays by 500
→ 500 credit retained
→ credit applied to next bill

This is preferred over introducing a true stored-value e-wallet initially.

### Resident E-Wallet

Deferred.

A real wallet holding resident funds creates significantly more:

- security requirements
- reconciliation requirements
- refund handling
- payment-provider complexity
- potential regulatory implications

Do not include in V1 subscription scope.

---

## 14. Working Plan Positioning

### Hominode Essential

Core community operations.

Primary commercial selling points:

- Residents / units
- Visitors and security
- Notices
- Complaints
- Emergency
- Maintenance billing
- Resident dues
- Payment-proof upload
- Admin payment verification
- Payment history
- One community bank account
- Secure bank-account governance
- Basic unit ownership transfer

### Hominode Plus

Complete day-to-day community operations.

Everything in Essential plus:

- Online payments with automatic reconciliation
- Up to two community bank accounts
- Advanced audit reports
- Facility booking
- Events / polls
- Community messaging
- Domestic staff
- Parking
- Paid parking
- Community assets
- Marketplace
- Enhanced ownership transfer
- Reports / CSV

### Hominode Pro

Advanced management, finance, automation and intelligence.

Everything in Plus plus:

- Multiple bank accounts
- Advanced payment / settlement analytics
- Vendor and supplier management
- Supplier bills and payments
- Advanced asset management
- Advanced analytics
- WhatsApp notifications
- Automated bill reminders
- Email payment receipts
- Camera plate recognition / ANPR
- Advanced governance workflows
- Advanced integrations

---

## 15. Add-ons / Usage-Based Features

Potential features that may have separate usage charges:

- WhatsApp messages
- SMS messages
- ANPR / OCR processing
- Payment-gateway transaction fees
- Accounting integrations
- External API integrations
- Additional storage

The subscription entitlement enables the feature.
External/provider usage charges may still apply separately.
