# Enpal Analytics Engineering Assessment

## Project Overview
Building a scalable sales funnel analytics layer for Pipedrive CRM data.

## Data Architecture

### Source Schema
- `deal_changes`: EAV model tracking all field changes (15,406 rows)
- `stages`: 9-stage sales pipeline definitions
- `activity`: Sales activities linked to deals (4,579 rows)
- `activity_types`: Activity categorization (Sales Call 1, Sales Call 2, etc.)

### dbt Model Layers

#### Staging Layer (`models/staging/`)
Light transformations - renaming, type casting, basic cleaning.
- `stg_pipedrive__deal_changes.sql` - Clean deal_changes
- `stg_pipedrive__stages.sql` - Clean stages lookup
- `stg_pipedrive__activities.sql` - Clean activity data
- `stg_pipedrive__activity_types.sql` - Clean activity types

#### Intermediate Layer (`models/intermediate/`)
Business logic - reusable transformations serving multiple downstream reports.
- `int_deals__stage_changes.sql` - Join deal_changes with stage names
- `int_deals__sales_calls.sql` - Identify Sales Call 1 & 2 events
- `int_deals__funnel_events.sql` - UNION all funnel entry points

#### Marts Layer (`models/marts/`)
Business-facing models - final aggregations.
- `rep_sales_funnel_monthly.sql` - Monthly funnel step counts

## Design Decisions

### Why This Architecture?
1. **Staging:** Keeps source logic separate - if Pipedrive schema changes, only staging models need updating
2. **Intermediate:** Reusable components - `int_deals__stage_changes` can serve future reports beyond just the monthly funnel
3. **Marts:** Business-specific aggregations - keeps reporting logic isolated

### Key Assumptions
- Deals entering multiple stages in the same month are counted once per stage
- Sales Call 1 = activities with `type = 'meeting'`
- Sales Call 2 = activities with `type = 'sc_2'`
- Month is based on `change_time` for stage changes, `due_to` for activities
- Only completed activities (`done = true`) count toward funnel sub-steps

## Running the Project

### Prerequisites
- Docker Desktop running
- Python 3.8+ with dbt-core and dbt-postgres installed
- PostgreSQL database running in Docker

### Setup Steps

1. **Start the database:**
```bash
   docker compose up
```
   Wait for "database system is ready to accept connections"

2. **Load data into PostgreSQL:**
```bash
   docker exec -i dbt_enpal_assessment-db-1 psql -U admin -d postgres -c "\COPY activity_types FROM '/raw_data/activity_types.csv' WITH (FORMAT csv, HEADER true);"
   docker exec -i dbt_enpal_assessment-db-1 psql -U admin -d postgres -c "\COPY stages FROM '/raw_data/stages.csv' WITH (FORMAT csv, HEADER true);"
   docker exec -i dbt_enpal_assessment-db-1 psql -U admin -d postgres -c "\COPY fields FROM '/raw_data/fields.csv' WITH (FORMAT csv, HEADER true);"
   docker exec -i dbt_enpal_assessment-db-1 psql -U admin -d postgres -c "\COPY users FROM '/raw_data/users.csv' WITH (FORMAT csv, HEADER true);"
   docker exec -i dbt_enpal_assessment-db-1 psql -U admin -d postgres -c "\COPY activity FROM '/raw_data/activity.csv' WITH (FORMAT csv, HEADER true);"
   docker exec -i dbt_enpal_assessment-db-1 psql -U admin -d postgres -c "\COPY deal_changes FROM '/raw_data/deal_changes.csv' WITH (FORMAT csv, HEADER true);"
```

3. **Test database connection:**
```bash
   dbt debug
```
   Should show "All checks passed!"

4. **Run the transformation pipeline:**
```bash
   dbt run
```
   Builds all 8 models in correct dependency order

5. **Run data quality tests:**
```bash
   dbt test
```
   Validates data integrity with 7 tests

6. **View the final report:**
```sql
   SELECT * FROM public_pipedrive_analytics.rep_sales_funnel_monthly 
   ORDER BY month, funnel_step;
```

### Project Structure
- **Staging:** 4 models cleaning raw data
- **Intermediate:** 3 models with business logic
- **Marts:** 1 final report model

### Results
- **Total rows in final report:** 128 (14 months × ~9 steps)
- **Date range:** January 2024 - February 2025
- **Build time:** ~2 seconds for full refresh