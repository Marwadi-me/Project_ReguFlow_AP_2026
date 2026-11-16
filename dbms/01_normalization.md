# DBMS Checkpoint 1 (CP1): Formal Database Normalization

**Project**: ReguFlow — Statutory Regulatory Compliance Automation Platform  
**Target Architecture**: ANSI SQL / PostgreSQL & SQLite Relational Storage  
**Author**: Shaurya Pratap Singh (`@sps-exe`), DBMS & Architecture Specialist  

---

## 1. Executive Summary & Normalization Objectives

In statutory compliance systems, regulatory filings govern high-stakes legal, environmental, and corporate governance actions. An unnormalized or poorly normalized relational schema introduces anomalies that jeopardize statutory fidelity:
- **Insertion Anomalies**: Inability to record statutory regulations, compliance rules, or regulatory authorities without first having a live filing submitted by an enterprise.
- **Update Anomalies**: Inconsistent enterprise turnover or officer caseloads across duplicate rows, leading to false regulatory penalties or inaccurate compliance scores.
- **Deletion Anomalies**: Inadvertently purging statutory regulation rules or enterprise registration histories when an old compliance filing record is archived or deleted.

This document demonstrates the formal mathematical normalization of the ReguFlow database schema from **Unnormalized Form (UNF)** through **1NF**, **2NF**, **3NF**, and into **Boyce-Codd Normal Form (BCNF)**. It establishes explicit Functional Dependencies (FDs), details anomaly resolutions at each stage, and provides formal proofs for **Lossless Join Decomposition** and **Dependency Preservation**.

---

## 2. Unnormalized Form (UNF)

### 2.1 Universal Relation Definition
Prior to normalization, legacy regulatory systems often store compliance submissions as a single monolithic flat record (or denormalized flat file exported from legacy portals). We define the universal relation schema as:

$$\begin{aligned}
\text{UNF\_RegulatoryRecord} = \{ & \text{EnterpriseRegNo}, \text{CompanyName}, \text{IndustrySector}, \text{ScaleCategory}, \\
& \text{AnnualTurnoverINR}, \text{ComplianceScore}, \text{EnterpriseCreatedAt}, \\
& \text{AuthorityCode}, \text{AuthorityName}, \text{JurisdictionLevel}, \text{ContactEmail}, \\
& \text{RegulationCode}, \text{RegulationTitle}, \text{RegulationDesc}, \text{EffectiveDate}, \\
& \text{FilingFrequency}, \text{RegulationIsActive}, \\
& \text{OfficerEmpCode}, \text{OfficerFullName}, \text{OfficerDesignation}, \text{OfficerEmail}, \text{OfficerActiveCases}, \\
& \text{FilingReference}, \text{FilingPeriod}, \text{FilingStatus}, \text{RiskScore}, \\
& \text{SubmissionDate}, \text{ReviewDate}, \\
& \{\text{ParameterKey}, \text{DeclaredNumericValue}, \text{DeclaredTextValue}, \text{UnitOfMeasure}, \text{VerifiedFlag}\}^*, \\
& \{\text{RuleCode}, \text{RuleParamKey}, \text{RuleOperator}, \text{ThresholdValue}, \text{Severity}, \text{PenaltyINR}, \text{RuleDesc}\}^*, \\
& \{\text{EvaluationOutcome}, \text{EvaluatedValue}, \text{ThresholdNumeric}, \text{DeltaValue}, \text{EvaluatedAt}\}^*, \\
& \{\text{ViolationSeverity}, \text{ViolationPenaltyINR}, \text{ResolutionStatus}, \text{RemedialActions}\}^*, \\
& \{\text{AuditAction}, \text{AuditPerformedBy}, \text{PreviousState}, \text{NewState}, \text{StateHash}, \text{AuditTimestamp}\}^* \}
\end{aligned}$$

Where $\{\dots\}^*$ denotes a repeating group (multivalued attribute set).

