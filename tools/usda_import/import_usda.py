#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import unicodedata
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd
import psycopg
import requests
from tqdm import tqdm


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATA_DIR = ROOT / "data" / "usda"
LICENSE = "CC0-1.0"
SOURCE = "usda_fdc"

NUTRIENTS = {
    "calories": 1008,
    "energy_general_kcal": 2047,
    "energy_specific_kcal": 2048,
    "protein_grams": 1003,
    "fat_grams": 1004,
    "carbs_grams": 1005,
    "fiber_grams": 1079,
    "sugars_grams": 2000,
    "saturated_fat_grams": 1258,
    "sodium_mg": 1093,
}

LEGACY_NUTRIENT_NUMBERS = {
    "208": 1008,
    "957": 2047,
    "958": 2048,
    "203": 1003,
    "204": 1004,
    "205": 1005,
    "291": 1079,
    "269": 2000,
    "606": 1258,
    "307": 1093,
}


@dataclass(frozen=True)
class Dataset:
    key: str
    label: str
    data_type: str
    release: str
    url: str
    detail_table: str


DATASETS = {
    "foundation": Dataset(
        key="foundation",
        label="Foundation Foods 04/2026",
        data_type="Foundation",
        release="2026-04-30",
        url="https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_csv_2026-04-30.zip",
        detail_table="foundation_food",
    ),
    "branded": Dataset(
        key="branded",
        label="Branded Foods 04/2026",
        data_type="Branded",
        release="2026-04-30",
        url="https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_branded_food_csv_2026-04-30.zip",
        detail_table="branded_food",
    ),
    "sr_legacy": Dataset(
        key="sr_legacy",
        label="SR Legacy 04/2018",
        data_type="SR Legacy",
        release="2018-04",
        url="https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip",
        detail_table="sr_legacy_food",
    ),
}

FOOD_LOAD_COLUMNS = [
    "external_id",
    "name",
    "normalized_name",
    "canonical_name",
    "data_type",
    "food_category",
    "publication_date",
    "ndb_number",
    "food_key",
    "brand",
    "barcode",
    "ingredients",
    "market_country",
    "household_serving_fulltext",
    "source_url",
    "license",
    "serving_grams",
    "calories",
    "protein_grams",
    "carbs_grams",
    "fat_grams",
    "nutrients_json",
]

