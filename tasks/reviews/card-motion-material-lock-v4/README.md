# Card Motion Material Lock V4

Isolated one-card Track-B material-readability proof. V1, V2 and V3 geometry,
timing, contact and motion are hash-bound. The V4 Model, Controller, Stage and
W2 material contract are byte-identical to V3; the product App remains
read-only.

## Material-only hypothesis

At the real 54.85 px target-card width, matte printed stock should read through
directional continuity and edge behavior, not large local spots. Replacing V3's
blurred oval layer with irregular directional fibres, sparse bent print dropout
and narrow edge compression should preserve a physical stock signal without a
polka-like cadence.

Fail-fast static gate at the real 402 x 874 viewport:

```sh
./Scripts/run.sh static
```

Only after visually approving that pair, reuse the same build for the uncut
wallclock sequence:

```sh
MATERIAL_LOCK_SKIP_BUILD=1 ./Scripts/run.sh full
```
