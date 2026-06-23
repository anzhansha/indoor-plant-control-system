# Known limitations and unresolved assumptions

- The raw ThingSpeak export is unavailable in the public repository.
- The computational PRBS was not confirmed as a physically applied irrigation experiment.
- The final generator uses order 9; earlier order-7 scripts were trials.
- The generation input is an abstract signed excitation. Negative values are not irrigation volumes.
- The historical random-noise seed is unknown.
- The recovered dataset contains 4,320 samples over 30 days, not 2,160 samples over 15 days.
- Identification uses a 600-second sample interval. The main controller simulation re-discretizes the plant to 60 seconds.
- The preprocessing factor `720` has no recovered physical derivation.
- Baseline data-generation scripts assumed 0.5 L/min. Presentation material and later controller code contain other pump-flow values.
- Water-use and pump-duration claims must be recalculated after the physical flow convention is resolved.
- The historical integral-state design and runtime update use different sample-time scaling conventions.
- The current budget logic does not implement the documented integrator-freeze anti-windup rule.
- N4SID states are latent realization coordinates; state 1 must not be described as a direct soil-moisture measurement.
- Raspberry Pi source code and runtime logs are currently unavailable.

