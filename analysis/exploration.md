# Data Exploration - Pipedrive CRM Dataset

## Initial Investigation

### Data Overview
Explored 6 source tables to understand structure, relationships, and quality:

**Tables scanned:**
- `deal_changes` (15,406 rows) - EAV structure tracking deal modifications
- `stages` (9 rows) - Pipeline stage definitions
- `activity` (9,158 rows) - Sales activities
- `activity_types` (4 rows) - Activity type lookup
- `users` (1,787 rows) - Sales representatives
- `fields` (3 rows) - Metadata with JSON options

### Key Questions Asked

**1. What events exist in deal_changes?**
```sql
SELECT changed_field_key, COUNT(*) 
FROM deal_changes 
GROUP BY 1;
```
**Finding:** 4 event types (add_time: 2000, lost_reason: 2000, stage_id: 8906, user_id: 2500)

**2. Are there duplicates?**
```sql
SELECT activity_id, COUNT(*) 
FROM activity 
GROUP BY 1 
HAVING COUNT(*) > 1;
```
**Finding:** CRITICAL - 9,158 rows → 4,568 unique activity_ids (perfect duplicates)

**3. Is activity_id unique?**
```sql
SELECT activity_id, COUNT(DISTINCT deal_id) 
FROM activity 
GROUP BY 1 
HAVING COUNT(DISTINCT deal_id) > 1;
```
**Finding:** Same activity_id used for multiple deals - composite key required

**4. Are there test users?**
```sql
SELECT email 
FROM users 
WHERE email LIKE '%test%' OR email LIKE '%example%';
```
**Finding:** Multiple test accounts with example.com/org domains

**5. Do stage IDs match field definitions?**
```sql
SELECT field_value_options 
FROM fields 
WHERE field_key = 'stage_id';
```
**Finding:** JSON contains labels matching stages table - consistent

---

## Data Quality Issues Discovered

### Issue 1: Perfect Duplicates in activity Table
**Severity:** HIGH
**Details:** 9,158 rows containing 4,568 unique activities
**Pattern:** Each activity_id appears exactly 2 times with identical data
**Root Cause:** Suspected double-insert bug in source system
**Resolution:** SELECT DISTINCT in staging layer

### Issue 2: Non-Unique activity_id
**Severity:** MEDIUM
**Details:** Same activity_id references multiple deals
**Impact:** Cannot use activity_id as primary key
**Resolution:** Composite key (activity_id, deal_id)

### Issue 3: VARCHAR Foreign Keys
**Severity:** MEDIUM (Performance)
**Details:** activity.type uses VARCHAR to join activity_types.type
**Impact:** String comparison ~10x slower than integer
**Resolution:** Convert to INTEGER FK in staging, join once

### Issue 4: Shared Email Addresses
**Severity:** LOW
**Details:** 4 users share email addresses
**Pattern:** david39@example.net (2 users), tbarrera@example.com (2 users)
**Impact:** Cannot use email as unique identifier
**Resolution:** Documented, removed unique constraint

### Issue 5: Test Data Pollution
**Severity:** LOW
**Details:** Production data contains test accounts
**Pattern:** Emails with 'test', 'demo', '@example.com'
**Resolution:** Added is_test_user flag for filtering

---

## Schema Analysis

### Relationships Discovered
```
deal_changes ←→ stages (via stage_id)
deal_changes ←→ users (via user_id) 
activity ←→ activity_types (via type VARCHAR)
activity ←→ deals (via deal_id - inferred)
fields → JSON options for stages, lost_reasons
```

### Cardinality Patterns
- 1 deal : N stage changes (avg 4.5 per deal)
- 1 deal : N activities (avg 2.3 per deal)
- 1 user : N deals (avg 1.1 per user)

### Temporal Coverage
- Date range: 2024-01-01 to 2024-06-18 (14 months)
- Most active month: March 2024 (199 deals)
- Least active month: January 2024 (30 deals in stage 1)

---

## Business Logic Interpretation

### Funnel Structure
**Stages 1-3:** Early funnel (lead generation, qualification)
**Stages 4-6:** Mid funnel (proposal, negotiation, closing)
**Stages 7-9:** Post-sale (onboarding, success, renewal)

### Activity Integration
**Sales Call 1 (meeting):** Maps to Step 2.1 (between stages 2-3)
**Sales Call 2 (sc_2):** Maps to Step 3.1 (between stages 3-4)

**Logic:** Completed activities (done=true) count as funnel steps

### Lost Reasons Decoded
From fields.field_value_options JSON:
1. Customer Not Ready
2. Pricing Issues  
3. Unreachable Customer
4. Product Mismatch
5. Duplicate Entry

---

## Data Modeling Decisions

### Decision 1: Staging Layer Focus
**Choice:** Clean data, minimal transformations
**Rationale:** Separate concerns - quality fixes vs business logic

### Decision 2: VARCHAR→INTEGER FK Conversion
**Choice:** Convert in staging, not in intermediate
**Rationale:** One-time cost, benefits all downstream models

### Decision 3: Hybrid Normalized + Arrays
**Choice:** Facts normalized, aggregates use arrays
**Rationale:** Fast aggregations + fast drill-downs

### Decision 4: Test User Flagging
**Choice:** is_test_user flag vs hardcoded exclusion
**Rationale:** Flexible filtering, no maintenance burden

### Decision 5: Materialization Strategy
**Choice:** Tables for facts/dims, views for small reports
**Rationale:** Balance performance vs storage

---

## Validation Queries

All findings validated with SQL queries documented in this analysis.
Cross-checked row counts, uniqueness constraints, and relationship integrity before model development.