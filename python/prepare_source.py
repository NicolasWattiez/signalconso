from pathlib import Path

import polars as pl


RAW_PATH = Path("data/raw/signalconso.csv")
OUTPUT_PATH = Path("data/processed/signalconso.parquet")


COLUMN_NAMES = {
    "Date": "date",
    "contactAgreement": "contact_agreement",
    "forwardToReponseConso": "forward_to_reponse_conso",
    "Signalement Transmis": "signalement_transmis",
    "Signalement Lu par l'entreprise": "signalement_lu",
    "Signalement ayant reçu une réponse": "signalement_reponse",
    "Code Officiel Région": "region_code",
    "Nom Officiel Région": "region_name",
}


BOOLEAN_COLUMNS = [
    "contactAgreement",
    "forwardToReponseConso",
    "Signalement Transmis",
    "Signalement Lu par l'entreprise",
    "Signalement ayant reçu une réponse",
]


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Read everything initially as text.
    # This prevents CSV schema inference from making unwanted decisions.
    df = pl.scan_csv(
        RAW_PATH,
        separator=";",
        infer_schema=False,
    )

    # Explicit technical typing.
    df = df.with_columns(
        pl.col("Date").str.to_date("%Y-%m-%d", strict=True),
        *[
            pl.col(column).cast(pl.Int8, strict=True).cast(pl.Boolean)
            for column in BOOLEAN_COLUMNS
        ],
    )

    # Technical column-name normalization.
    df = df.rename(COLUMN_NAMES)

    # Stream the result directly to Parquet.
    df.sink_parquet(
        OUTPUT_PATH,
        compression="zstd",
        statistics=True,
    )

    # Validation of the produced artifact.
    parquet = pl.scan_parquet(OUTPUT_PATH)

    summary = parquet.select(
        pl.len().alias("row_count"),
        pl.col("date").min().alias("min_date"),
        pl.col("date").max().alias("max_date"),
        pl.col("id").n_unique().alias("unique_ids"),
    ).collect()

    print(summary)
    print()
    print("Schema:")
    print(parquet.collect_schema())


if __name__ == "__main__":
    main()