# Figure checklist

Add the final exported images using these exact paths so they appear in the main README.

| Filename | Required content | Source mentioned in presentation |
|---|---|---|
| `system_overview.png` | Complete workflow overview | New combined overview or block diagram |
| `prbs_valve_signal.png` | 24-hour binary PRBS schedule | `24h_PRBS_valve_signal.png` |
| `prbs_chirp_spectrum.png` | Final order-9 PRBS/chirp spectrum | Python FFT plot |
| `identification_dataset.png` | Four-channel identification data overview | MATLAB/Python data plot |
| `arx441_residuals.png` | ARX(4,4,1) residual diagnostics | `arx441_resid.png` |
| `n4sid3_residuals.png` | Three-state N4SID residual diagnostics | `ss1_resid.png` |
| `model_validation_comparison.png` | Candidate-model validation comparison | System Identification results |
| `moisture_tracking.png` | 35-day moisture and set-point trajectory | `try47_moisture_plot.png` |
| `state_estimation.png` | True versus estimated state | `x1_est_vs_true.png` |
| `daily_water.png` | Daily water and pump ON time | `daily_water.png` |
| `pump_durations.png` | Pump-duration histogram | `pump_durations.png` |
| `raw_control_signal.png` | Raw LQR-integral command | `raw_u.png` |
| `tracking_error.png` | Tracking-error history | MATLAB simulation figure 6 |
| `hardware_stack.jpg` | Raspberry Pi/ESP32/sensor/pump stack | `hw_stack_photo_s.png` |
| `hardware_block_diagram.png` | Hardware I/O and control flow | `block_diagram_hw.png` |
| `field_setup_1.jpg` | Full physical setup | `field_photo1.png` |
| `field_setup_2.jpg` | Wiring/sensor close-up | `field_photo2.png` |

Export MATLAB figures as PNG at sufficient resolution for GitHub. Do not add screenshots containing credentials, ThingSpeak API keys, Wi-Fi details, private IP addresses, or personal account information.

