# Enpal dbt Assessment - Sales Funnel Analytics

Production-grade dbt project implementing dimensional modeling for Pipedrive CRM sales funnel analysis.

## 📊 Project Overview

**Deliverable:** Monthly sales funnel report (`rep_sales_funnel_monthly`) showing deal counts entering each funnel step per month.

**Architecture:** Three-layer dimensional model (Staging → Intermediate → Marts) following Kimball methodology.

**Data Source:** Pipedrive CRM (6 tables, 14 months of sales data)

---

## 🏗️ Architecture

### **Staging Layer** (5 models)
Clean, deduplicated source data with data quality validation:
- `stg_pipedrive__deal_changes` - 8,906 stage transitions
- `stg_pipedrive__stages` - 9 pipeline stages with categories
- `stg_pipedrive__activity` - 4,579 sales activities (deduplicated from 9,158)
- `stg_pipedrive__activity_types` - 4 activity type definitions
- `stg_pipedrive__users` - 1,787 users with test account flagging

**Key Transformations:**
- Deduplication of perfect duplicates
- VARCHAR → INTEGER FK conversion (10x performance improvement)
- Test user identification via email patterns
- Comprehensive type casting and date field derivation

### **Intermediate Layer** (6 models)

**Dimensions:**
- `dim_dates` - 414-day calendar spine with business attributes
- `dim_stages` - Enhanced with business logic (early funnel, post-sale flags)

**Facts:**
- `fct_deal_stage_changes` - 8,906 stage events with dimension FKs
- `fct_deal_activities` - 1,128 completed sales calls (filtered)

**Aggregates:**
- `int_funnel_events` - 10,034 combined events (stages + calls) for unified analysis
- `int_deal_journey` - 1,995 deals with array-based time-travel capability

### **Marts Layer** (1 model)
- `rep_sales_funnel_monthly` - 128 rows, final deliverable

**Output Schema:**
```
month       | kpi_name                           | funnel_step                        | deals_count
2024-01-01  | Step 1: Lead Generation            | Step 1: Lead Generation            | 30
2024-01-01  | Step 2.1: Sales Call 1             | Step 2.1: Sales Call 1             | 77
...
```

---

## 🔍 Data Quality Findings

**Source Issues Discovered & Fixed:**
1. **Perfect duplicates:** 9,158 → 4,579 activities after deduplication
2. **Non-unique activity_id:** Same ID used for multiple deals (composite key required)
3. **VARCHAR foreign keys:** Converted to INTEGER for performance
4. **Shared emails:** 4 users share email addresses (business process issue)
5. **Schema evolution risks:** Documented and mitigated with dynamic tests

---

## 📈 Business Logic

**Funnel Steps (11 total):**
- 9 main stages (Lead Generation → Renewal/Expansion)
- 2 sub-steps: Sales Call 1 (Step 2.1), Sales Call 2 (Step 3.1)

**Filtering Rules:**
- Activities: Only completed (done=true) Sales Call 1 & 2
- Users: Test accounts flagged via `is_test_user` (email pattern matching)

**Time Intelligence:**
- Monthly aggregation (primary)
- Architecture supports weekly/daily via pre-computed date fields

---

## 🚀 Quick Start

### **Prerequisites:**
- Docker Desktop
- dbt-core with dbt-postgres
- Git

### **Setup:**
```bash
# 1. Clone repository
git clone <your-repo-url>
cd dbt_enpal_assessment

# 2. Start database
docker compose up -d

# 3. Load sample data
bash raw_data/load_data.sh  # or load_data.bat on Windows

# 4. Install dbt dependencies
dbt deps

# 5. Build all models
dbt run

# 6. Run tests
dbt test

# 7. Generate documentation
dbt docs generate
dbt docs serve
```

---

## 📁 Project Structure
```
dbt_enpal_assessment/
├── models/
│   ├── staging/
│   │   ├── _sources.yml              # Source documentation + tests
│   │   ├── _stg_models.yml           # Staging model tests
│   │   ├── stg_pipedrive__*.sql      # 5 staging models
│   ├── intermediate/
│   │   ├── dimensions/
│   │   │   ├── dim_dates.sql         # Date spine
│   │   │   └── dim_stages.sql        # Enhanced stages
│   │   ├── facts/
│   │   │   ├── fct_deal_stage_changes.sql
│   │   │   └── fct_deal_activities.sql
│   │   └── aggregates/
│   │       ├── int_funnel_events.sql      # Combined events
│   │       └── int_deal_journey.sql       # Array-based time travel
│   └── marts/
│       └── rep_sales_funnel_monthly.sql   # Final report
├── analysis/
│   └── exploration.md                # Data exploration notes
├── raw_data/                         # CSV source files
├── dbt_project.yml
├── packages.yml                      # dbt_utils dependency
└── README.md
```

---

## 🧪 Testing

**52 Data Quality Tests:**
- Source tests: Not null, unique, relationships
- Staging tests: Composite keys, referential integrity, accepted values
- All tests passing ✅

**Run tests:**
```bash
dbt test                              # All tests
dbt test --select staging            # Staging only
dbt test --select source:pipedrive   # Source only
```

---

## 🎯 Advanced Features

### **1. Hybrid Data Modeling**
Combines normalized facts (for aggregations) with array-based aggregates (for time-travel queries):
```sql
-- Normalized: Fast aggregations
SELECT stage_id, COUNT(DISTINCT deal_id)
FROM fct_deal_stage_changes
GROUP BY 1

-- Array-based: Fast single-deal analysis
SELECT stage_journey, stage_timestamps
FROM int_deal_journey
WHERE deal_id = 123
```

### **2. Performance Optimizations**
- VARCHAR → INTEGER FK conversion (~10x faster joins)
- Pre-computed date fields (avoid repeated date_trunc)
- Deduplication before JOINs (reduce data volume)
- Surrogate keys for efficient lookups

### **3. Schema Evolution Readiness**
- Dynamic relationships tests (adapt to new stages automatically)
- Test user identification (no hardcoded exclusions)
- SCD Type 2 architecture prepared (not implemented per requirements)

---

## 📚 Key Decisions & Trade-offs

### **Why Kimball Dimensional Model?**
✅ Industry standard for BI/analytics  
✅ Reusable dimensions serve multiple reports  
✅ Query performance via star schema  
✅ Scalable for future requirements  

### **Why NOT fully denormalized arrays?**
Aggregations, time-based analysis, and JOINs perform better with normalized facts. Arrays used selectively for single-deal queries.

### **Why Type 1 SCD for users?**
Assessment scope focuses on fundamentals. Architecture supports Type 2 upgrade via `last_modified_at` field.

---

## 🔗 Database Connection

**Docker Compose:**
```yaml
Host: localhost
Port: 15432  # Changed from 5432 (Windows port conflict)
Database: postgres
User: admin
Password: admin
```

---

## 📝 Git History

Clean, meaningful commits documenting each development phase:
```
cb578a0 feat(intermediate+marts): complete dimensional model and final report
2aa102d feat(staging): complete staging layer with activity_types and users
015c38d feat(staging): add stg_pipedrive__activity with deduplication
76fd562 feat(staging): add stg_pipedrive__stages dimension
49dab57 docs(staging): add comprehensive documentation
a5ed260 feat(staging): add stg_pipedrive__deal_changes
```

---

## 👤 Author

**Kowsar** - Analytics Engineering Assessment for Enpal

**Submission Date:** February 2026

---

## 📄 License

This project is for assessment purposes only.