"""Generate the model-assisted PRBS/chirp identification dataset.

This reconstructs the final recovered Colab workflow. It requires private
baseline files that are not distributed with the repository.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.signal import chirp, max_len_seq


REQUIRED_VALVE_COLUMNS = {
    "created_at",
    "soil_moisture",
    "valve",
    "air_temp",
    "humidity",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--valve-data", type=Path, required=True)
    parser.add_argument("--timeline-data", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=2025)
    parser.add_argument("--flow-rate-lpm", type=float, default=0.5)
    parser.add_argument("--step-min", type=float, default=10.0)
    parser.add_argument("--noise-std", type=float, default=0.1)
    return parser.parse_args()


def load_timestamped_csv(path: Path) -> pd.DataFrame:
    frame = pd.read_csv(path, parse_dates=["created_at"])
    if frame["created_at"].duplicated().any():
        raise ValueError(f"Duplicate timestamps in {path}")
    return frame.set_index("created_at").sort_index()


def fit_miso_arx(
    valve_data: pd.DataFrame, flow_rate_lpm: float, step_min: float
) -> np.ndarray:
    missing = REQUIRED_VALVE_COLUMNS.difference({"created_at", *valve_data.columns})
    if missing:
        raise KeyError(f"Missing baseline columns: {sorted(missing)}")

    soil = valve_data["soil_moisture"].to_numpy(dtype=float)
    irrigation = (
        valve_data["valve"].to_numpy(dtype=float) * flow_rate_lpm * step_min
    )
    temperature = valve_data["air_temp"].to_numpy(dtype=float)
    humidity = valve_data["humidity"].to_numpy(dtype=float)

    if len(soil) < 3:
        raise ValueError("At least three baseline samples are required")

    target = soil[2:]
    regressors = np.column_stack(
        [
            soil[1:-1],
            soil[:-2],
            irrigation[1:-1],
            temperature[1:-1],
            humidity[1:-1],
            np.ones(len(target)),
        ]
    )
    theta, *_ = np.linalg.lstsq(regressors, target, rcond=None)
    return theta


def build_excitation(index: pd.DatetimeIndex) -> np.ndarray:
    if len(index) < 2:
        raise ValueError("The excitation timeline requires at least two samples")

    order = 9
    sequence = max_len_seq(order)[0]
    tiled = np.tile(sequence, int(np.ceil(len(index) / len(sequence))))[: len(index)]
    prbs = (tiled.astype(float) * 2.0 - 1.0) * 50.0

    elapsed_seconds = (index - index[0]).total_seconds().to_numpy()
    slow_chirp = chirp(
        elapsed_seconds,
        f0=1.0 / (24.0 * 3600.0),
        f1=1.0 / (2.0 * 3600.0),
        t1=elapsed_seconds[-1],
        method="linear",
    ) * 10.0
    return prbs + slow_chirp


def generate_dataset(
    valve_data: pd.DataFrame,
    timeline_data: pd.DataFrame,
    theta: np.ndarray,
    seed: int,
    noise_std: float,
) -> pd.DataFrame:
    excitation = pd.DataFrame(
        {"water_input": build_excitation(timeline_data.index)},
        index=timeline_data.index,
    )
    baseline = valve_data[
        ["soil_moisture", "air_temp", "humidity"]
    ].rename(columns={"soil_moisture": "soil_seed"})
    data = excitation.join(baseline, how="inner")

    if len(data) != len(timeline_data):
        raise ValueError(
            "Timeline and baseline timestamps are not identical; refusing to "
            "silently shorten the historical workflow"
        )

    a1, a2, b_water, b_temperature, b_humidity, intercept = theta
    soil = np.zeros(len(data), dtype=float)
    soil[:2] = data["soil_seed"].mean()
    rng = np.random.default_rng(seed)

    for k in range(2, len(data)):
        soil[k] = (
            a1 * soil[k - 1]
            + a2 * soil[k - 2]
            + b_water * data["water_input"].iat[k - 1]
            + b_temperature * data["air_temp"].iat[k - 1]
            + b_humidity * data["humidity"].iat[k - 1]
            + intercept
            + rng.normal(0.0, noise_std)
        )

    data["soil_moisture_sim"] = soil
    return data


def main() -> None:
    args = parse_args()
    valve_data = load_timestamped_csv(args.valve_data)
    timeline_data = load_timestamped_csv(args.timeline_data)
    theta = fit_miso_arx(valve_data, args.flow_rate_lpm, args.step_min)
    result = generate_dataset(
        valve_data, timeline_data, theta, args.seed, args.noise_std
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.to_csv(args.output, index_label="created_at")

    names = ("a1", "a2", "b_water", "b_temperature", "b_humidity", "c")
    print("Fitted MISO ARX coefficients:")
    for name, value in zip(names, theta, strict=True):
        print(f"  {name} = {value:.12g}")
    print(f"Saved {len(result)} samples to {args.output}")


if __name__ == "__main__":
    main()

