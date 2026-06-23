# Data

## Provenance

Baseline soil-moisture, valve, temperature, and humidity measurements were collected using an ESP32-S3 and ThingSpeak. The raw ThingSpeak export is not included because the original source is unavailable for publication.

The processed identification dataset is model-generated. The final recovered workflow was:

1. Fit a second-order MISO ARX regression to baseline measurements.
2. Generate an order-9 maximum-length sequence.
3. Scale it to `[-50, 50]` and add a chirp with amplitude 10.
4. Reuse the baseline temperature and humidity profiles.
5. Simulate soil moisture with the fitted ARX coefficients and additive Gaussian noise.

The negative `water_input` values are synthetic excitation values. They are not physically realizable negative irrigation volumes and must not be interpreted as liters.

## Processed files

### `processed/system_identification_dataset.csv`

| Column | Meaning | Origin |
|---|---|---|
| `created_at` | Sample timestamp, 10-minute interval | Baseline timeline |
| `water_input` | PRBS plus chirp excitation, nominal range about -60 to 60 | Generated |
| `soil_seed` | Baseline soil-moisture series used for alignment/seeding | Measured baseline series |
| `air_temp` | Air temperature | Baseline measurement |
| `humidity` | Relative humidity | Baseline measurement |
| `soil_moisture_sim` | MISO ARX simulated soil-moisture response | Generated |

The file contains 4,320 rows covering 30 days at a 600-second sample interval.

### `processed/normalized_identification_dataset.csv`

The recovered transformation is:

```text
soil_frac = soil_moisture_sim / 100
u_irrig   = max(water_input, 0) / 720
```

The factor 720 is retained to reproduce the historical dataset, but its physical derivation has not been recovered. It must not be silently reinterpreted as pump calibration.

## Reproducibility limitation

The historical generator added random noise without recording a seed. The committed CSV is therefore the canonical historical artifact. New generator runs use an explicit seed and will not be byte-identical to the historical file.