### 2.2 Tabular Sample of UNF Data
Notice the multivalued repeating groups within a single entity tuple:

| EnterpriseRegNo | CompanyName | AuthorityCode | RegulationCode | FilingReference | { ParameterKey, DeclaredVal, Unit } | { RuleCode, Threshold, Severity } |
|---|---|---|---|---|---|---|
| `U24100MH2018PTC123456` | Apex Chemicals Ltd | `SPCB-MH` | `ENV-AIR-2024` | `FIL-2026-00101` | `{(PM2_5, 45.2, ug/m3), (SO2, 68.0, ug/m3), (NOx, 72.5, ug/m3)}` | `{(R-AIR-01, 60.0, HIGH), (R-AIR-02, 80.0, MEDIUM)}` |
| `U72200DL2020PTC654321` | Nexus Tech Labs | `MCA-ROC` | `MCA-CORP-2025`| `FIL-2026-00102` | `{(BOARD_MEETINGS, 5, count), (INDEP_DIRECTORS, 2, count)}` | `{(R-CORP-01, 4, HIGH), (R-CORP-02, 2, MEDIUM)}` |

---

## 3. First Normal Form (1NF)

### 3.1 Transformation to 1NF
A relation $R$ is in **First Normal Form (1NF)** if and only if all attribute domains contain only atomic (indivisible) values, and there are no repeating groups.

To convert `UNF_RegulatoryRecord` into 1NF:
1. Flatten all repeating groups by disaggregating each element of the multivalued sets into distinct rows.
2. Form the primary composite key capable of uniquely identifying every atomic tuple:
   $$\text{Candidate Key (1NF)} = \{\text{EnterpriseRegNo}, \text{RegulationCode}, \text{FilingReference}, \text{ParameterKey}, \text{RuleCode}, \text{AuditTimestamp}\}$$

### 3.2 1NF Schema
In 1NF, every attribute holds an atomic scalar value. However, all enterprise, authority, regulation, officer, parameter, rule, and audit attributes coexist in a single relation `FLAT_1NF`.

### 3.3 Anomalies Evident in 1NF
1. **Insertion Anomaly**:
   - A regulatory authority (e.g., Central Pollution Control Board `CPCB-HQ`) creates a new regulation `ENV-NOISE-2026` with rules. This regulation **cannot** be stored in the database because `FilingReference`, `ParameterKey`, and `AuditTimestamp` are null, which violates the entity integrity constraint of the primary key.
2. **Update Anomaly**:
   - If `Apex Chemicals Ltd` changes its `AnnualTurnoverINR` or company name, this value must be updated across hundreds of individual rows (each parameter $\times$ rule $\times$ audit entry). A network interruption or partial update causes immediate data inconsistency.
3. **Deletion Anomaly**:
   - If the only filing `FIL-2026-00102` for `Nexus Tech Labs` is purged due to a retention cycle, all records of `Nexus Tech Labs` and its compliance history are inadvertently deleted.

---

## 4. Second Normal Form (2NF)

### 4.1 Functional Dependency (FD) Analysis on 1NF
Let $K$ be the composite candidate key:
$$K = \{\text{FilingReference}, \text{ParameterKey}, \text{RuleCode}, \text{AuditTimestamp}\}$$

We observe the following **Partial Functional Dependencies** (dependencies where non-prime attributes depend upon a strict subset of the candidate key):

1. **FD1 (Enterprise Partial Dependency)**:
   $$\text{EnterpriseRegNo} \rightarrow \text{CompanyName}, \text{IndustrySector}, \text{ScaleCategory}, \text{AnnualTurnoverINR}, \text{ComplianceScore}, \text{EnterpriseCreatedAt}$$
2. **FD2 (Authority & Regulation Partial Dependency)**:
   $$\text{RegulationCode} \rightarrow \text{AuthorityCode}, \text{AuthorityName}, \text{JurisdictionLevel}, \text{ContactEmail}, \text{RegulationTitle}, \text{RegulationDesc}, \text{EffectiveDate}, \text{FilingFrequency}, \text{RegulationIsActive}$$
