# Enpal dbt Assessment - Sales Funnel Analytics

Production-grade dbt project implementing Kimball dimensional modeling for Pipedrive CRM analysis.

## Project Overview

**Deliverable:** `rep_sales_funnel_monthly` - Monthly deal counts per funnel step (128 rows, 11 steps)

**Architecture:** Three-layer dimensional model (Staging → Intermediate → Marts)

**Data:** Pipedrive CRM (6 tables, 14 months, 1,995 deals)

---

## Architecture

### Staging Layer (5 models) - Data Quality Foundation

- **deal_changes**: 8,906 stage transitions (deduped, type-cast)
- **stages**: 9 pipeline stages with business categorization
- **activity**: 4,579 sales activities (50% deduplication, VARCHAR→INTEGER FK)
- **activity_types**: 4 lookup definitions
- **users**: 1,787 reps with test account flagging

**Fixes Applied:** Perfect duplicate removal, non-unique ID handling, schema optimization, shared email detection

### Intermediate Layer (6 models) - Reusable Business Logic

**Dimensions:**
- `dim_dates` (414 days) - Calendar spine
- `dim_stages` (9 stages) - Early/mid/late funnel flags

**Facts:**
- `fct_deal_stage_changes` (8,906 events) - Normalized stage transitions
- `fct_deal_activities` (1,128 calls) - Completed Sales Call 1 & 2 only

**Aggregates:**
- `int_funnel_events` (10,034 events) - Unified stages + activities
- `int_deal_timeline` (1,995 deals) - Array-based time-travel capability

### Marts Layer (2 models) - Business Deliverables

- `rep_sales_funnel_monthly` (table) - Primary deliverable
- `rep_lost_reasons` (view) - Loss pattern analysis

---

## Performance Validation

**Raw Query (Optimized):** 22.75 ms execution, 1006 kB memory, 207 buffer hits

**dbt Mart Query:** 0.16 ms execution, 35 kB memory, 5 buffer hits

**Improvement:** 47x faster via pre-aggregation

---

## Intermediate Layer Value

**Supports Multiple Use Cases:**
- Monthly/weekly/daily funnel reports (reuse `int_funnel_events`)
- Deal lifecycle reconstruction (array time-travel via `int_deal_timeline`)
- Loss analysis (reason categorization + temporal patterns)
- Stage conversion rates (`int_stage_transitions` - 46 paths detected)
- Backward transition detection (regression alerts)
- Time-in-stage performance metrics

**Architecture Coverage:**
- Dimensional foundation: Centralized business logic (stage categories, date attributes)
- Transaction facts: Normalized for aggregations (8,906 + 1,128 events)
- Analytical aggregates: Arrays for drill-down, pre-computed for speed

---

## Quick Start
```bash
# Setup
docker compose up -d
bash raw_data/load_data.sh  # or .bat on Windows
dbt deps && dbt run && dbt test

# Verify
dbt docs generate && dbt docs serve
```

---

## Data Quality

**52 tests passing** - Unique keys, referential integrity, not null, composite constraints, accepted values

**Key Decisions:**
- Dynamic relationships tests (schema evolution ready)
- Composite unique keys where needed (activity_id + deal_id)
- Test user identification (email pattern matching, no hardcoding)

---

## Project Structure
```
models/
├── staging/          # 5 models - Clean source data
├── intermediate/     # 6 models - Reusable dimensions/facts/aggregates
└── marts/            # 2 models - Business deliverables
```

---

## Technical Highlights

**Performance:** VARCHAR→INTEGER FK (10x faster joins), pre-computed dates, early deduplication, strategic materialization (tables for facts, views for reports)

**Data Quality:** Source duplicate detection (50% reduction), non-unique ID patterns, schema design fixes, comprehensive testing

**Scalability:** Kimball star schema, SCD Type 2 ready, dynamic test patterns, incremental-capable facts

---

## Deliverable Schema
```sql
month       | kpi_name                | funnel_step             | deals_count
2024-01-01  | Step 1: Lead Generation | Step 1: Lead Generation | 30
2024-01-01  | Step 2.1: Sales Call 1  | Step 2.1: Sales Call 1  | 77
```

**Output:** 128 rows across 14 months, 11 funnel steps (9 stages + 2 sub-steps)

---

## Submission Details

**Author:** Kowsar

**Date:** February 2026

**Repository:** https://github.com/KowsarAsghari/dbt_enpal_assessment

**Transparency Note:** Claude AI (Anthropic) was used as a thought partner throughout this project for architectural discussions, code review, optimization suggestions, and debugging assistance. All design decisions, problem-solving approaches, and implementations remain my original work.

---

## License

This project is for assessment purposes only.