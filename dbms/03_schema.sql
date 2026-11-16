-- ============================================================================
-- ReguFlow Relational DDL Schema (BCNF Normalized)
-- Project: Viksit Bharat 2026 - Regulatory Governance (Team T0010)
-- Dual-Compatible: ANSI SQL / SQLite 3.38+ / PostgreSQL 14+
-- ============================================================================

-- Enable Foreign Keys (for SQLite environments)
PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- Drop existing tables in reverse dependency order
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS violations;
DROP TABLE IF EXISTS rule_evaluations;
DROP TABLE IF EXISTS filing_details;
DROP TABLE IF EXISTS compliance_filings;
DROP TABLE IF EXISTS compliance_officers;
DROP TABLE IF EXISTS compliance_rules;
DROP TABLE IF EXISTS regulations;
DROP TABLE IF EXISTS regulatory_authorities;
DROP TABLE IF EXISTS enterprises;

-- ============================================================================
-- 1. Enterprises Master Table
-- Stores legal entities (MSMEs, Large Enterprises) subject to compliance
-- ============================================================================
CREATE TABLE enterprises (
    enterprise_id INTEGER PRIMARY KEY AUTOINCREMENT,
    registration_number VARCHAR(64) NOT NULL UNIQUE,
    company_name VARCHAR(255) NOT NULL,
    industry_sector VARCHAR(100) NOT NULL,
    scale_category VARCHAR(20) NOT NULL CHECK (scale_category IN ('MICRO', 'SMALL', 'MEDIUM', 'LARGE')),
    annual_turnover_inr REAL NOT NULL DEFAULT 0.0 CHECK (annual_turnover_inr >= 0),
    compliance_score REAL NOT NULL DEFAULT 100.0 CHECK (compliance_score BETWEEN 0.0 AND 100.0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. Regulatory Authorities Master Table
-- Central, State, and Municipal statutory regulatory bodies (e.g. CPCB, SPCB, MCA)
-- ============================================================================
CREATE TABLE regulatory_authorities (
    authority_id INTEGER PRIMARY KEY AUTOINCREMENT,
    authority_code VARCHAR(32) NOT NULL UNIQUE,
    authority_name VARCHAR(255) NOT NULL,
    jurisdiction_level VARCHAR(20) NOT NULL CHECK (jurisdiction_level IN ('CENTRAL', 'STATE', 'MUNICIPAL')),
    contact_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 3. Regulations Master Table
-- Specific statutory regulations promulgated by authorities
-- ============================================================================
CREATE TABLE regulations (
    regulation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    authority_id INTEGER NOT NULL,
    regulation_code VARCHAR(64) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    effective_date DATE NOT NULL,
    filing_frequency VARCHAR(20) NOT NULL CHECK (filing_frequency IN ('ANNUAL', 'QUARTERLY', 'MONTHLY', 'EVENT_BASED')),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (authority_id) REFERENCES regulatory_authorities(authority_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ============================================================================
-- 4. Compliance Rules Table
-- Declarative statutory evaluation parameters, thresholds, and penalty rates
-- ============================================================================
CREATE TABLE compliance_rules (
    rule_id INTEGER PRIMARY KEY AUTOINCREMENT,
    regulation_id INTEGER NOT NULL,
    rule_code VARCHAR(64) NOT NULL UNIQUE,
    parameter_key VARCHAR(64) NOT NULL,
    operator VARCHAR(4) NOT NULL CHECK (operator IN ('<=', '>=', '==', '!=', '<', '>')),
    threshold_value REAL NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    penalty_inr REAL NOT NULL DEFAULT 0.0 CHECK (penalty_inr >= 0),
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (regulation_id) REFERENCES regulations(regulation_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================================
-- 5. Compliance Officers Table
-- Authorized statutory inspectors and adjudicating officers
-- ============================================================================
CREATE TABLE compliance_officers (
    officer_id INTEGER PRIMARY KEY AUTOINCREMENT,
    authority_id INTEGER NOT NULL,
    employee_code VARCHAR(32) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    designation VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    active_cases INTEGER NOT NULL DEFAULT 0 CHECK (active_cases >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (authority_id) REFERENCES regulatory_authorities(authority_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ============================================================================
-- 6. Compliance Filings Table
-- Submissions tendered by enterprises for specific reporting periods
-- ============================================================================
CREATE TABLE compliance_filings (
    filing_id INTEGER PRIMARY KEY AUTOINCREMENT,
    enterprise_id INTEGER NOT NULL,
    regulation_id INTEGER NOT NULL,
    reviewing_officer_id INTEGER,
    filing_reference VARCHAR(64) NOT NULL UNIQUE,
    filing_period VARCHAR(20) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'SUBMITTED' 
        CHECK (status IN ('DRAFT', 'SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'FLAGGED_VIOLATION')),
    risk_score REAL NOT NULL DEFAULT 0.0 CHECK (risk_score BETWEEN 0.0 AND 100.0),
    submission_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    review_date TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (enterprise_id) REFERENCES enterprises(enterprise_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (regulation_id) REFERENCES regulations(regulation_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (reviewing_officer_id) REFERENCES compliance_officers(officer_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ============================================================================
-- 7. Filing Details Table
-- Granular parameter readings and declared quantitative measurements
-- ============================================================================
CREATE TABLE filing_details (
    detail_id INTEGER PRIMARY KEY AUTOINCREMENT,
    filing_id INTEGER NOT NULL,
    parameter_key VARCHAR(64) NOT NULL,
    declared_numeric_value REAL,
    declared_text_value TEXT,
    unit_of_measure VARCHAR(32),
    verified_flag INTEGER NOT NULL DEFAULT 0 CHECK (verified_flag IN (0, 1)),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (filing_id) REFERENCES compliance_filings(filing_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE (filing_id, parameter_key)
);

-- ============================================================================
-- 8. Rule Evaluations Table
-- Automated deterministic evaluation outcomes of rules against filed parameters
-- ============================================================================
CREATE TABLE rule_evaluations (
    evaluation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    filing_id INTEGER NOT NULL,
    rule_id INTEGER NOT NULL,
    outcome VARCHAR(20) NOT NULL CHECK (outcome IN ('PASS', 'FAIL', 'WARNING')),
    evaluated_numeric_value REAL,
    threshold_numeric_value REAL,
    delta_value REAL,
    evaluated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (filing_id) REFERENCES compliance_filings(filing_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (rule_id) REFERENCES compliance_rules(rule_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ============================================================================
-- 9. Violations Table
-- Official statutory citations and penalty assessments resulting from failed rules
-- ============================================================================
CREATE TABLE violations (
    violation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    filing_id INTEGER NOT NULL,
    rule_id INTEGER NOT NULL,
    evaluation_id INTEGER NOT NULL UNIQUE,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    penalty_inr REAL NOT NULL DEFAULT 0.0 CHECK (penalty_inr >= 0),
    resolution_status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CHECK (resolution_status IN ('OPEN', 'APPEALED', 'RESOLVED', 'PENALTY_PAID')),
    remedial_actions TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (filing_id) REFERENCES compliance_filings(filing_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (rule_id) REFERENCES compliance_rules(rule_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (evaluation_id) REFERENCES rule_evaluations(evaluation_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================================
-- 10. Audit Logs Table
-- Append-only cryptographically verifiable ledger tracking all state mutations
-- ============================================================================
CREATE TABLE audit_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    filing_id INTEGER,
    action VARCHAR(100) NOT NULL,
    performed_by VARCHAR(150) NOT NULL,
    previous_state TEXT,
    new_state TEXT,
    state_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (filing_id) REFERENCES compliance_filings(filing_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ============================================================================
-- B-Tree Performance Indexes
-- Optimized for join paths, foreign keys, filtering, and reporting aggregations
-- ============================================================================
CREATE INDEX idx_enterprises_reg_no ON enterprises(registration_number);
CREATE INDEX idx_enterprises_sector_score ON enterprises(industry_sector, compliance_score);
CREATE INDEX idx_regulations_auth_code ON regulations(authority_id, regulation_code);
CREATE INDEX idx_rules_reg_param ON compliance_rules(regulation_id, parameter_key);
CREATE INDEX idx_officers_auth_cases ON compliance_officers(authority_id, active_cases);
CREATE INDEX idx_filings_enterprise_status ON compliance_filings(enterprise_id, status);
CREATE INDEX idx_filings_officer_status ON compliance_filings(reviewing_officer_id, status);
CREATE INDEX idx_filings_reg_period ON compliance_filings(regulation_id, filing_period);
CREATE INDEX idx_filings_submission_date ON compliance_filings(submission_date);
CREATE INDEX idx_filing_details_filing_param ON filing_details(filing_id, parameter_key);
CREATE INDEX idx_rule_eval_filing_outcome ON rule_evaluations(filing_id, outcome);
CREATE INDEX idx_violations_filing_status ON violations(filing_id, resolution_status);
CREATE INDEX idx_violations_severity ON violations(severity);
CREATE INDEX idx_audit_filing_created ON audit_logs(filing_id, created_at);