3. **FD3 (Officer Partial Dependency)**:
   $$\text{OfficerEmpCode} \rightarrow \text{OfficerFullName}, \text{OfficerDesignation}, \text{OfficerEmail}, \text{OfficerActiveCases}, \text{AuthorityCode}$$
4. **FD4 (Compliance Filing Partial Dependency)**:
   $$\text{FilingReference} \rightarrow \text{EnterpriseRegNo}, \text{RegulationCode}, \text{OfficerEmpCode}, \text{FilingPeriod}, \text{FilingStatus}, \text{RiskScore}, \text{SubmissionDate}, \text{ReviewDate}$$
5. **FD5 (Filing Parameter Detail Partial Dependency)**:
   $$\{\text{FilingReference}, \text{ParameterKey}\} \rightarrow \text{DeclaredNumericValue}, \text{DeclaredTextValue}, \text{UnitOfMeasure}, \text{VerifiedFlag}$$
6. **FD6 (Compliance Rule Partial Dependency)**:
   $$\text{RuleCode} \rightarrow \text{RegulationCode}, \text{RuleParamKey}, \text{RuleOperator}, \text{ThresholdValue}, \text{Severity}, \text{PenaltyINR}, \text{RuleDesc}$$
7. **FD7 (Audit Log Partial Dependency)**:
   $$\{\text{FilingReference}, \text{AuditTimestamp}\} \rightarrow \text{AuditAction}, \text{AuditPerformedBy}, \text{PreviousState}, \text{NewState}, \text{StateHash}$$

### 4.2 Transformation to 2NF
A relation $R$ is in **Second Normal Form (2NF)** if and only if it is in 1NF and no non-prime attribute is functionally dependent on a proper subset of any candidate key (i.e., **no partial functional dependencies**).

We decompose `FLAT_1NF` by projecting each partial dependency into its own relation:

1. `R_ENTERPRISE_2NF` = $(\underline{\text{EnterpriseRegNo}}, \text{CompanyName}, \text{IndustrySector}, \text{ScaleCategory}, \text{AnnualTurnoverINR}, \text{ComplianceScore}, \text{EnterpriseCreatedAt})$
2. `R_REGULATION_AUTHORITY_2NF` = $(\underline{\text{RegulationCode}}, \text{RegulationTitle}, \text{RegulationDesc}, \text{EffectiveDate}, \text{FilingFrequency}, \text{RegulationIsActive}, \text{AuthorityCode}, \text{AuthorityName}, \text{JurisdictionLevel}, \text{ContactEmail})$
3. `R_OFFICER_2NF` = $(\underline{\text{OfficerEmpCode}}, \text{OfficerFullName}, \text{OfficerDesignation}, \text{OfficerEmail}, \text{OfficerActiveCases}, \text{AuthorityCode})$
4. `R_RULE_2NF` = $(\underline{\text{RuleCode}}, \text{RegulationCode}, \text{RuleParamKey}, \text{RuleOperator}, \text{ThresholdValue}, \text{Severity}, \text{PenaltyINR}, \text{RuleDesc})$
5. `R_FILING_2NF` = $(\underline{\text{FilingReference}}, \text{EnterpriseRegNo}, \text{RegulationCode}, \text{OfficerEmpCode}, \text{FilingPeriod}, \text{FilingStatus}, \text{RiskScore}, \text{SubmissionDate}, \text{ReviewDate})$
6. `R_FILING_DETAIL_2NF` = $(\underline{\text{FilingReference}, \text{ParameterKey}}, \text{DeclaredNumericValue}, \text{DeclaredTextValue}, \text{UnitOfMeasure}, \text{VerifiedFlag})$
7. `R_RULE_EVALUATION_2NF` = $(\underline{\text{FilingReference}, \text{RuleCode}}, \text{EvaluationOutcome}, \text{EvaluatedValue}, \text{ThresholdNumeric}, \text{DeltaValue}, \text{EvaluatedAt})$
8. `R_VIOLATION_2NF` = $(\underline{\text{FilingReference}, \text{RuleCode}}, \text{ViolationSeverity}, \text{ViolationPenaltyINR}, \text{ResolutionStatus}, \text{RemedialActions})$
9. `R_AUDIT_LOG_2NF` = $(\underline{\text{FilingReference}, \text{AuditTimestamp}}, \text{AuditAction}, \text{AuditPerformedBy}, \text{PreviousState}, \text{NewState}, \text{StateHash})$

