# Hominode Community Bank Account Governance V1

Status: Working product specification  
Scope: Community bank-account setup, change control, approvals, visibility and audit

---

## 1. Purpose

Hominode stores community bank-account details used for collections, disbursements, reserves, facilities, parking and other community financial operations.

Because these details are sensitive and can directly affect where community money is sent, no single user should be able to add or change an active community bank account without independent approval.

This specification defines the mandatory governance model.

---

## 2. Core Principle

Every bank-account addition or sensitive modification must pass through a minimum 3-level approval workflow.

This requirement applies to all subscription plans:

- Hominode Essential
- Hominode Plus
- Hominode Pro

This is a security and governance control, not a premium feature.

Advanced/custom approval workflow configuration may later be Pro-only, but the mandatory 3-level bank-account approval remains available on every plan.

---

## 3. Community Bank Account Ownership

Bank accounts belong to the community.

They do not belong to:

- the current community admin
- a resident
- a security user
- a Super Admin

Changing community administrators must not affect existing approved bank accounts.

All account records must remain associated with the community.

---

## 4. Supported Account Types

### Essential

Maximum:

- 1 active community bank account

Typical role:

- Collection Account

### Plus

Maximum:

- 2 active community bank accounts

Recommended roles:

1. Collection Account
2. Disbursement / Expense Account

### Pro

Multiple active bank accounts.

Possible roles:

- Collection Account
- Disbursement / Expense Account
- Reserve Fund
- Sinking Fund
- Parking Collection Account
- Facility Collection Account
- Other approved community account types

---

## 5. Minimum Bank Account Data

Each approved bank-account record should support:

- account name
- bank name
- branch name
- account number
- account type / purpose
- country
- currency
- optional SWIFT / BIC
- optional routing / bank code
- optional QR/payment identifier
- optional notes
- active/inactive status
- createdAt
- createdBy
- approvedAt
- approvedBy
- lastUpdatedAt
- lastUpdatedBy

Sensitive values should be stored and displayed according to role-based permissions.

---

## 6. Proposed Change Model

An active bank-account record must not be directly overwritten when a sensitive change is requested.

Instead:

1. User creates a bank-account proposal.
2. Proposed values are stored separately from the active approved account.
3. Proposal enters `pending_approval`.
4. Required approvers review the proposal.
5. After all required approvals are completed, the proposal becomes effective.
6. Active account is updated atomically.
7. Previous state is preserved in immutable history.

This applies to:

- new bank account
- account-number change
- bank-name change
- account-holder-name change
- branch change
- routing/SWIFT change
- account-purpose change
- reactivation
- account replacement

---

## 7. Approval Levels

Minimum required approval levels:

### Level 1 — Community Admin

An authorized community administrator verifies the operational requirement.

### Level 2 — Designated Owner / Authorized Financial Representative

A distinct authorized person verifies the legitimacy of the financial account.

Examples:

- property owner representative
- treasurer
- finance officer
- designated association owner representative

### Level 3 — Association / Committee Representative

A distinct authorized committee or association representative provides final governance approval.

Examples:

- president
- secretary
- committee member
- board representative

---

## 8. Distinct Approver Requirement

The three approval levels must represent independent approval.

The same person must not satisfy multiple required approval levels for the same proposal.

Example:

A user who holds both Admin and Committee Member permissions must not approve both Level 1 and Level 3 for the same bank-account proposal.

Each required approval must be associated with a distinct user identity.

---

## 9. Proposer Restriction

The proposer may create the change request but must not be able to unilaterally activate it.

Recommended rule:

- proposer may approve only if their configured governance role allows it
- proposer approval must never eliminate the requirement for independent approvers
- at least two other distinct authorized users must participate

For stronger security, production configuration may later prohibit proposer approval completely.

---

## 10. Approval Sequence

Default sequence:

1. Level 1 approval
2. Level 2 approval
3. Level 3 approval
4. Activation

