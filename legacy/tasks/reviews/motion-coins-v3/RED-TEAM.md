# Coin Motion V3 - Red Team

V3 is an architecture gate, not a visual prototype. Its job is to falsify the
smallest useful 3D contact core before renderer or multi-coin work resumes.

## Attacks this experiment must survive

1. **Global energy deletion**
   No exponential or unconditional damping may run merely because a contact
   exists. Restitution, Coulomb friction, and explicitly bounded rolling
   resistance are the only permitted dissipative mechanisms.
2. **Hidden freezing**
   Rest is not proven by assigning linear or angular velocity to zero. The
   solver must continue for at least 0.5 seconds after a rest candidate and keep
   the body inside the velocity envelope through contact impulses alone.
3. **Penetration laundering**
   Maximum raw penetration is measured before any positional correction and is
   a mandatory gate. Corrected residual penetration is reported separately.
4. **Hidden time resolution**
   The same fixtures run at real outer steps of 60, 120, and 240 Hz. Event-time
   splitting for a detected impact is allowed; fixed physics substeps are not.
5. **A fitted happy path**
   Both a central face impact and an inclined edge/lip impact run as perturbation
   matrices. A single hand-tuned trajectory cannot make the suite green.
6. **Fake 3D geometry**
   The body is an analytic finite cylinder with a normalized quaternion. Plane
   support is computed analytically from cylinder radius, half-thickness, and
   body axis; it is not a sampled point cloud or a heightfield lookup.
7. **Tautological verification**
   Gates compare independently observed states across time steps and fixtures.
   A digest compared with itself, post-correction penetration, or a sleep flag
   is not evidence.

## Immediate RED conditions

- Any mandatory gate fails at any required step rate.
- Source contains a contact-wide damping multiplier or a rest-time velocity
  zeroing path.
- Raw penetration is unavailable or substituted with corrected penetration.
- 60/120/240 Hz results only converge after an undisclosed fixed substep.
- The central or edge/lip perturbation matrix is missing.

On RED, the executable exits non-zero and prints the failed evidence. Renderer,
multi-coin behavior, and visual tuning remain out of scope until every contract
item is honestly green.
