#!/bin/bash

set -e

echo "Waiting for database to be ready..."
sleep 5

for file in /raw_data/*.csv; do
    table_name=$(basename "$file" .csv)
    echo "Loading $table_name..."
    psql -h db -U admin -d postgres -c "\COPY $table_name FROM '$file' CSV HEADER"
done

echo "Data loading complete!"