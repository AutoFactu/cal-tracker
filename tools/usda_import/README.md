# USDA Import Tool

Isolated Python tooling for building and loading a local USDA FoodData Central corpus.

## Data Sources

The tool downloads official FoodData Central CSV archives:

- Foundation Foods 04/2026
- Branded Foods 04/2026
- SR Legacy 04/2018

Raw ZIPs, reduced Parquet tables, normalized output, manifests, and validation reports are written under `data/usda/`, which is intentionally ignored by Git.

## Local Usage

```bash
cd /home/javier/dev/cal-tracker
python -m venv .venv-usda
. .venv-usda/bin/activate
pip install -r tools/usda_import/requirements.txt

export USDA_IMPORT_DATABASE_URL=postgres://cal_tracker:cal_tracker@localhost:5432/cal_tracker
export USDA_IMPORT_DATABASE_SCHEMA=public
python tools/usda_import/import_usda.py run --target local
python tools/usda_import/import_usda.py validate-db --target local
```

The loader reads `USDA_IMPORT_DATABASE_URL` first, then `DATABASE_URL`.
The loader reads `USDA_IMPORT_DATABASE_SCHEMA` first, then `DATABASE_SCHEMA`, and defaults to `public`.
Each successful load records a row in `reference_data_imports` with the manifest hash, source release metadata, row counts, target schema, and import timestamp.

## Dev/Production Schemas

The deployed Postgres database uses separate schemas:

- Dev: `cal_tracker_dev`
- Production: `cal_tracker_pro`

Run the same load for each schema by changing `USDA_IMPORT_DATABASE_SCHEMA`.

## Production Guard

Production runs require explicit intent:

```bash
USDA_IMPORT_MODE=docker-exec \
USDA_IMPORT_POSTGRES_CONTAINER=cal-tracker-postgres \
USDA_IMPORT_DATABASE_SCHEMA=cal_tracker_pro \
python tools/usda_import/import_usda.py validate-db --target production --confirm-production
```

The script does not start, stop, restart, kill, or reconfigure production containers.
