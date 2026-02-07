\# Data Exploration Notes



\## Initial Investigation (2026-02-07)



\### Database Connection

\- Successfully connected to PostgreSQL 18.1 in Docker

\- Database: postgres

\- User: admin

\- Port: 5432



\### Source Data Summary



\#### deal\_changes (15,406 rows)

\- \*\*Structure:\*\* EAV model (Entity-Attribute-Value)

\- \*\*Key Field:\*\* `changed\_field\_key` - identifies which field changed

\- \*\*Date Field:\*\* `change\_time` - timestamp for monthly grouping

\- \*\*Critical Filter:\*\* WHERE changed\_field\_key = 'stage\_id' returns stage transitions

\- \*\*Data Quality:\*\* 

&nbsp; - Deals can skip stages (observed: Deal 881836 went stage 4→6, skipping Negotiation)

&nbsp; - new\_value contains stage\_id as text that needs casting to integer



\*\*Sample Data:\*\*

```

deal\_id | change\_time         | changed\_field\_key | new\_value

--------|---------------------|-------------------|----------

881836  | 2024-04-20 21:32:09 | stage\_id          | 1

881836  | 2024-05-02 21:32:09 | stage\_id          | 2

```



\#### stages (9 rows)

\- \*\*Primary Key:\*\* stage\_id

\- \*\*Stage Names:\*\* Match requirements exactly

\- \*\*No data quality issues observed\*\*



\*\*All Stages:\*\*

1\. Lead Generation

2\. Qualified lead

3\. Needs Assessment

4\. Proposal/Quote Preparation

5\. Negotiation

6\. Closing

7\. Implementation/Onboarding

8\. Follow-up/Customer Success

9\. Renewal/Expansion



\#### activity (4,579 rows)

\- \*\*Links to deals:\*\* via deal\_id foreign key

\- \*\*Type field:\*\* Maps to activity\_types (meeting, sc\_2, follow\_up, after\_close\_call)

\- \*\*Date Field:\*\* `due\_to` - timestamp for activity completion

\- \*\*Status Field:\*\* `done` (boolean) - whether activity completed

\- \*\*Key for Sub-Steps:\*\*

&nbsp; - Sales Call 1 = type 'meeting'

&nbsp; - Sales Call 2 = type 'sc\_2'



\#### activity\_types (4 rows)

\- Lookup table for activity categorization

\- Key types: Sales Call 1, Sales Call 2, Follow Up Call, After Close Call



\#### users (1,787 rows)

\- Sales team members

\- Not needed for funnel report but available for future analysis



\#### fields (4 rows)

\- Metadata table, not needed for current analysis



\### Key Insights for Modeling



1\. \*\*Funnel Events Come from 2 Sources:\*\*

&nbsp;  - Main stages: deal\_changes (where changed\_field\_key = 'stage\_id')

&nbsp;  - Sub-steps: activity (where type IN ('meeting', 'sc\_2'))



2\. \*\*Date Handling:\*\*

&nbsp;  - Stage changes: Use change\_time

&nbsp;  - Activities: Use due\_to

&nbsp;  - Need DATE\_TRUNC('month', ...) for monthly grouping



3\. \*\*Join Strategy:\*\*

&nbsp;  - deal\_changes.new\_value::int = stages.stage\_id

&nbsp;  - activity.type = activity\_types.type

&nbsp;  - activity.deal\_id = deal\_changes.deal\_id



4\. \*\*Assumptions to Validate:\*\*

&nbsp;  - Should we count only completed activities (done = true)?

&nbsp;  - How to handle deals in multiple stages same month? (Count once per stage)

&nbsp;  - Timezone of timestamps? (Appears to be UTC based on format)



\### Questions for Stakeholders

\- Should incomplete activities (done = false) count toward Sales Call sub-steps?

\- Are there stage transitions we should exclude (e.g., backward movements)?

\- Should we consider activity.assigned\_to\_user for any filtering?