### 4.3 Anomalies Remaining in 2NF
While partial dependencies are resolved, **Transitive Dependencies** remain:
- In `R_REGULATION_AUTHORITY_2NF`:
  $$\text{RegulationCode} \rightarrow \text{AuthorityCode} \quad \text{and} \quad \text{AuthorityCode} \rightarrow \{\text{AuthorityName}, \text{JurisdictionLevel}, \text{ContactEmail}\}$$
  Here, the regulatory authority's name, jurisdiction, and contact email depend transitively on `RegulationCode` through `AuthorityCode`.
- **Consequence**:
  - If an authority like `SPCB-MH` updates its contact email, every regulation issued by that authority must be updated.
  - A new authority cannot be recorded without registering a regulation first.

---

## 5. Third Normal Form (3NF)

### 5.1 Formal Definition of 3NF
A relation $R$ is in **Third Normal Form (3NF)** if and only if it is in 2NF and for every non-trivial functional dependency $X \rightarrow Y$ in $R$:
1. $X$ is a superkey of $R$, OR
2. $Y$ is a prime attribute (a member of some candidate key of $R$).

Equivalently, no non-prime attribute is transitively dependent on any candidate key.

### 5.2 Eliminating Transitive Dependencies
We isolate the transitive dependencies into dedicated relations:

1. **Authority Transitivity Elimination**:
   Extract `regulatory_authorities` out of `R_REGULATION_AUTHORITY_2NF`:
   - `regulatory_authorities`:
     $$\text{AuthorityCode} \rightarrow \text{AuthorityName}, \text{JurisdictionLevel}, \text{ContactEmail}$$
   - `regulations`:
     $$\text{RegulationCode} \rightarrow \text{AuthorityCode}, \text{RegulationTitle}, \text{RegulationDesc}, \text{EffectiveDate}, \text{FilingFrequency}, \text{RegulationIsActive}$$
   Here, `AuthorityCode` becomes a foreign key in `regulations` referencing `regulatory_authorities(AuthorityCode)`.

2. **Officer Authority Association**:
   In `compliance_officers`, `AuthorityCode` is a foreign key referencing `regulatory_authorities(AuthorityCode)`, ensuring no duplication of authority attributes.

3. **Evaluation and Violation Decoupling**:
   In statutory proceedings, a single filing evaluation may trigger multiple remedial actions or appeals over time. Decoupling evaluations (`rule_evaluations`) from legal penalties (`violations`) ensures that violation status transitions (`OPEN` $\rightarrow$ `APPEALED` $\rightarrow$ `RESOLVED`) do not overwrite the immutable rule evaluation outcome (`FAIL` with calculated $\Delta$).

---

## 6. Boyce-Codd Normal Form (BCNF)

### 6.1 Formal Definition of BCNF
A relation $R$ is in **Boyce-Codd Normal Form (BCNF)** if and only if for every non-trivial functional dependency $X \rightarrow Y$ in $R$, $X$ is a **superkey** of $R$.

BCNF is strictly stronger than 3NF: it eliminates the exception where $Y$ is a prime attribute when $X$ is not a superkey.

### 6.2 Evaluation of the 10 Decomposed Relations

