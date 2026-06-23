# Advanced Control System Design for Indoor Plant Growth

Model-based soil-moisture control for indoor lettuce cultivation using experimental sensor data, PRBS-assisted system identification, discrete LQR with integral action, Kalman state estimation, and constrained irrigation logic.

**Authors:** Zhansha Ansagan, Assem Serikova, and Mussa Bolatbay  
**Supervisor:** Sanzhar Kusdavletov  
**Institution:** Astana IT University, Department of Intelligent Systems and Cybersecurity  
**Project:** BSc diploma project, June 2025

> **Figure to add:** `results/figures/system_overview.png` — complete sensing, identification, control, and irrigation workflow.

## Project overview

The objective of this project was to regulate soil moisture for indoor lettuce cultivation using a model-based feedback controller. The main work concentrated on experimental data preparation, dynamic system identification in MATLAB, state-space model selection, LQR/Kalman design, and practical irrigation constraints.

The ESP32-S3 served as the sensing and communication node. It collected baseline soil-moisture, valve-state, air-temperature, and humidity measurements and transmitted them through ThingSpeak. The controller was designed in MATLAB and later translated to Python for Raspberry Pi testing; that Python implementation is not currently included.

## Data collection and persistent excitation

Baseline measurements were recorded on a 10-minute grid:

- soil moisture;
- irrigation valve state;
- air temperature;
- relative humidity.

To obtain a richer identification input, the final data-generation workflow used an order-9 maximum-length PRBS with a sequence length of 511 samples. The PRBS was combined with a slow chirp:

$$
u[k] = u_{\mathrm{PRBS}}[k] + u_{\mathrm{chirp}}[k].
$$

The signed PRBS/chirp signal is a computational excitation signal, not a physical negative irrigation volume. A second-order MISO ARX model fitted from the baseline measurements generated the persistently excited soil-moisture response:

$$
y[k] = a_1y[k-1] + a_2y[k-2]
     + b_wu[k-1] + b_TT[k-1] + b_HH[k-1] + c + e[k].
$$

The final identification dataset contains **4,320 samples over 30 days** at a sampling interval of **600 seconds**. Temperature and humidity originate from the baseline record; `water_input` and `soil_moisture_sim` are generated signals.

> **Figures to add:**
> - `results/figures/prbs_valve_signal.png` — 24-hour binary PRBS schedule.
> - `results/figures/prbs_chirp_spectrum.png` — spectrum of the final order-9 PRBS plus chirp.
> - `results/figures/identification_dataset.png` — irrigation, temperature, humidity, and simulated soil-moisture series.

## System identification

The processed dataset was divided chronologically into estimation and validation subsets. Candidate models included ARX, ARMAX, Output Error, Box–Jenkins, first-order transfer-function, nonlinear Hammerstein–Wiener, and N4SID state-space structures.

The project reported the following validation results on the generated identification dataset:

| Model | Validation fit | FPE | MSE | Role |
|---|---:|---:|---:|---|
| ARX(4,4,1) | 90.13% | 0.009823 | 0.009663 | Lightweight benchmark |
| N4SID, 3 states | 90.08% | 0.009826 | 0.009663 | Selected for control design |
| ARMAX(2,2,1) | 89.53% | 0.01073 | 0.01067 | Explicit noise model |
| P1D | 84.36% | 0.01163 | 0.01151 | First-order comparison |
| NLHW | 79.0% | 0.3631 | 0.3618 | Nonlinear candidate |
| OE(2,2) | 68.15% | 0.9548 | 0.9468 | Output-error candidate |
| BJ(2,2,2,2) | 68.0% | 0.1013 | 0.1002 | Validation degradation |

ARX produced the highest reported fit, while the three-state N4SID model was selected because its state-space form supports LQR feedback and Kalman estimation directly.

The selected realization was reported as:

$$
A = \begin{bmatrix}
0 & 0 & -0.0122 \\
1 & 0 & -0.613 \\
0 & 1 & 1.61
\end{bmatrix},\quad
B = \begin{bmatrix}
1 & -12.7 & -1.50 \\
0 & -2.53 & -36.6 \\
0 & 13.3 & 40.8
\end{bmatrix},
$$

$$
C = \begin{bmatrix}0.0185 & 0.0171 & 0.0164\end{bmatrix}.
$$

> **Figures to add:**
> - `results/figures/arx441_residuals.png` — ARX residual autocorrelation and input cross-correlation.
> - `results/figures/n4sid3_residuals.png` — three-state N4SID residual diagnostics.
> - `results/figures/model_validation_comparison.png` — measured/generated validation output versus candidate predictions.

## LQR with integral action

For controller synthesis, the discrete plant was augmented with an integral tracking state:

$$
\widetilde{x}[k] = \begin{bmatrix}x[k] \\ w[k]\end{bmatrix},\qquad
\widetilde{A} = \begin{bmatrix}A & 0 \\ -C & 1\end{bmatrix},\qquad
\widetilde{B} = \begin{bmatrix}B \\ 0\end{bmatrix}.
$$

The controller minimizes

$$
J = \sum_{k=0}^{\infty}
\left(\widetilde{x}^{\mathsf T}Q_e\widetilde{x} + u^{\mathsf T}Ru\right),
$$

using the historical tuning

$$
Q_x = \operatorname{diag}(10,1,1),\qquad q_w=0.05,\qquad R=200.
$$

The resulting command has the form

$$
u_{\mathrm{raw}}[k] = -K_x\widehat{x}[k] - K_iw[k] + N_br[k].
$$

## Kalman state estimation

A steady-state Kalman filter estimates the state from the soil-moisture output:

$$
\widehat{x}[k+1] = A\widehat{x}[k] + Bu[k]
+ L\left(y[k]-C\widehat{x}[k]\right).
$$

The design uses

$$
Q_k = 10^{-6}I_3,\qquad R_k = 10^{-4}.
$$

The N4SID states are internal realization coordinates; soil moisture is the model output $y=Cx$ rather than an individual state coordinate.

## Constrained irrigation simulation

The 35-day simulation combines the controller and estimator with supervisory irrigation rules:

- five weekly moisture targets: 20%, 22%, 25%, 28%, and 30%;
- weekly water budgets of 350, 450, 550, 650, and 750 mL;
- actuator command saturation to $0 \leq u \leq 1$;
- a $\pm0.5\%$ moisture hysteresis band;
- integrator handling around constraint activation;
- pump-duty and daily-volume accounting.

The historical simulation reported an integral absolute error of approximately $6.45\times10^5$ moisture·s and total simulated water use of approximately 2.73 L. These values depend on the historical pump-flow conversion and should be interpreted as simulation results rather than independent field measurements.

> **Figures to add:**
> - `results/figures/moisture_tracking.png` — 35-day soil-moisture trajectory and piecewise set point.
> - `results/figures/state_estimation.png` — true versus Kalman-estimated state.
> - `results/figures/daily_water.png` — daily water allocation and pump ON time.
> - `results/figures/pump_durations.png` — distribution of simulated pump activation durations.
> - `results/figures/raw_control_signal.png` — unconstrained LQR-integral command.
> - `results/figures/tracking_error.png` — moisture tracking error.

## Hardware implementation

The experimental platform included:

- ESP32-S3 sensing and communication node;
- capacitive soil-moisture sensor;
- air-temperature and humidity sensor;
- relay-driven irrigation pump;
- Raspberry Pi 5 used for the later Python controller prototype.

Baseline acquisition through the ESP32-S3 and ThingSpeak was physically implemented. The project team also tested a Python translation of the controller on the Raspberry Pi, but the source and runtime logs are not presently available in this repository. Therefore, the included code supports the MATLAB identification and simulation results; complete reproduction of the Raspberry Pi deployment is future repository work.

> **Figures to add:**
> - `results/figures/hardware_stack.jpg` — Raspberry Pi, ESP32-S3, sensors, relay, and pump.
> - `results/figures/hardware_block_diagram.png` — sensing, communication, controller, and actuator flow.
> - `results/figures/field_setup_1.jpg` and `field_setup_2.jpg` — physical cultivation setup.

## Repository contents

```text
data/processed/                 Identification datasets
python/data_generation/         Recovered PRBS/chirp and MISO-ARX generation
matlab/01_preprocessing/        Data preparation and estimation/validation split
matlab/02_system_identification Candidate-model comparison and diagnostics
matlab/03_control_design/       Control-design documentation
matlab/04_simulation/           Constrained LQR/Kalman simulation
results/models/                 Archived MATLAB model artifacts
results/figures/                Project figures
docs/                           Detailed methodology and known limitations
hardware/                       Hardware scope and future source files
```

## Main conclusions

- Persistently excited, model-generated data enabled systematic comparison of several linear and nonlinear model structures.
- ARX and three-state N4SID models achieved approximately 90% validation fit on the generated dataset.
- N4SID provided a convenient state-space realization for LQR and Kalman-filter design.
- The simulation demonstrates how saturation, hysteresis, and water budgets can be integrated with model-based feedback.
- The hardware layer supported real data acquisition and later controller prototyping, while the repository's principal contribution remains MATLAB system identification and control design.

## References

1. P. Van Overschee and B. De Moor, *Subspace Identification for Linear Systems*, Kluwer, 1996.
2. L. Ljung, *System Identification: Theory for the User*, 2nd ed., Prentice Hall, 1999.
3. K. Ogata, *Modern Control Engineering*, 5th ed., Prentice Hall, 2010.
4. E. J. van Henten, “Validation of a dynamic lettuce growth model for greenhouse climate control,” *Agricultural Systems*, 45, 55–72, 1994.

