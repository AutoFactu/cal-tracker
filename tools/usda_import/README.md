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
python tools/usda_import/import_usda.py run --target local
python tools/usda_import/import_usda.py validate-db --target local
```

The loader reads `USDA_IMPORT_DATABASE_URL` first, then `DATABASE_URL`.

## Production Guard

Production runs require explicit intent:

```bash
USDA_IMPORT_MODE=docker-exec \
USDA_IMPORT_POSTGRES_CONTAINER=cal-tracker-postgres \
python tools/usda_import/import_usda.py validate-db --target production --confirm-production
```

The script does not start, stop, restart, kill, or reconfigure production containers.