We assign synthetic surrogate primary keys (`_id`) for high-performance integer B-Tree indexing, while preserving all natural candidate keys with `UNIQUE` constraints.

Let us evaluate every decomposed relation:

#### 1. `enterprises`
- **Attributes**: `(enterprise_id, registration_number, company_name, industry_sector, scale_category, annual_turnover_inr, compliance_score, created_at)`
- **Candidate Keys**: `CK1 = {enterprise_id}`, `CK2 = {registration_number}`
- **FDs**:
  - `enterprise_id -> registration_number, company_name, industry_sector, scale_category, annual_turnover_inr, compliance_score, created_at`
  - `registration_number -> enterprise_id, company_name, industry_sector, scale_category, annual_turnover_inr, compliance_score, created_at`
- **Determinant Check**: Both determinants `{enterprise_id}` and `{registration_number}` are superkeys.
- **Result**: **In BCNF**.

#### 2. `regulatory_authorities`
- **Attributes**: `(authority_id, authority_code, authority_name, jurisdiction_level, contact_email, created_at)`
- **Candidate Keys**: `CK1 = {authority_id}`, `CK2 = {authority_code}`
- **FDs**:
  - `authority_id -> authority_code, authority_name, jurisdiction_level, contact_email, created_at`
  - `authority_code -> authority_id, authority_name, jurisdiction_level, contact_email, created_at`
- **Determinant Check**: Both determinants are superkeys.
- **Result**: **In BCNF**.

#### 3. `regulations`
- **Attributes**: `(regulation_id, authority_id, regulation_code, title, description, effective_date, filing_frequency, is_active, created_at)`
- **Candidate Keys**: `CK1 = {regulation_id}`, `CK2 = {regulation_code}`
- **FDs**:
  - `regulation_id -> authority_id, regulation_code, title, description, effective_date, filing_frequency, is_active, created_at`
  - `regulation_code -> regulation_id, authority_id, title, description, effective_date, filing_frequency, is_active, created_at`
- **Determinant Check**: Both determinants are superkeys.
- **Result**: **In BCNF**.

#### 4. `compliance_rules`
- **Attributes**: `(rule_id, regulation_id, rule_code, parameter_key, operator, threshold_value, severity, penalty_inr, description, created_at)`
- **Candidate Keys**: `CK1 = {rule_id}`, `CK2 = {rule_code}`
- **FDs**:
  - `rule_id -> regulation_id, rule_code, parameter_key, operator, threshold_value, severity, penalty_inr, description, created_at`
  - `rule_code -> rule_id, regulation_id, parameter_key, operator, threshold_value, severity, penalty_inr, description, created_at`
- **Determinant Check**: Both determinants are superkeys.
- **Result**: **In BCNF**.

#### 5. `compliance_officers`
- **Attributes**: `(officer_id, authority_id, employee_code, full_name, designation, email, active_cases, created_at)`
- **Candidate Keys**: `CK1 = {officer_id}`, `CK2 = {employee_code}`, `CK3 = {email}`
- **FDs**:
  - `officer_id -> authority_id, employee_code, full_name, designation, email, active_cases, created_at`
  - `employee_code -> officer_id, authority_id, full_name, designation, email, active_cases, created_at`
  - `email -> officer_id, authority_id, employee_code, full_name, designation, active_cases, created_at`
- **Determinant Check**: All determinants are superkeys.
- **Result**: **In BCNF**.

#### 6. `compliance_filings`
- **Attributes**: `(filing_id, enterprise_id, regulation_id, reviewing_officer_id, filing_reference, filing_period, status, risk_score, submission_date, review_date, created_at)`
- **Candidate Keys**: `CK1 = {filing_id}`, `CK2 = {filing_reference}`
- **FDs**:
  - `filing_id -> enterprise_id, regulation_id, reviewing_officer_id, filing_reference, filing_period, status, risk_score, submission_date, review_date, created_at`
  - `filing_reference -> filing_id, enterprise_id, regulation_id, reviewing_officer_id, filing_period, status, risk_score, submission_date, review_date, created_at`
