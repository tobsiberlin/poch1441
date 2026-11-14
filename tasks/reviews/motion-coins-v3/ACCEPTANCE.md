# Coin Motion V3 - Acceptance Contract

## Scope

The experiment contains one dynamic rigid coin and one analytic static plane.
It has no renderer, no SpriteKit integration, and no multi-coin path.

The coin uses radius `0.011 m`, thickness `0.0022 m`, mass `0.0045 kg`, and
gravity `9.81 m/s²`. State is full 3D position, linear velocity, normalized
quaternion orientation, and angular velocity.

## Mandatory gates

1. **Free flight** - over 1.0 second, relative mechanical-energy drift is at
   most `1e-10`, quaternion norm error is at most `1e-12`, and angular-momentum
   drift is at most `1e-10` at 60, 120, and 240 Hz.
2. **Raw penetration** - maximum pre-correction penetration is at most
   `0.00015 m` in every matrix case and at every required rate. Raw and residual
   values are both printed.
3. **Step convergence** - each fixture is simulated at true outer rates of 60,
   120, and 240 Hz with no fixed substeps. Relative to 240 Hz, first-impact time
   differs by at most `0.0001 s`, final center position by at most `0.00075 m`,
   final orientation by at most `1.0°`, and final mechanical energy by at most
   `2%` of the initial energy scale.
4. **Contact energy** - contact never creates more than `1%` of the initial
   energy scale. Dissipation comes only from restitution and Coulomb friction;
   there is no global contact damping.
5. **Sustained rest** - the central baseline must remain below `0.015 m/s`
   linear speed and `0.8 rad/s` angular speed for a continuous 0.5-second audit
   while the solver keeps advancing. No rest or sleep path may assign either
   velocity to zero.
6. **Perturbation coverage** - the suite contains a central face matrix and an
   inclined edge/lip matrix. Each has a baseline plus changes in launch speed,
   orientation, and lateral/tangential offset. Every case must remain finite,
   collide, and pass penetration and energy gates.
7. **Implementation audit** - the release runner verifies that no fixed-substep,
   sleep, velocity-zeroing, or contact-wide damping mechanism is configured by
   the core. Event-time impact splitting is reported separately and is allowed.

## Verdict

`GREEN` is printed only when all mandatory gates pass. Any failure prints `RED`,
lists the measured violation, and exits with a non-zero status. Tests are not
relaxed to rescue the solver; a failing architecture stops here.