V1 should use sequential approval unless later requirements justify parallel approval.

A later level must not approve before the previous required level is complete.

---

## 11. Proposal Statuses

Recommended statuses:

- `draft`
- `pending_level_1`
- `pending_level_2`
- `pending_level_3`
- `approved`
- `activated`
- `rejected`
- `cancelled`
- `expired`

Optional future status:

- `returned_for_changes`

---

## 12. Rejection

Any authorized approver may reject the proposal at their assigned level.

Rejection must require:

- rejection reason
- rejectedBy
- rejectedAt
- approval level

Rejected proposals must not alter the active bank account.

Rejected proposals remain permanently available in audit history.

A rejected proposal should normally require a new proposal rather than modifying the rejected record in place.

---

## 13. Cancellation

A proposal may be cancelled before activation if the requester or authorized administrator determines it is no longer required.

Cancellation must record:

- cancelledBy
- cancelledAt
- cancellationReason

Already activated changes cannot be cancelled.

They require a new change proposal.

---

## 14. Immutable Audit History

Every bank-account action must create an immutable audit entry.

Examples:

- proposal created
- proposal edited before submission
- proposal submitted
- Level 1 approved
- Level 2 approved
- Level 3 approved
- proposal rejected
- proposal cancelled
- proposal activated
- account deactivated
- account reactivated

Each audit record should include:

- communityId
- bankAccountId
- proposalId
- action
- actorId
- actor role/personality
- timestamp
- approval level where applicable
- reason/comment where applicable
- previous values or secure change summary
- proposed/new values or secure change summary
- request metadata where appropriate

Audit entries must not be editable or deletable by normal community users.

---

## 15. Sensitive Data Protection

Sensitive banking data must be protected.

Recommended rules:

- full account number must not be exposed to unauthorized users
- logs must not contain full sensitive account numbers
- audit summaries should use masked values where possible
- backend authorization must control access, not UI hiding alone

Example masked display:

`********1234`

---

## 16. General User Visibility

General authorized community users may need to see approved payment account information for paying maintenance or community charges.

Possible visible fields:

- account name
- bank name
- account purpose
- masked or full approved account number depending on final policy
- approved QR/payment identifier
- payment instructions

Pending bank-account changes must never be shown as active payment instructions.

Only the last approved and activated account must be used for resident-facing payment information.

---

## 17. Pending Account Changes

While a change is pending:

- existing approved account remains active
- resident payment instructions continue to use existing approved account
- pending details are visible only to authorized governance users
- pending change must be clearly labeled as not active

Activation occurs only after the complete approval chain succeeds.

---

## 18. Account Deactivation

Deactivating an active bank account is also a sensitive financial action.

Recommended rule:

Deactivation requires the same approval workflow as an account-number change.

Reason:

Removing a valid community collection or expense account can affect financial operations.

---

## 19. Emergency Changes

V1 should not allow a single-user emergency bypass.

If an urgent change is required, the normal approval workflow must still be completed.

A future emergency governance workflow may be considered only if it maintains multiple independent approvals and enhanced audit logging.

---

## 20. Running Balance

Running balance is a separate sensitive capability.

Current policy:

- general residents must never see bank running balance
- security users must never see bank running balance

Exact permissions for:

- community admin
- treasurer
- finance representative
- committee members
- Super Admin

remain TBD.

Running balance should not be implemented until these permissions are finalized.

---

## 21. Super Admin Access

Super Admin manages platform-level configuration but should not automatically function as a community financial approver.

Super Admin may require access for:

- support
- audit investigation
- community setup
- subscription enforcement
- security investigation

Any Super Admin access to sensitive bank-account information should itself be auditable.

Future decision required:

Whether Super Admin can participate in exceptional approval recovery.

---

## 22. Suggested Backend Collections

Possible structure:

```text
communities/{communityId}/bankAccounts/{bankAccountId}