- **Determinant Check**: Both determinants are superkeys.
- **Result**: **In BCNF**.

#### 7. `filing_details`
- **Attributes**: `(detail_id, filing_id, parameter_key, declared_numeric_value, declared_text_value, unit_of_measure, verified_flag, created_at)`
- **Candidate Keys**: `CK1 = {detail_id}`, `CK2 = {filing_id, parameter_key}`
- **FDs**:
  - `detail_id -> filing_id, parameter_key, declared_numeric_value, declared_text_value, unit_of_measure, verified_flag, created_at`
  - `{filing_id, parameter_key} -> detail_id, declared_numeric_value, declared_text_value, unit_of_measure, verified_flag, created_at`
- **Determinant Check**: Both determinants are superkeys.
- **Result**: **In BCNF**.

#### 8. `rule_evaluations`
- **Attributes**: `(evaluation_id, filing_id, rule_id, outcome, evaluated_numeric_value, threshold_numeric_value, delta_value, evaluated_at)`
- **Candidate Keys**: `CK1 = {evaluation_id}`, `CK2 = {filing_id, rule_id}`
- **FDs**:
  - `evaluation_id -> filing_id, rule_id, outcome, evaluated_numeric_value, threshold_numeric_value, delta_value, evaluated_at`
  - `{filing_id, rule_id} -> evaluation_id, outcome, evaluated_numeric_value, threshold_numeric_value, delta_value, evaluated_at`
- **Determinant Check**: Both determinants are superkeys.
- **Result**: **In BCNF**.

#### 9. `violations`
- **Attributes**: `(violation_id, filing_id, rule_id, evaluation_id, severity, penalty_inr, resolution_status, remedial_actions, created_at)`
- **Candidate Keys**: `CK1 = {violation_id}`, `CK2 = {evaluation_id}`
- **FDs**:
  - `violation_id -> filing_id, rule_id, evaluation_id, severity, penalty_inr, resolution_status, remedial_actions, created_at`
  - `evaluation_id -> violation_id, filing_id, rule_id, severity, penalty_inr, resolution_status, remedial_actions, created_at`
- **Determinant Check**: Both determinants are superkeys.
- **Result**: **In BCNF**.

#### 10. `audit_logs`
- **Attributes**: `(log_id, filing_id, action, performed_by, previous_state, new_state, state_hash, created_at)`
- **Candidate Keys**: `CK1 = {log_id}`
- **FDs**:
  - `log_id -> filing_id, action, performed_by, previous_state, new_state, state_hash, created_at`
- **Determinant Check**: The determinant `{log_id}` is a superkey.
- **Result**: **In BCNF**.

---

## 7. Mathematical Proofs

### 7.1 Lossless Join Decomposition Proof

**Theorem (Lossless Join Decomposition)**:  
A decomposition of relation $R$ into $R_1$ and $R_2$ is a lossless join decomposition with respect to a set of functional dependencies $F$ if and only if at least one of the following functional dependencies is in $F^+$:
1. $R_1 \cap R_2 \rightarrow R_1$
2. $R_1 \cap R_2 \rightarrow R_2$

#### Proof for Decomposition of Regulations and Authorities:
- Let $R = \text{REGULATION\_AUTHORITY}(\text{RegCode}, \text{RegTitle}, \text{AuthCode}, \text{AuthName}, \text{Contact})$.
- Decompose into:
  - $R_1 = \text{regulations}(\underline{\text{RegCode}}, \text{RegTitle}, \text{AuthCode})$
  - $R_2 = \text{regulatory\_authorities}(\underline{\text{AuthCode}}, \text{AuthName}, \text{Contact})$
- Common attributes:
  $$R_1 \cap R_2 = \{\text{AuthCode}\}$$