PORTION_LOAD_COLUMNS = [
    "external_food_id",
    "usda_portion_id",
    "amount",
    "unit",
    "modifier",
    "description",
    "gram_weight",
    "normalized_aliases_json",
    "kind",
    "source_description",
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Build and load a local USDA FoodData Central corpus.")
    parser.add_argument("command", choices=["download", "build", "validate", "load", "validate-db", "run"])
    parser.add_argument("--data-dir", default=str(DEFAULT_DATA_DIR))
    parser.add_argument("--target", choices=["local", "production"], default="local")
    parser.add_argument("--confirm-production", action="store_true")
    parser.add_argument("--chunk-size", type=int, default=250_000)
    args = parser.parse_args()

    ctx = Context(Path(args.data_dir), args.target, args.confirm_production, args.chunk_size)
    ctx.ensure_dirs()
    if args.command in {"download", "run"}:
        download(ctx)
    if args.command in {"build", "run"}:
        build(ctx)
    if args.command in {"validate", "run"}:
        validate(ctx)
    if args.command in {"load", "run"}:
        load(ctx)
    if args.command == "validate-db":
        validate_db(ctx)
    return 0


class Context:
    def __init__(self, data_dir: Path, target: str, confirm_production: bool, chunk_size: int) -> None:
        self.data_dir = data_dir
        self.target = target
        self.confirm_production = confirm_production
        self.chunk_size = chunk_size
        self.raw_dir = data_dir / "raw"
        self.parquet_dir = data_dir / "parquet"
        self.normalized_dir = data_dir / "normalized"
        self.manifest_dir = data_dir / "manifests"
        self.report_dir = data_dir / "reports"

    def ensure_dirs(self) -> None:
        for directory in [self.raw_dir, self.parquet_dir, self.normalized_dir, self.manifest_dir, self.report_dir]:
            directory.mkdir(parents=True, exist_ok=True)

    def zip_path(self, dataset: Dataset) -> Path:
        return self.raw_dir / Path(dataset.url).name

    def parquet_path(self, dataset: Dataset, table: str) -> Path:
        return self.parquet_dir / dataset.key / f"{table}.parquet"

    @property
    def foods_path(self) -> Path:
        return self.normalized_dir / "foods.parquet"

    @property
    def portions_path(self) -> Path:
        return self.normalized_dir / "food_portions.parquet"


def download(ctx: Context) -> None:
    for dataset in DATASETS.values():
        destination = ctx.zip_path(dataset)
        if destination.exists() and destination.stat().st_size > 0:
            print(f"Using cached {destination}")
            continue
        temporary = destination.with_suffix(destination.suffix + ".part")
        print(f"Downloading {dataset.label}")
        with requests.get(dataset.url, stream=True, timeout=60) as response:
            response.raise_for_status()
            total = int(response.headers.get("content-length") or 0)
            with temporary.open("wb") as fh, tqdm(total=total, unit="B", unit_scale=True) as progress:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if not chunk:
                        continue
                    fh.write(chunk)
                    progress.update(len(chunk))
        temporary.replace(destination)


def build(ctx: Context) -> None:
    foods_by_dataset: dict[str, pd.DataFrame] = {}
    portions_by_dataset: list[pd.DataFrame] = []
    for dataset in DATASETS.values():
        print(f"Reducing {dataset.label}")
        foods, portions = build_dataset(ctx, dataset)
        foods_by_dataset[dataset.key] = foods
        portions_by_dataset.append(portions)

    sr = foods_by_dataset["sr_legacy"]
    foundation = drop_foundation_duplicates(foods_by_dataset["foundation"], sr, ctx)
    branded = dedupe_branded_foods(foods_by_dataset["branded"], ctx)
    foods = pd.concat([sr, foundation, branded], ignore_index=True)
    foods = foods.drop_duplicates(subset=["external_id"], keep="first")
    foods = filter_valid_foods(foods, ctx)
    valid_ids = set(foods["external_id"].astype(str))
    portions = pd.concat(portions_by_dataset, ignore_index=True)
    portions = portions[portions["external_food_id"].astype(str).isin(valid_ids)].copy()

    ctx.foods_path.parent.mkdir(parents=True, exist_ok=True)
    foods.to_parquet(ctx.foods_path, index=False)
    portions.to_parquet(ctx.portions_path, index=False)
    write_manifest(ctx, foods, portions)
    print(f"Wrote {len(foods):,} foods and {len(portions):,} portions")


def build_dataset(ctx: Context, dataset: Dataset) -> tuple[pd.DataFrame, pd.DataFrame]:
    food = cached_table(ctx, dataset, "food", ["fdc_id", "data_type", "description", "food_category_id", "publication_date"])
    nutrients = cached_nutrients(ctx, dataset)
    categories = cached_table(ctx, dataset, "food_category", ["id", "code", "description"])
    detail = cached_table(ctx, dataset, dataset.detail_table, detail_columns(dataset))

    food["fdc_id"] = food["fdc_id"].astype(str)
    food["data_type"] = dataset.data_type
    food = food.merge(nutrients, on="fdc_id", how="left")
    food = attach_categories(food, categories)
    food = attach_detail(food, detail, dataset)
    food = normalize_food_rows(food, dataset)

    portions = normalize_portions(ctx, dataset, set(food["external_id"].astype(str)))
    return food, portions


def cached_table(ctx: Context, dataset: Dataset, table: str, columns: list[str]) -> pd.DataFrame:
    path = ctx.parquet_path(dataset, table)
    if path.exists():
        return pd.read_parquet(path)
    try:
        frame = read_csv_from_zip(ctx.zip_path(dataset), table, columns)
    except FileNotFoundError:
        frame = pd.DataFrame(columns=columns)
    path.parent.mkdir(parents=True, exist_ok=True)
    frame.to_parquet(path, index=False)
    return frame


def cached_nutrients(ctx: Context, dataset: Dataset) -> pd.DataFrame:
    path = ctx.parquet_path(dataset, "selected_nutrients_v5")
    if path.exists():
        return pd.read_parquet(path)

    nutrient_map = nutrient_id_map(ctx, dataset)
    selected = set(nutrient_map)
    chunks: list[pd.DataFrame] = []
    for chunk in read_csv_chunks(
        ctx.zip_path(dataset),
        "food_nutrient",
        ["fdc_id", "nutrient_id", "amount"],
        chunksize=ctx.chunk_size,
    ):
        chunk["nutrient_id"] = pd.to_numeric(chunk["nutrient_id"], errors="coerce").astype("Int64")
        filtered = chunk[chunk["nutrient_id"].isin(selected)].copy()
        if not filtered.empty:
            filtered["fdc_id"] = filtered["fdc_id"].astype(str)
            filtered["nutrient_number"] = filtered["nutrient_id"].map(nutrient_map)
            filtered["amount"] = pd.to_numeric(filtered["amount"], errors="coerce")
            chunks.append(filtered)
    if chunks:
        nutrients = pd.concat(chunks, ignore_index=True)
        pivot = nutrients.pivot_table(index="fdc_id", columns="nutrient_number", values="amount", aggfunc="first").reset_index()
    else:
        pivot = pd.DataFrame(columns=["fdc_id"])
    rename = {nutrient_id: name for name, nutrient_id in NUTRIENTS.items()}
    pivot = pivot.rename(columns=rename)
    for name in NUTRIENTS:
        if name not in pivot:
            pivot[name] = np.nan
    path.parent.mkdir(parents=True, exist_ok=True)
    pivot.to_parquet(path, index=False)
    return pivot


def nutrient_id_map(ctx: Context, dataset: Dataset) -> dict[int, int]:
    nutrients = read_csv_from_zip(ctx.zip_path(dataset), "nutrient", ["id", "nutrient_nbr"])
    selected_ids = set(NUTRIENTS.values())
    result: dict[int, int] = {}
    for _, row in nutrients.iterrows():
        nutrient_id = pd.to_numeric(row.get("id"), errors="coerce")
        nutrient_number = str(row.get("nutrient_nbr")).strip()
        if pd.isna(nutrient_id):
            continue
        nutrient_id_int = int(nutrient_id)
        if nutrient_id_int in selected_ids:
            result[nutrient_id_int] = nutrient_id_int
        elif nutrient_number in LEGACY_NUTRIENT_NUMBERS:
            result[nutrient_id_int] = LEGACY_NUTRIENT_NUMBERS[nutrient_number]
    return result


def detail_columns(dataset: Dataset) -> list[str]:
    if dataset.key == "branded":
        return [
            "fdc_id",
            "brand_owner",
            "brand_name",
            "subbrand_name",
            "gtin_upc",
            "ingredients",
            "serving_size",
            "serving_size_unit",
            "household_serving_fulltext",
            "branded_food_category",
            "modified_date",
            "available_date",
            "discontinued_date",
            "market_country",
        ]
    return ["fdc_id", "NDB_number", "ndb_number"]


def attach_categories(food: pd.DataFrame, categories: pd.DataFrame) -> pd.DataFrame:
    if categories.empty or "food_category_id" not in food:
        food["food_category"] = None
        return food
    categories = categories.rename(columns={"id": "food_category_id", "description": "food_category"})
    categories["food_category_id"] = categories["food_category_id"].astype(str)
    food["food_category_id"] = food["food_category_id"].astype(str)
    return food.merge(categories[["food_category_id", "food_category"]], on="food_category_id", how="left")


def attach_detail(food: pd.DataFrame, detail: pd.DataFrame, dataset: Dataset) -> pd.DataFrame:
    if detail.empty:
        return food
    detail["fdc_id"] = detail["fdc_id"].astype(str)
    attached = food.merge(detail, on="fdc_id", how="left")
    if dataset.key != "branded":
        if "ndb_number" not in attached:
            attached["ndb_number"] = None
        if "NDB_number" in attached:
            attached["ndb_number"] = attached["ndb_number"].fillna(attached["NDB_number"])
        if "ndb_number" not in attached:
            attached["ndb_number"] = None
    return attached


def normalize_food_rows(food: pd.DataFrame, dataset: Dataset) -> pd.DataFrame:
    result = food.copy()
    if "calories" in result:
        result["calories"] = pd.to_numeric(result["calories"], errors="coerce")
        result["calories"] = result["calories"].fillna(pd.to_numeric(result.get("energy_general_kcal"), errors="coerce"))
        result["calories"] = result["calories"].fillna(pd.to_numeric(result.get("energy_specific_kcal"), errors="coerce"))
    result["external_id"] = result["fdc_id"].astype(str)
    result["name"] = result["description"].astype(str).str.strip()
    result["normalized_name"] = result["name"].map(normalize_text)
    result["canonical_name"] = result["normalized_name"]
    result["data_type"] = dataset.data_type
    result["publication_date"] = series_or_default(result, "publication_date", dataset.release).fillna(dataset.release).astype(str).str[:10]
    result["food_key"] = SOURCE + ":" + result["external_id"]
    result["source_url"] = "https://fdc.nal.usda.gov/fdc-app.html#/food-details/" + result["external_id"] + "/nutrients"
    result["license"] = LICENSE
    result["brand"] = None
    result["barcode"] = None
    result["ingredients"] = None
    result["market_country"] = None
    result["household_serving_fulltext"] = None
    result["serving_grams"] = 100.0
    if dataset.key == "branded":
        result["brand"] = result.apply(brand_for_row, axis=1)
        result["barcode"] = series_or_default(result, "gtin_upc", None).map(clean_barcode)
        result["ingredients"] = series_or_default(result, "ingredients", None)
        result["market_country"] = series_or_default(result, "market_country", None)
        result["household_serving_fulltext"] = series_or_default(result, "household_serving_fulltext", None)
        result["food_category"] = series_or_default(result, "branded_food_category", None).fillna(series_or_default(result, "food_category", None))
        result["serving_grams"] = serving_grams_for_branded(result)
    if "ndb_number" not in result:
        result["ndb_number"] = None

    result["nutrients_json"] = result.apply(nutrients_json, axis=1)
    keep = FOOD_LOAD_COLUMNS + ["fdc_id", "modified_date", "available_date", "discontinued_date"]
    for column in keep:
        if column not in result:
            result[column] = None
    return result[keep]


def brand_for_row(row: pd.Series) -> str | None:
    values = [row.get("brand_name"), row.get("subbrand_name"), row.get("brand_owner")]
    cleaned = [str(value).strip() for value in values if pd.notna(value) and str(value).strip()]
    return ", ".join(dict.fromkeys(cleaned)) or None


def clean_barcode(value: object) -> str | None:
    if pd.isna(value):
        return None
    digits = re.sub(r"\D+", "", str(value))
    return digits or None


def series_or_default(frame: pd.DataFrame, column: str, default: object) -> pd.Series:
    if column in frame:
        return frame[column]
    return pd.Series([default] * len(frame), index=frame.index)


def serving_grams_for_branded(frame: pd.DataFrame) -> pd.Series:
    size = pd.to_numeric(series_or_default(frame, "serving_size", None), errors="coerce")
    unit = series_or_default(frame, "serving_size_unit", "").fillna("").astype(str).str.lower()
    grams = size.where(unit.isin(["g", "gram", "grams", "ml", "milliliter", "milliliters"]), 100.0)
    return grams.fillna(100.0)


def nutrients_json(row: pd.Series) -> str:
    payload = {}
    for key in ["fiber_grams", "sugars_grams", "saturated_fat_grams", "sodium_mg"]:
        value = row.get(key)
        if pd.notna(value):
            payload[key] = round(float(value), 4)
    return json.dumps(payload, separators=(",", ":"))


def normalize_portions(ctx: Context, dataset: Dataset, valid_food_ids: set[str]) -> pd.DataFrame:
    portions = cached_table(ctx, dataset, "food_portion", ["id", "fdc_id", "amount", "measure_unit_id", "portion_description", "modifier", "gram_weight"])
    if portions.empty:
        return empty_portions()
    units = cached_table(ctx, dataset, "measure_unit", ["id", "name", "abbreviation"])
    portions["fdc_id"] = portions["fdc_id"].astype(str)
    portions = portions[portions["fdc_id"].isin(valid_food_ids)].copy()
    if portions.empty:
        return empty_portions()
    if not units.empty:
        units = units.rename(columns={"id": "measure_unit_id", "name": "unit", "abbreviation": "unit_abbreviation"})
        portions["measure_unit_id"] = portions["measure_unit_id"].astype(str)
        units["measure_unit_id"] = units["measure_unit_id"].astype(str)
        portions = portions.merge(units[["measure_unit_id", "unit", "unit_abbreviation"]], on="measure_unit_id", how="left")
    else:
        portions["unit"] = None
        portions["unit_abbreviation"] = None

    portions["amount_number"] = pd.to_numeric(portions.get("amount"), errors="coerce")
    portions["gram_weight_number"] = pd.to_numeric(portions.get("gram_weight"), errors="coerce")
    portions = portions[portions["gram_weight_number"] > 0].copy()
    portions["gram_weight"] = portions.apply(
        lambda row: float(row["gram_weight_number"]) / float(row["amount_number"])
        if pd.notna(row["amount_number"]) and float(row["amount_number"]) > 0
        else float(row["gram_weight_number"]),
        axis=1,
    )
    portions["source_description"] = portions.apply(portion_source_description, axis=1)
    portions["normalized_aliases_json"] = portions.apply(lambda row: json.dumps(portion_aliases(row), separators=(",", ":")), axis=1)
    portions["kind"] = portions["source_description"].map(classify_portion_kind)
    portions = portions.rename(
        columns={
            "fdc_id": "external_food_id",
            "id": "usda_portion_id",
            "portion_description": "description",
        }
    )
    for column in PORTION_LOAD_COLUMNS:
        if column not in portions:
            portions[column] = None
    return portions[PORTION_LOAD_COLUMNS]


def empty_portions() -> pd.DataFrame:
    return pd.DataFrame(columns=PORTION_LOAD_COLUMNS)


def portion_source_description(row: pd.Series) -> str:
    parts = [
        row.get("amount"),
        row.get("unit"),
        row.get("unit_abbreviation"),
        row.get("modifier"),
        row.get("portion_description"),
    ]
    return " ".join(str(part).strip() for part in parts if pd.notna(part) and str(part).strip()) or "USDA portion"


def portion_aliases(row: pd.Series) -> list[str]:
    text = " ".join(
        str(row.get(column) or "")
        for column in ["unit", "unit_abbreviation", "modifier", "portion_description", "source_description"]
    )
    normalized = normalize_text(text)
    aliases = set()
    for alias, canonical in HOUSEHOLD_ALIASES.items():
        if re.search(rf"\b{re.escape(alias)}\b", normalized):
            aliases.add(alias)
            aliases.add(canonical)
    for size in ["extra small", "extra large", "small", "medium", "large", "jumbo", "whole", "each"]:
        if re.search(rf"\b{re.escape(size)}\b", normalized):
            aliases.add(size)
    return sorted(alias for alias in aliases if alias)


HOUSEHOLD_ALIASES = {
    "cup": "cup",
    "cups": "cup",
    "tbsp": "tablespoon",
    "tablespoon": "tablespoon",
    "tablespoons": "tablespoon",
    "tsp": "teaspoon",
    "teaspoon": "teaspoon",
    "teaspoons": "teaspoon",
    "slice": "slice",
    "slices": "slice",
    "piece": "piece",
    "pieces": "piece",
    "wedge": "wedge",
    "wedges": "wedge",
    "clove": "clove",
    "cloves": "clove",
    "breast": "breast",
    "breasts": "breast",
    "leg": "leg",
    "legs": "leg",
    "fruit": "fruit",
    "item": "item",
    "each": "each",
    "egg": "egg",
    "eggs": "egg",
}


def classify_portion_kind(source_description: str) -> str:
    text = normalize_text(source_description)
    if re.search(r"\b(cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons)\b", text):
        return "household"
    if re.search(r"\b(slice|slices|wedge|wedges|piece|pieces|clove|cloves|head|heads|stalk|stalks|bunch|bunches|breast|breasts|leg|legs|fillet|fillets)\b", text):
        return "piece_shape"
    if re.search(r"\b(extra small|small|medium|large|extra large|jumbo)\b", text):
        return "count_size"
    if re.search(r"\b(whole|fruit|item|each|egg|eggs)\b", text):
        return "whole_item"
    return "serving"


def drop_foundation_duplicates(foundation: pd.DataFrame, sr: pd.DataFrame, ctx: Context) -> pd.DataFrame:
    sr_ndb = {str(value).strip() for value in sr["ndb_number"].dropna() if str(value).strip()}
    sr_desc_cat = {
        (row.normalized_name, row.food_category or "")
        for row in sr[["normalized_name", "food_category"]].itertuples(index=False)
    }
    ndb_duplicate = foundation["ndb_number"].fillna("").astype(str).str.strip().isin(sr_ndb)
    desc_duplicate = foundation.apply(lambda row: (row["normalized_name"], row.get("food_category") or "") in sr_desc_cat, axis=1)
    dropped = foundation[ndb_duplicate | desc_duplicate]
    kept = foundation[~(ndb_duplicate | desc_duplicate)].copy()
    report = {
        "dropped_foundation_rows": int(len(dropped)),
        "dropped_by_ndb_number": int(ndb_duplicate.sum()),
        "dropped_by_description_category": int(desc_duplicate.sum()),
        "sample_dropped_fdc_ids": dropped["external_id"].head(25).astype(str).tolist(),
    }
    write_json(ctx.report_dir / "foundation_dedup.json", report)
    return kept


def dedupe_branded_foods(branded: pd.DataFrame, ctx: Context) -> pd.DataFrame:
    if branded.empty:
        return branded
    active = branded[branded["discontinued_date"].isna() | (branded["discontinued_date"].astype(str).str.strip() == "")].copy()
    active["barcode_text"] = active["barcode"].fillna("").astype(str)
    sort_columns = ["available_date", "modified_date", "publication_date", "external_id"]
    with_barcode = active[active["barcode_text"] != ""].sort_values(sort_columns).drop_duplicates("barcode_text", keep="last")
    without_barcode = active[active["barcode_text"] == ""].drop_duplicates("external_id", keep="last")
    result = pd.concat([with_barcode, without_barcode], ignore_index=True).drop(columns=["barcode_text"])
    report = {
        "input_rows": int(len(branded)),
        "active_rows": int(len(active)),
        "deduped_rows": int(len(result)),
        "dropped_rows": int(len(branded) - len(result)),
    }
    write_json(ctx.report_dir / "branded_dedup.json", report)
    return result


def filter_valid_foods(foods: pd.DataFrame, ctx: Context) -> pd.DataFrame:
    required = ["calories", "protein_grams", "carbs_grams", "fat_grams"]
    numeric = foods.copy()
    for column in required:
        numeric[column] = pd.to_numeric(numeric[column], errors="coerce")
    missing = numeric[required].isna().any(axis=1)
    impossible = (
        (numeric["calories"] < 0)
        | (numeric["calories"] > 2000)
        | (numeric["protein_grams"] < 0)
        | (numeric["protein_grams"] > 100)
        | (numeric["carbs_grams"] < 0)
        | (numeric["carbs_grams"] > 100)
        | (numeric["fat_grams"] < 0)
        | (numeric["fat_grams"] > 100)
    )
    dropped = numeric[missing | impossible]
    kept = numeric[~(missing | impossible)].copy()
    for column in required:
        kept[column] = kept[column].round(4)
    write_json(
        ctx.report_dir / "nutrition_filter.json",
        {
            "input_rows": int(len(foods)),
            "kept_rows": int(len(kept)),
            "dropped_missing_required_nutrition": int(missing.sum()),
            "dropped_impossible_macros": int(impossible.sum()),
            "sample_dropped_fdc_ids": dropped["external_id"].head(25).astype(str).tolist(),
        },
    )
    return kept


def validate(ctx: Context) -> None:
    foods = pd.read_parquet(ctx.foods_path)
    portions = pd.read_parquet(ctx.portions_path)
    errors: list[str] = []
    if foods["external_id"].duplicated().any():
        errors.append("duplicate fdc_id values found in normalized foods")
    required = ["calories", "protein_grams", "carbs_grams", "fat_grams"]
    missing = foods[required].isna().any(axis=1)
    if missing.any():
        errors.append(f"{int(missing.sum())} foods are missing required nutrition fields")
    impossible = foods[
        (foods["calories"] < 0)
        | (foods["calories"] > 2000)
        | (foods["protein_grams"] < 0)
        | (foods["protein_grams"] > 100)
        | (foods["carbs_grams"] < 0)
        | (foods["carbs_grams"] > 100)
        | (foods["fat_grams"] < 0)
        | (foods["fat_grams"] > 100)
    ]
    if not impossible.empty:
        errors.append(f"{len(impossible)} foods have negative or impossible macro values")
    if portions.empty:
        errors.append("no portions were imported")

    report = {
        "foods": int(len(foods)),
        "portions": int(len(portions)),
        "by_data_type": foods["data_type"].value_counts(dropna=False).to_dict(),
        "errors": errors,
    }
    write_json(ctx.report_dir / "validation.json", report)
    if errors:
        raise SystemExit("Validation failed: " + "; ".join(errors))
    print("Validation passed")


def load(ctx: Context) -> None:
    guard_production(ctx)
    foods = pd.read_parquet(ctx.foods_path)
    portions = pd.read_parquet(ctx.portions_path)
    if import_mode() == "docker-exec":
        docker_load(ctx, foods, portions)
    else:
        direct_load(ctx, foods, portions)


def direct_load(ctx: Context, foods: pd.DataFrame, portions: pd.DataFrame) -> None:
    database_url = os.environ.get("USDA_IMPORT_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not database_url:
        raise SystemExit("USDA_IMPORT_DATABASE_URL or DATABASE_URL is required")
    with psycopg.connect(database_url) as conn:
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute(search_path_sql())
                cur.execute(stage_food_sql())
                with cur.copy(f"COPY usda_food_stage ({','.join(FOOD_LOAD_COLUMNS)}) FROM STDIN") as copy:
                    for row in dataframe_rows(foods, FOOD_LOAD_COLUMNS):
                        copy.write_row(row)
                cur.execute(stage_portion_sql())
                with cur.copy(f"COPY usda_portion_stage ({','.join(PORTION_LOAD_COLUMNS)}) FROM STDIN") as copy:
                    for row in dataframe_rows(portions, PORTION_LOAD_COLUMNS):
                        copy.write_row(row)
                cur.execute(merge_stage_sql())
                cur.execute(record_import_sql(ctx, len(foods), len(portions)))
    print(f"Loaded {len(foods):,} USDA foods and {len(portions):,} portions")


def docker_load(ctx: Context, foods: pd.DataFrame, portions: pd.DataFrame) -> None:
    container = os.environ.get("USDA_IMPORT_POSTGRES_CONTAINER", "cal-tracker-postgres")
    food_csv = ctx.normalized_dir / "load_foods.csv"
    portion_csv = ctx.normalized_dir / "load_food_portions.csv"
    foods[FOOD_LOAD_COLUMNS].to_csv(food_csv, index=False)
    portions[PORTION_LOAD_COLUMNS].to_csv(portion_csv, index=False)
    subprocess.run(["docker", "cp", str(food_csv), f"{container}:/tmp/usda_foods.csv"], check=True)
    subprocess.run(["docker", "cp", str(portion_csv), f"{container}:/tmp/usda_food_portions.csv"], check=True)
    sql = "\n".join(
        [
            search_path_sql(),
            "BEGIN;",
            stage_food_sql(),
            f"\\copy usda_food_stage ({','.join(FOOD_LOAD_COLUMNS)}) FROM '/tmp/usda_foods.csv' WITH (FORMAT csv, HEADER true)",
            stage_portion_sql(),
            f"\\copy usda_portion_stage ({','.join(PORTION_LOAD_COLUMNS)}) FROM '/tmp/usda_food_portions.csv' WITH (FORMAT csv, HEADER true)",
            merge_stage_sql(),
            record_import_sql(ctx, len(foods), len(portions)),
            "COMMIT;",
        ]
    )
    docker_psql(sql, container)
    subprocess.run(["docker", "exec", container, "rm", "-f", "/tmp/usda_foods.csv", "/tmp/usda_food_portions.csv"], check=False)


def dataframe_rows(frame: pd.DataFrame, columns: list[str]) -> Iterable[list[object | None]]:
    for values in frame[columns].replace({np.nan: None}).itertuples(index=False, name=None):
        yield [None if pd.isna(value) else value for value in values]


def stage_food_sql() -> str:
    columns = ",\n  ".join(f"{column} text" for column in FOOD_LOAD_COLUMNS)
    return f"CREATE TEMP TABLE usda_food_stage (\n  {columns}\n) ON COMMIT DROP;"


def stage_portion_sql() -> str:
    columns = ",\n  ".join(f"{column} text" for column in PORTION_LOAD_COLUMNS)
    return f"CREATE TEMP TABLE usda_portion_stage (\n  {columns}\n) ON COMMIT DROP;"


def search_path_sql() -> str:
    schema = database_schema()
    if schema == "public":
        return "SET search_path TO public;"
    return f"SET search_path TO {quote_ident(schema)}, public;"


def database_schema() -> str:
    schema = os.environ.get("USDA_IMPORT_DATABASE_SCHEMA") or os.environ.get("DATABASE_SCHEMA") or "public"
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", schema):
        raise SystemExit(f"Invalid database schema name: {schema}")
    return schema


def quote_ident(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def merge_stage_sql() -> str:
    return """
UPDATE food_items target
SET name = stage.name,
    normalized_name = stage.normalized_name,
    canonical_name = stage.canonical_name,
    brand = NULLIF(stage.brand, ''),
    barcode = NULLIF(stage.barcode, ''),
    source = 'usda_fdc',
    external_source = 'usda_fdc',
    source_url = stage.source_url,
    license = stage.license,
    fetched_at = now(),
    data_type = stage.data_type,
    food_category = NULLIF(stage.food_category, ''),
    publication_date = NULLIF(stage.publication_date, '')::date,
    ndb_number = NULLIF(stage.ndb_number, ''),
    food_key = stage.food_key,
    ingredients = NULLIF(stage.ingredients, ''),
    market_country = NULLIF(stage.market_country, ''),
    household_serving_fulltext = NULLIF(stage.household_serving_fulltext, ''),
    nutrients_json = COALESCE(NULLIF(stage.nutrients_json, '')::jsonb, '{}'::jsonb),
    serving_grams = NULLIF(stage.serving_grams, '')::numeric,
    calories = round(NULLIF(stage.calories, '')::numeric)::integer,
    protein_grams = NULLIF(stage.protein_grams, '')::numeric,
    carbs_grams = NULLIF(stage.carbs_grams, '')::numeric,
    fat_grams = NULLIF(stage.fat_grams, '')::numeric
FROM usda_food_stage stage
WHERE target.external_source = 'usda_fdc'
  AND target.external_id = stage.external_id
  AND target.user_id IS NULL;

INSERT INTO food_items (
  user_id, name, normalized_name, canonical_name, brand, barcode, source,
  external_source, external_id, source_url, license, fetched_at, data_type,
  food_category, publication_date, ndb_number, food_key, ingredients,
  market_country, household_serving_fulltext, nutrients_json, serving_grams,
  calories, protein_grams, carbs_grams, fat_grams
)
SELECT
  NULL, stage.name, stage.normalized_name, stage.canonical_name,
  NULLIF(stage.brand, ''), NULLIF(stage.barcode, ''), 'usda_fdc',
  'usda_fdc', stage.external_id, stage.source_url, stage.license, now(),
  stage.data_type, NULLIF(stage.food_category, ''), NULLIF(stage.publication_date, '')::date,
  NULLIF(stage.ndb_number, ''), stage.food_key, NULLIF(stage.ingredients, ''),
  NULLIF(stage.market_country, ''), NULLIF(stage.household_serving_fulltext, ''),
  COALESCE(NULLIF(stage.nutrients_json, '')::jsonb, '{}'::jsonb),
  NULLIF(stage.serving_grams, '')::numeric, round(NULLIF(stage.calories, '')::numeric)::integer,
  NULLIF(stage.protein_grams, '')::numeric, NULLIF(stage.carbs_grams, '')::numeric,
  NULLIF(stage.fat_grams, '')::numeric
FROM usda_food_stage stage
WHERE NOT EXISTS (
  SELECT 1 FROM food_items existing
  WHERE existing.external_source = 'usda_fdc'
    AND existing.external_id = stage.external_id
    AND existing.user_id IS NULL
);

DELETE FROM food_portions portion
USING food_items food, usda_food_stage stage
WHERE portion.food_item_id = food.id
  AND food.external_source = 'usda_fdc'
  AND food.external_id = stage.external_id
  AND food.user_id IS NULL;

INSERT INTO food_portions (
  food_item_id, usda_portion_id, amount, unit, modifier, description,
  gram_weight, normalized_aliases, kind, source_description
)
SELECT
  food.id,
  NULLIF(stage.usda_portion_id, ''),
  NULLIF(stage.amount, '')::numeric,
  NULLIF(stage.unit, ''),
  NULLIF(stage.modifier, ''),
  NULLIF(stage.description, ''),
  NULLIF(stage.gram_weight, '')::numeric,
  ARRAY(SELECT jsonb_array_elements_text(COALESCE(NULLIF(stage.normalized_aliases_json, '')::jsonb, '[]'::jsonb))),
  COALESCE(NULLIF(stage.kind, ''), 'serving'),
  COALESCE(NULLIF(stage.source_description, ''), 'USDA portion')
FROM usda_portion_stage stage
JOIN food_items food
  ON food.external_source = 'usda_fdc'
 AND food.external_id = stage.external_food_id
 AND food.user_id IS NULL
WHERE NULLIF(stage.gram_weight, '')::numeric > 0;
"""


def record_import_sql(ctx: Context, food_count: int, portion_count: int) -> str:
    manifest = import_manifest(ctx)
    manifest_json = json.dumps(manifest, sort_keys=True, separators=(",", ":"))
    manifest_sha256 = hashlib.sha256(manifest_json.encode("utf-8")).hexdigest()
    return f"""
INSERT INTO reference_data_imports (
  source, target_schema, manifest_sha256, manifest_json, food_count, portion_count
)
VALUES (
  {sql_literal(SOURCE)},
  {sql_literal(database_schema())},
  {sql_literal(manifest_sha256)},
  {sql_literal(manifest_json)}::jsonb,
  {int(food_count)},
  {int(portion_count)}
)
ON CONFLICT (source, target_schema, manifest_sha256)
DO UPDATE SET
  manifest_json = EXCLUDED.manifest_json,
  food_count = EXCLUDED.food_count,
  portion_count = EXCLUDED.portion_count,
  imported_at = now();
"""


def import_manifest(ctx: Context) -> dict[str, object]:
    manifest_path = ctx.manifest_dir / "manifest.json"
    if not manifest_path.exists():
        raise SystemExit(f"Manifest not found: {manifest_path}. Run build/validate before load.")
    return json.loads(manifest_path.read_text(encoding="utf-8"))


def sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def validate_db(ctx: Context) -> None:
    guard_production(ctx)
    sql = search_path_sql() + """
SELECT 'usda_food_items', count(*)::text FROM food_items WHERE external_source = 'usda_fdc'
UNION ALL
SELECT 'usda_portions', count(*)::text FROM food_portions
UNION ALL
SELECT 'duplicate_fdc_ids', count(*)::text
FROM (
  SELECT external_id FROM food_items
  WHERE external_source = 'usda_fdc' AND user_id IS NULL
  GROUP BY external_id HAVING count(*) > 1
) duplicates
UNION ALL
SELECT 'sr_legacy', count(*)::text FROM food_items WHERE external_source = 'usda_fdc' AND data_type = 'SR Legacy'
UNION ALL
SELECT 'foundation', count(*)::text FROM food_items WHERE external_source = 'usda_fdc' AND data_type = 'Foundation'
UNION ALL
SELECT 'branded', count(*)::text FROM food_items WHERE external_source = 'usda_fdc' AND data_type = 'Branded';

SELECT source, target_schema, manifest_sha256, food_count, portion_count, imported_at
FROM reference_data_imports
WHERE source = 'usda_fdc'
ORDER BY imported_at DESC
LIMIT 5;

EXPLAIN ANALYZE
SELECT id, name
FROM food_items
WHERE external_source = 'usda_fdc'
  AND normalized_name % 'chicken breast'
ORDER BY similarity(normalized_name, 'chicken breast') DESC
LIMIT 10;
"""
    if import_mode() == "docker-exec":
        print(docker_psql(sql, os.environ.get("USDA_IMPORT_POSTGRES_CONTAINER", "cal-tracker-postgres")))
        return
    database_url = os.environ.get("USDA_IMPORT_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not database_url:
        raise SystemExit("USDA_IMPORT_DATABASE_URL or DATABASE_URL is required")
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            for statement in [part.strip() for part in sql.split(";") if part.strip()]:
                cur.execute(statement)
                if cur.description:
                    for row in cur.fetchall():
                        print(row)


def docker_psql(sql: str, container: str) -> str:
    user = os.environ.get("USDA_IMPORT_POSTGRES_USER", "cal_tracker")
    database = os.environ.get("USDA_IMPORT_POSTGRES_DB", "cal_tracker")
    try:
        completed = subprocess.run(
            ["docker", "exec", "-i", container, "psql", "-v", "ON_ERROR_STOP=1", "-U", user, "-d", database],
            input=sql,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=True,
        )
    except subprocess.CalledProcessError as error:
        if error.stdout:
            print(error.stdout, file=sys.stderr)
        raise
    return completed.stdout


def guard_production(ctx: Context) -> None:
    if ctx.target == "production" and not ctx.confirm_production:
        raise SystemExit("--confirm-production is required for production targets")


def import_mode() -> str:
    return os.environ.get("USDA_IMPORT_MODE", "direct")


def read_csv_from_zip(zip_path: Path, table: str, columns: list[str]) -> pd.DataFrame:
    member = zip_member(zip_path, table)
    with zipfile.ZipFile(zip_path) as archive:
        with archive.open(member) as fh:
            header = pd.read_csv(fh, nrows=0)
        usecols = [column for column in columns if column in header.columns]
        if not usecols:
            return pd.DataFrame(columns=columns)
        with archive.open(member) as fh:
            frame = pd.read_csv(fh, usecols=usecols, dtype=str, low_memory=False)
    for column in columns:
        if column not in frame:
            frame[column] = None
    return frame[columns]


def read_csv_chunks(zip_path: Path, table: str, columns: list[str], chunksize: int) -> Iterable[pd.DataFrame]:
    member = zip_member(zip_path, table)
    with zipfile.ZipFile(zip_path) as archive:
        with archive.open(member) as fh:
            header = pd.read_csv(fh, nrows=0)
        usecols = [column for column in columns if column in header.columns]
        with archive.open(member) as fh:
            for chunk in pd.read_csv(fh, usecols=usecols, dtype=str, chunksize=chunksize, low_memory=False):
                for column in columns:
                    if column not in chunk:
                        chunk[column] = None
                yield chunk[columns]


def zip_member(zip_path: Path, table: str) -> str:
    expected = f"{table}.csv".lower()
    with zipfile.ZipFile(zip_path) as archive:
        for name in archive.namelist():
            if Path(name).name.lower() == expected:
                return name
    raise FileNotFoundError(f"{expected} not found in {zip_path}")


def write_manifest(ctx: Context, foods: pd.DataFrame, portions: pd.DataFrame) -> None:
    manifest = {
        "datasets": {
            key: {
                "label": dataset.label,
                "release": dataset.release,
                "url": dataset.url,
                "sha256": sha256_file(ctx.zip_path(dataset)) if ctx.zip_path(dataset).exists() else None,
            }
            for key, dataset in DATASETS.items()
        },
        "foods": int(len(foods)),
        "portions": int(len(portions)),
        "by_data_type": foods["data_type"].value_counts(dropna=False).to_dict(),
    }
    write_json(ctx.manifest_dir / "manifest.json", manifest)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def normalize_text(value: object) -> str:
    if pd.isna(value):
        return ""
    text = unicodedata.normalize("NFKD", str(value).lower())
    text = "".join(char for char in text if not unicodedata.combining(char))
    text = re.sub(r"[^a-z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


if __name__ == "__main__":
    raise SystemExit(main())
