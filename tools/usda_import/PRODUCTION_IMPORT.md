# Production USDA Import Notes

These notes assume application deployment and database migrations are handled by the existing CI/CD path.

## Before Import

1. Deploy backend code that includes migrations `0009_usda_local_corpus.sql` and `0010_usda_search_indexes.sql`.
2. Apply migration `0011_reference_data_imports.sql` so USDA loads are auditable.
3. Confirm the production Postgres container is healthy.
4. Do not stop, restart, recreate, or reconfigure production containers from the import script.
5. Keep the production database volume intact. Do not run `docker compose down -v`.

## Import Mode

Production Postgres is not expected to be host-published, so run through `docker exec`:

```bash
USDA_IMPORT_MODE=docker-exec \
USDA_IMPORT_POSTGRES_CONTAINER=cal-tracker-postgres \
USDA_IMPORT_DATABASE_SCHEMA=cal_tracker_pro \
python tools/usda_import/import_usda.py load --target production --confirm-production
```

The script copies temporary CSV files into the Postgres container, loads them through `psql`, then removes the temporary files.

## Validation

Run the same database checks through the production container:

```bash
USDA_IMPORT_MODE=docker-exec \
USDA_IMPORT_POSTGRES_CONTAINER=cal-tracker-postgres \
USDA_IMPORT_DATABASE_SCHEMA=cal_tracker_pro \
python tools/usda_import/import_usda.py validate-db --target production --confirm-production
```

Expected checks:

- `duplicate_fdc_ids` is `0`.
- `SR Legacy`, `Foundation`, and `Branded` counts are non-zero.
- `food_portions` has imported rows.
- `reference_data_imports` has a recent `usda_fdc` row for the target schema.
- `EXPLAIN ANALYZE` uses `food_items_usda_normalized_name_trgm_idx`.

After import, verify backend health on the production host:

```bash
curl -s http://127.0.0.1:3102/v1/health
curl -s http://127.0.0.1:3201/v1/health
```

Expected response:

```json
{"ok":true,"service":"cal-tracker-backend"}
```