- In $R_2$, $\text{AuthCode}$ is the primary key. Therefore:
  $$\text{AuthCode} \rightarrow \{\text{AuthCode}, \text{AuthName}, \text{Contact}\} \implies (R_1 \cap R_2) \rightarrow R_2$$
- Since $(R_1 \cap R_2) \rightarrow R_2 \in F^+$, the decomposition is **strictly lossless**.

#### Proof for Decomposition of Filings and Filing Details:
- Let $R = \text{FILING\_AND\_DETAILS}(\text{FilingRef}, \text{Status}, \text{ParamKey}, \text{DeclaredVal})$.
- Decompose into:
  - $R_1 = \text{compliance\_filings}(\underline{\text{FilingRef}}, \text{Status})$
  - $R_2 = \text{filing\_details}(\underline{\text{FilingRef}, \text{ParamKey}}, \text{DeclaredVal})$
- Common attributes:
  $$R_1 \cap R_2 = \{\text{FilingRef}\}$$
- In $R_1$, $\text{FilingRef}$ is the primary key. Therefore:
  $$\text{FilingRef} \rightarrow \{\text{FilingRef}, \text{Status}\} \implies (R_1 \cap R_2) \rightarrow R_1$$
- Since $(R_1 \cap R_2) \rightarrow R_1 \in F^+$, this decomposition is **strictly lossless**.

By induction over the finite sequence of binary decompositions performed, the entire 10-table relational schema guarantees **Lossless Join Decomposition**. No spurious tuples can be generated by natural joins across the schema.

---

### 7.2 Dependency Preservation Proof

**Theorem (Dependency Preservation)**:  
A decomposition $D = \{R_1, R_2, \dots, R_k\}$ of a relation $R$ with functional dependencies $F$ preserves dependencies if:
$$\left( \bigcup_{i=1}^k \pi_{R_i}(F) \right)^+ = F^+$$
where $\pi_{R_i}(F) = \{X \rightarrow Y \in F^+ \mid X \cup Y \subseteq R_i\}$.

#### Verification:
1. All enterprise functional dependencies ($\text{EnterpriseRegNo} \rightarrow \dots$) are enclosed within $R_{\text{enterprises}}$.
2. All authority functional dependencies ($\text{AuthorityCode} \rightarrow \dots$) are enclosed within $R_{\text{authorities}}$.
3. All regulation functional dependencies ($\text{RegulationCode} \rightarrow \dots$) are enclosed within $R_{\text{regulations}}$.
4. All rule functional dependencies ($\text{RuleCode} \rightarrow \dots$) are enclosed within $R_{\text{compliance\_rules}}$.
5. All officer functional dependencies ($\text{EmployeeCode} \rightarrow \dots$) are enclosed within $R_{\text{compliance\_officers}}$.
6. All filing functional dependencies ($\text{FilingReference} \rightarrow \dots$) are enclosed within $R_{\text{compliance\_filings}}$.
7. All parameter detail dependencies ($\{\text{FilingRef}, \text{ParamKey}\} \rightarrow \dots$) are enclosed within $R_{\text{filing\_details}}$.
8. All rule evaluation dependencies ($\{\text{FilingRef}, \text{RuleCode}\} \rightarrow \dots$) are enclosed within $R_{\text{rule\_evaluations}}$.
9. All violation dependencies ($\text{EvaluationId} \rightarrow \dots$) are enclosed within $R_{\text{violations}}$.
10. All audit log dependencies ($\text{LogId} \rightarrow \dots$) are enclosed within $R_{\text{audit\_logs}}$.

Every functional dependency in the canonical cover $F_c$ has its left-hand and right-hand side attributes located entirely within a single relation. Hence, **no inter-relational joins are required to enforce any functional dependency**. Referential integrity is preserved via Foreign Key constraints.

$$\therefore \text{The decomposition is strictly Dependency Preserving and in BCNF. } \blacksquare$$
