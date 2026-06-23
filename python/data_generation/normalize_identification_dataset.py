"""Reproduce the recovered normalization of the historical dataset."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    source = pd.read_csv(args.input, parse_dates=["created_at"])
    required = {
        "created_at",
        "water_input",
        "soil_moisture_sim",
        "air_temp",
        "humidity",
    }
    missing = required.difference(source.columns)
    if missing:
        raise KeyError(f"Missing columns: {sorted(missing)}")

    normalized = pd.DataFrame(
        {
            "created_at": source["created_at"],
            # Historical transformation. The physical meaning of 720 is unresolved.
            "u_irrig": source["water_input"].clip(lower=0.0) / 720.0,
            "soil_frac": source["soil_moisture_sim"] / 100.0,
            "air_temp": source["air_temp"],
            "humidity": source["humidity"],
        }
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    normalized.to_csv(args.output, index=False)
    print(f"Saved {len(normalized)} samples to {args.output}")


if __name__ == "__main__":
    main()

