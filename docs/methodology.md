# Methodology

## 1. Baseline measurements

An ESP32-S3 collected soil moisture, valve state, air temperature, and humidity and transmitted the records through ThingSpeak. This layer supported data acquisition; it was not the main control contribution.

## 2. Model-assisted persistent excitation

The physically collected baseline record was not itself a sufficiently rich PRBS experiment. A second-order MISO ARX model was fitted to the baseline signals:

```text
soil[k] = a1 soil[k-1] + a2 soil[k-2]
        + bw irrigation[k-1]
        + bt temperature[k-1]
        + bh humidity[k-1] + c
```

An order-9 PRBS and slow chirp were then used as computational excitation. The fitted ARX model produced `soil_moisture_sim`. This is best described as model-assisted data enrichment or a virtual excitation experiment.

## 3. MATLAB system identification

The generated record was imported as a one-output, three-input dataset. Candidate models included ARX, ARMAX, OE, BJ, and subspace state-space models. State-space selection was motivated by controller/estimator compatibility as well as validation fit.

Because the output was generated from an ARX model, validation on held-out portions measures recovery of the generated dynamics. It is not independent physical plant validation.

## 4. Control study

The selected model was used for discrete LQR with an integral channel and steady-state Kalman estimation. Supervisory simulation logic imposed duty saturation, hysteresis, and daily water budgets.

The current MATLAB simulation uses the irrigation input channel for control. Environmental signals are not applied as live measured disturbances in the main simulation.

## 5. Hardware status

The project team reports that the MATLAB controller was translated to Python and tested on a Raspberry Pi. That implementation will be added only when its source is available. Until then, hardware execution is project context rather than a reproducible repository result.

