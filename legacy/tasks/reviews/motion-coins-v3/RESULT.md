# Coin Motion V3 - RED Result

## Verdict

**RED. Do not proceed to renderer or multi-coin work.**

The production executable built with Swift 6 and ran the unchanged acceptance
contract. It exited with status `1`: 18 of 352 mandatory checks failed.

Command:

```sh
swift run -c release motion-coins-v3-gates
```

An additional `swift build -c release` completed successfully.

## Evidence

The analytic free-flight propagator passed at 60, 120, and 240 Hz:

| Rate | Relative energy drift | Relative angular-momentum drift | Quaternion norm error |
| ---: | ---: | ---: | ---: |
| 60 Hz | `2.80e-15` | `2.15e-15` | `1.11e-16` |
| 120 Hz | `1.59e-14` | `5.76e-15` | `2.22e-16` |
| 240 Hz | `1.73e-14` | `2.07e-15` | `2.22e-16` |

The central zero-tilt cases and every inclined lip case passed their collision,
raw-penetration, energy, and 60/120/240 convergence checks. The central rest
case also stayed inside the velocity envelope for at least 0.5 seconds while
the solver continued advancing, without a sleep path or velocity assignment.

The central `-3°` and `+3°` perturbations failed:

| Measurement | 60 Hz | 120 Hz | 240 Hz | Contract |
| --- | ---: | ---: | ---: | ---: |
| Maximum raw penetration | `10.169 mm` | `10.169 mm` | `3.895 mm` | `<= 0.150 mm` |
| Energy growth | `5.990e-05 J` | `5.990e-05 J` | approximately zero | `<= 1%` initial scale |
| Orientation delta vs 240 Hz | `2.907°` | `1.762°` | reference | `<= 1.0°` |

The 60 Hz result additionally missed position convergence (`0.840 mm` versus a
`0.750 mm` limit) and energy convergence (`5.008%` versus a `2%` limit).

## Root cause

An analytic cylinder support point is sufficient for the first isolated plane
impact, but not for the evolving contact manifold of a slightly tilted face.
After the first edge impulse, the current single-point event loop enters repeated
near-zero-time contacts. Once its bounded event budget is exhausted, it accepts a
deeply penetrating state and moves the center out along the plane normal. The
mandatory raw metric exposes the penetration before correction; the correction
then explains the artificial potential-energy increase.

This is an architectural failure, not a tolerance issue. A credible next
experiment needs an analytic face/edge contact manifold with a persistent
constraint solve (or an equivalent complementarity formulation) and a
non-penetrating event continuation. The V3 gates and perturbations should remain
unchanged for that attempt.

## Source audit

The core contains no fixed physics substep, sleep transition, contact-wide
damping multiplier, or assignment of either body velocity to zero. Event-time
bisection is used only to locate an impact. Raw and corrected residual
penetration are recorded as separate values.
