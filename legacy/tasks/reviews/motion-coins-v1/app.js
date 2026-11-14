(() => {
  "use strict";

  const canvas = document.querySelector("#coinCanvas");
  const context = canvas.getContext("2d", { alpha: false, desynchronized: true });
  const stage = document.querySelector(".stage-card");
  const playButton = document.querySelector("#playButton");
  const pauseButton = document.querySelector("#pauseButton");
  const replayButton = document.querySelector("#replayButton");
  const sceneTabs = [...document.querySelectorAll(".scene-tab")];
  const motionInputs = [...document.querySelectorAll('input[name="motion"]')];

  const labels = {
    seed: document.querySelector("#seedLabel"),
    kicker: document.querySelector("#sceneKicker"),
    title: document.querySelector("#sceneTitle"),
    pill: document.querySelector("#statePill"),
    state: document.querySelector("#stateLabel"),
    settle: document.querySelector("#settleValue"),
    collisions: document.querySelector("#collisionValue"),
    stable: document.querySelector("#stableValue"),
    fps: document.querySelector("#fpsValue"),
  };

  const FIXED_STEP = 1 / 120;
  const MAX_FRAME = 1 / 20;
  const TAU = Math.PI * 2;
  const SCENARIOS = {
    outer: {
      seed: 144101,
      kicker: "TRACK A · EINWURF",
      title: "Einsatz in die Außenmulde",
      count: 8,
      target: "outer",
      targetCenter: [0.72, 0.52],
      source: [0.11, 0.22],
      flight: 0.72,
      stagger: 0.082,
    },
    center: {
      seed: 144203,
      kicker: "TRACK A · AUSZAHLUNG",
      title: "Poch-Auszahlung in die Mitte",
      count: 12,
      target: "center",
      targetCenter: [0.5, 0.53],
      source: [0.86, 0.2],
      flight: 0.78,
      stagger: 0.063,
    },
    snackbox: {
      seed: 144307,
      kicker: "TRACK B · MATERIALWELT",
      title: "Münzen in der Snackbox",
      count: 10,
      target: "snackbox",
      targetCenter: [0.62, 0.55],
      source: [0.12, 0.19],
      flight: 0.82,
      stagger: 0.074,
    },
  };

  const state = {
    scenarioKey: "outer",
    motion: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "reduced" : "normal",
    width: 1,
    height: 1,
    dpr: 1,
    coins: [],
    running: false,
    paused: false,
    completed: false,
    simTime: 0,
    settleTime: null,
    accumulator: 0,
    lastFrame: performance.now(),
    fpsFrames: 0,
    fpsSampleStart: performance.now(),
    fps: 60,
    collisions: 0,
    clipViolations: 0,
    status: "ready",
  };

  class SeededRandom {
    constructor(seed) {
      this.value = seed >>> 0;
    }

    next() {
      let value = (this.value += 0x6d2b79f5);
      value = Math.imul(value ^ (value >>> 15), value | 1);
      value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
      return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
    }

    between(minimum, maximum) {
      return minimum + (maximum - minimum) * this.next();
    }
  }

  function scenario() {
    return SCENARIOS[state.scenarioKey];
  }

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value));
  }

  function roundedRectPath(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + width, y, x + width, y + height, r);
    ctx.arcTo(x + width, y + height, x, y + height, r);
    ctx.arcTo(x, y + height, x, y, r);
    ctx.arcTo(x, y, x + width, y, r);
    ctx.closePath();
  }

  function geometry() {
    const config = scenario();
    const shortEdge = Math.min(state.width, state.height);
    const center = {
      x: config.targetCenter[0] * state.width,
      y: config.targetCenter[1] * state.height,
    };
    const source = {
      x: config.source[0] * state.width,
      y: config.source[1] * state.height,
    };

    if (config.target === "snackbox") {
      const width = clamp(state.width * 0.48, 176, 390);
      const height = clamp(state.height * 0.47, 96, 260);
      return {
        source,
        center,
        radius: clamp(shortEdge * 0.045, 8.5, 13),
        target: {
          kind: "rect",
          x: center.x - width / 2,
          y: center.y - height / 2,
          width,
          height,
          inset: clamp(shortEdge * 0.055, 12, 24),
        },
      };
    }

    const radius = config.target === "center"
      ? clamp(shortEdge * 0.25, 62, 150)
      : clamp(shortEdge * 0.205, 50, 124);
    return {
      source,
      center,
      radius: clamp(shortEdge * 0.045, 8.5, 13),
      target: { kind: "circle", x: center.x, y: center.y, radius },
    };
  }

  function slotLayout(config, geo, random) {
    const slots = [];
    const coinRadius = geo.radius;
    const count = config.count;

    if (geo.target.kind === "rect") {
      const inner = {
        x: geo.target.x + geo.target.inset + coinRadius,
        y: geo.target.y + geo.target.inset + coinRadius,
        width: geo.target.width - 2 * (geo.target.inset + coinRadius),
        height: geo.target.height - 2 * (geo.target.inset + coinRadius),
      };
      const columns = state.width < 500 ? 3 : 4;
      const rows = Math.max(2, Math.ceil(Math.min(count, 8) / columns));
      for (let index = 0; index < count; index += 1) {
        const baseIndex = index % Math.min(count, columns * rows);
        const column = baseIndex % columns;
        const row = Math.floor(baseIndex / columns);
        const level = Math.floor(index / (columns * rows));
        slots.push({
          x: inner.x + (columns === 1 ? 0.5 : column / (columns - 1)) * inner.width
            + random.between(-1.8, 1.8),
          y: inner.y + (rows === 1 ? 0.5 : row / (rows - 1)) * inner.height
            + random.between(-1.5, 1.5),
          z: level * 3.4,
          angle: random.between(-0.16, 0.16),
        });
      }
      return slots;
    }

    const rings = config.target === "center"
      ? [[0, 1], [0.34, 6], [0.61, 8]]
      : [[0, 1], [0.42, 5], [0.69, 8]];
    let emitted = 0;
    for (const [radiusRatio, capacity] of rings) {
      for (let index = 0; index < capacity && emitted < count; index += 1) {
        const level = emitted >= 8 ? 1 : 0;
        const angle = (index / capacity) * TAU + random.between(-0.08, 0.08);
        const spread = (geo.target.radius - coinRadius * 1.3) * radiusRatio;
        slots.push({
          x: geo.center.x + Math.cos(angle) * spread,
          y: geo.center.y + Math.sin(angle) * spread * 0.56,
          z: level * 3.4,
          angle: random.between(-0.2, 0.2),
        });
        emitted += 1;
      }
      if (emitted >= count) break;
    }
    return slots;
  }

  function createCoins() {
    const config = scenario();
    const geo = geometry();
    const random = new SeededRandom(config.seed);
    const slots = slotLayout(config, geo, random);
    const reduced = state.motion === "reduced";

    state.coins = slots.map((slot, index) => {
      const spawnAt = index * (reduced ? 0.026 : config.stagger);
      const flightTime = config.flight + random.between(-0.055, 0.055);
      const sourceX = reduced ? slot.x + random.between(-7, 7) : geo.source.x + random.between(-9, 9);
      const sourceY = reduced ? slot.y + random.between(-5, 5) : geo.source.y + random.between(-5, 5);
      const startZ = reduced ? 1.5 : geo.radius * random.between(0.6, 1.2);
      const gravity = reduced ? 0 : clamp(Math.min(state.width, state.height) * 2.15, 480, 980);
      const velocityX = reduced ? 0 : (slot.x - sourceX) / flightTime + random.between(-13, 13);
      const velocityY = reduced ? 0 : (slot.y - sourceY) / flightTime + random.between(-9, 9);
      const velocityZ = reduced ? 0 : (0.5 * gravity * flightTime * flightTime - startZ) / flightTime;
      return {
        index,
        radius: geo.radius * random.between(0.96, 1.03),
        x: sourceX,
        y: sourceY,
        z: startZ,
        vx: velocityX,
        vy: velocityY,
        vz: velocityZ,
        angle: random.between(-0.35, 0.35),
        angularVelocity: reduced ? 0 : random.between(-4.3, 4.3),
        gravity,
        spawnAt,
        active: false,
        contained: reduced,
        settling: reduced,
        settled: false,
        restDuration: 0,
        slot,
        opacity: reduced ? 0 : 1,
      };
    });
  }

  function reset({ autoplay = false } = {}) {
    state.running = autoplay;
    state.paused = false;
    state.completed = false;
    state.simTime = 0;
    state.settleTime = null;
    state.accumulator = 0;
    state.collisions = 0;
    state.clipViolations = 0;
    state.status = autoplay ? "running" : "ready";
    createCoins();
    updateControls();
    updateLabels();
    draw();
  }

  function activateCoin(coin) {
    if (coin.active || state.simTime < coin.spawnAt) return;
    coin.active = true;
  }

  function stepCoin(coin, delta, geo) {
    activateCoin(coin);
    if (!coin.active || coin.settled) return;

    if (state.motion === "reduced") {
      coin.opacity = Math.min(1, coin.opacity + delta * 6.5);
      springCoinToSlot(coin, delta, 86, 18);
      return;
    }

    if (!coin.settling) {
      coin.vz -= coin.gravity * delta;
      coin.x += coin.vx * delta;
      coin.y += coin.vy * delta;
      coin.z += coin.vz * delta;
      coin.angle += coin.angularVelocity * delta;

      if (coin.z <= 0) {
        coin.z = 0;
        if (coin.vz < -38) {
          coin.vz = -coin.vz * 0.24;
          coin.vx *= 0.83;
          coin.vy *= 0.83;
          coin.angularVelocity *= 0.62;
          state.collisions += 1;
        } else {
          coin.vz = 0;
        }
        if (pointInsideTarget(coin, geo, coin.radius * 0.35)) {
          coin.contained = true;
        }
      }

      if (coin.z < coin.radius * 0.7) {
        const friction = Math.pow(0.13, delta);
        coin.vx *= friction;
        coin.vy *= friction;
        coin.angularVelocity *= Math.pow(0.09, delta);
        if (coin.contained) collideWithTarget(coin, geo);
      }

      const speed = Math.hypot(coin.vx, coin.vy, coin.vz * 0.35);
      if (coin.contained && coin.z <= 0.1 && speed < 32 && state.simTime > coin.spawnAt + 0.78) {
        coin.restDuration += delta;
        if (coin.restDuration > 0.09) coin.settling = true;
      } else {
        coin.restDuration = 0;
      }

      if (state.simTime > coin.spawnAt + 1.65) {
        coin.contained = true;
        coin.settling = true;
      }
    }

    if (coin.settling) springCoinToSlot(coin, delta, 72, 15);
  }

  function springCoinToSlot(coin, delta, stiffness, damping) {
    const accelerationX = (coin.slot.x - coin.x) * stiffness - coin.vx * damping;
    const accelerationY = (coin.slot.y - coin.y) * stiffness - coin.vy * damping;
    const accelerationZ = (coin.slot.z - coin.z) * stiffness - coin.vz * damping;
    coin.vx += accelerationX * delta;
    coin.vy += accelerationY * delta;
    coin.vz += accelerationZ * delta;
    coin.x += coin.vx * delta;
    coin.y += coin.vy * delta;
    coin.z = Math.max(0, coin.z + coin.vz * delta);
    coin.angle += (coin.slot.angle - coin.angle) * Math.min(1, delta * 9);

    const positionError = Math.hypot(coin.slot.x - coin.x, coin.slot.y - coin.y, coin.slot.z - coin.z);
    const velocity = Math.hypot(coin.vx, coin.vy, coin.vz);
    if (positionError < 0.22 && velocity < 0.42 && coin.opacity > 0.995) {
      coin.restDuration += delta;
      if (coin.restDuration > 0.16) {
        coin.x = coin.slot.x;
        coin.y = coin.slot.y;
        coin.z = coin.slot.z;
        coin.vx = 0;
        coin.vy = 0;
        coin.vz = 0;
        coin.settled = true;
      }
    } else {
      coin.restDuration = 0;
    }
  }

  function pointInsideTarget(coin, geo, inset = 0) {
    const target = geo.target;
    if (target.kind === "circle") {
      const dx = coin.x - target.x;
      const dy = (coin.y - target.y) / 0.58;
      return Math.hypot(dx, dy) <= target.radius - coin.radius - inset;
    }
    return coin.x >= target.x + target.inset + coin.radius + inset
      && coin.x <= target.x + target.width - target.inset - coin.radius - inset
      && coin.y >= target.y + target.inset + coin.radius + inset
      && coin.y <= target.y + target.height - target.inset - coin.radius - inset;
  }

  function collideWithTarget(coin, geo) {
    const target = geo.target;
    if (target.kind === "circle") {
      const dx = coin.x - target.x;
      const scaledY = (coin.y - target.y) / 0.58;
      const distance = Math.hypot(dx, scaledY) || 1;
      const limit = target.radius - coin.radius * 1.08;
      if (distance > limit) {
        const nx = dx / distance;
        const ny = scaledY / distance;
        coin.x = target.x + nx * limit;
        coin.y = target.y + ny * limit * 0.58;
        const normalVelocity = coin.vx * nx + coin.vy * ny;
        if (normalVelocity > 0) {
          coin.vx -= normalVelocity * nx * 1.45;
          coin.vy -= normalVelocity * ny * 1.45;
          state.collisions += 1;
        }
      }
      return;
    }

    const minimumX = target.x + target.inset + coin.radius;
    const maximumX = target.x + target.width - target.inset - coin.radius;
    const minimumY = target.y + target.inset + coin.radius;
    const maximumY = target.y + target.height - target.inset - coin.radius;
    if (coin.x < minimumX || coin.x > maximumX) {
      coin.x = clamp(coin.x, minimumX, maximumX);
      coin.vx *= -0.38;
      state.collisions += 1;
    }
    if (coin.y < minimumY || coin.y > maximumY) {
      coin.y = clamp(coin.y, minimumY, maximumY);
      coin.vy *= -0.38;
      state.collisions += 1;
    }
  }

  function resolveCoinCollisions() {
    const coins = state.coins.filter((coin) => coin.active && !coin.settled
      && !coin.settling && coin.z < coin.radius * 0.72);
    for (let leftIndex = 0; leftIndex < coins.length; leftIndex += 1) {
      for (let rightIndex = leftIndex + 1; rightIndex < coins.length; rightIndex += 1) {
        const left = coins[leftIndex];
        const right = coins[rightIndex];
        if (Math.abs(left.z - right.z) > 4.2) continue;
        const dx = right.x - left.x;
        const dy = right.y - left.y;
        const distance = Math.hypot(dx, dy) || 0.001;
        const minimum = (left.radius + right.radius) * 0.82;
        if (distance >= minimum) continue;
        const nx = dx / distance;
        const ny = dy / distance;
        const overlap = minimum - distance;
        if (!left.settling) {
          left.x -= nx * overlap * 0.5;
          left.y -= ny * overlap * 0.5;
        }
        if (!right.settling) {
          right.x += nx * overlap * 0.5;
          right.y += ny * overlap * 0.5;
        }
        const relativeVelocity = (right.vx - left.vx) * nx + (right.vy - left.vy) * ny;
        if (relativeVelocity < 0) {
          const impulse = -relativeVelocity * 0.34;
          left.vx -= impulse * nx;
          left.vy -= impulse * ny;
          right.vx += impulse * nx;
          right.vy += impulse * ny;
          state.collisions += 1;
        }
      }
    }
  }

  function simulationStep(delta) {
    state.simTime += delta;
    const geo = geometry();
    for (const coin of state.coins) stepCoin(coin, delta, geo);
    if (state.motion === "normal") resolveCoinCollisions();

    const settled = state.coins.filter((coin) => coin.settled).length;
    if (!state.completed && settled === state.coins.length) {
      state.completed = true;
      state.running = false;
      state.settleTime = state.simTime;
      state.status = "settled";
      updateControls();
    }

    auditClipping();
  }

  function auditClipping() {
    let clipped = false;
    for (const coin of state.coins) {
      if (!coin.active) continue;
      const screenY = coin.y - coin.z * 0.56;
      if (coin.x - coin.radius < 0 || coin.x + coin.radius > state.width
          || screenY - coin.radius < 0 || screenY + coin.radius + 5 > state.height) {
        clipped = true;
        break;
      }
    }
    if (clipped) state.clipViolations += 1;
  }

  function drawBackground(ctx, width, height) {
    const gradient = ctx.createLinearGradient(0, 0, width, height);
    gradient.addColorStop(0, "#3b2a1d");
    gradient.addColorStop(0.48, "#251a13");
    gradient.addColorStop(1, "#17110d");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.globalAlpha = 0.12;
    ctx.strokeStyle = "#d2a56b";
    ctx.lineWidth = 1;
    const spacing = Math.max(32, width / 12);
    for (let x = -height; x < width + height; x += spacing) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x + height * 0.22, height);
      ctx.stroke();
    }
    ctx.restore();

    const vignette = ctx.createRadialGradient(width * 0.52, height * 0.42, 0,
      width * 0.52, height * 0.42, Math.max(width, height) * 0.72);
    vignette.addColorStop(0, "rgba(255,225,170,0.07)");
    vignette.addColorStop(0.62, "rgba(0,0,0,0.05)");
    vignette.addColorStop(1, "rgba(0,0,0,0.58)");
    ctx.fillStyle = vignette;
    ctx.fillRect(0, 0, width, height);
  }

  function drawTarget(ctx, geo) {
    if (scenario().target === "snackbox") {
      drawSnackbox(ctx, geo);
      return;
    }

    const target = geo.target;
    if (scenario().target === "center") {
      ctx.save();
      ctx.translate(target.x, target.y);
      for (let index = 0; index < 8; index += 1) {
        const angle = index / 8 * TAU;
        const x = Math.cos(angle) * target.radius * 1.48;
        const y = Math.sin(angle) * target.radius * 0.83;
        ctx.beginPath();
        ctx.ellipse(x, y, target.radius * 0.3, target.radius * 0.18, 0, 0, TAU);
        ctx.fillStyle = "rgba(12,9,7,0.34)";
        ctx.fill();
        ctx.strokeStyle = "rgba(205,170,110,0.12)";
        ctx.lineWidth = 1;
        ctx.stroke();
      }
      ctx.restore();
    }

    ctx.save();
    ctx.translate(target.x, target.y);
    ctx.scale(1, 0.58);
    const outer = ctx.createRadialGradient(-target.radius * 0.18, -target.radius * 0.2, 4,
      0, 0, target.radius);
    outer.addColorStop(0, "#33261c");
    outer.addColorStop(0.7, "#15100d");
    outer.addColorStop(1, "#080605");
    ctx.beginPath();
    ctx.arc(0, 0, target.radius, 0, TAU);
    ctx.fillStyle = outer;
    ctx.shadowColor = "rgba(0,0,0,0.65)";
    ctx.shadowBlur = 22;
    ctx.shadowOffsetY = 12;
    ctx.fill();
    ctx.shadowColor = "transparent";
    ctx.strokeStyle = "rgba(211,177,115,0.34)";
    ctx.lineWidth = 4;
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(0, 0, target.radius * 0.85, 0, TAU);
    ctx.strokeStyle = "rgba(225,208,177,0.12)";
    ctx.lineWidth = 1.2;
    ctx.stroke();
    ctx.restore();
  }

  function drawSnackbox(ctx, geo) {
    const target = geo.target;
    const lip = Math.max(8, target.inset * 0.65);
    ctx.save();
    ctx.shadowColor = "rgba(0,0,0,0.66)";
    ctx.shadowBlur = 24;
    ctx.shadowOffsetY = 12;
    roundedRectPath(ctx, target.x, target.y, target.width, target.height, 24);
    ctx.fillStyle = "rgba(81,73,62,0.72)";
    ctx.fill();
    ctx.shadowColor = "transparent";
    ctx.strokeStyle = "rgba(218,213,198,0.31)";
    ctx.lineWidth = 2;
    ctx.stroke();

    roundedRectPath(ctx, target.x + lip, target.y + lip, target.width - lip * 2,
      target.height - lip * 2, 17);
    const inner = ctx.createLinearGradient(target.x, target.y, target.x, target.y + target.height);
    inner.addColorStop(0, "rgba(38,34,30,0.78)");
    inner.addColorStop(1, "rgba(15,13,11,0.94)");
    ctx.fillStyle = inner;
    ctx.fill();
    ctx.strokeStyle = "rgba(239,229,210,0.14)";
    ctx.lineWidth = 1;
    ctx.stroke();

    ctx.globalAlpha = 0.3;
    ctx.strokeStyle = "#b8b1a3";
    ctx.lineWidth = 1;
    const third = (target.width - lip * 2) / 3;
    for (let index = 1; index < 3; index += 1) {
      const x = target.x + lip + third * index;
      ctx.beginPath();
      ctx.moveTo(x, target.y + lip + 8);
      ctx.lineTo(x, target.y + target.height - lip - 8);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawSource(ctx, geo) {
    const x = geo.source.x;
    const y = geo.source.y;
    ctx.save();
    ctx.globalAlpha = 0.68;
    ctx.beginPath();
    ctx.ellipse(x, y + 8, geo.radius * 1.8, geo.radius * 0.65, -0.12, 0, TAU);
    ctx.fillStyle = "rgba(0,0,0,0.42)";
    ctx.fill();
    for (let index = 0; index < 3; index += 1) {
      drawCoinFace(ctx, x + index * 1.5, y - index * 3, 0, geo.radius, -0.1 + index * 0.06, 1);
    }
    ctx.restore();
  }

  function drawCoinFace(ctx, x, groundY, z, radius, angle, opacity) {
    const screenY = groundY - z * 0.56;
    const lift = clamp(z / 100, 0, 1);
    ctx.save();
    ctx.globalAlpha *= opacity;

    ctx.beginPath();
    ctx.ellipse(x + z * 0.04, groundY + radius * 0.42, radius * (1.05 + lift * 0.22),
      radius * 0.34, 0, 0, TAU);
    ctx.fillStyle = `rgba(0,0,0,${0.38 - lift * 0.2})`;
    ctx.fill();

    ctx.translate(x, screenY);
    ctx.rotate(angle);
    ctx.beginPath();
    ctx.ellipse(0, radius * 0.22 + 2.4, radius, radius * 0.67, 0, 0, TAU);
    ctx.fillStyle = "#6b3f24";
    ctx.fill();
    ctx.strokeStyle = "rgba(32,18,10,0.68)";
    ctx.lineWidth = 1;
    ctx.stroke();

    const face = ctx.createRadialGradient(-radius * 0.32, -radius * 0.35, 1,
      0, 0, radius * 1.12);
    face.addColorStop(0, "#efd69b");
    face.addColorStop(0.34, "#c89a52");
    face.addColorStop(0.78, "#9c6333");
    face.addColorStop(1, "#60361f");
    ctx.beginPath();
    ctx.ellipse(0, 0, radius, radius * 0.67, 0, 0, TAU);
    ctx.fillStyle = face;
    ctx.fill();
    ctx.strokeStyle = "rgba(250,225,171,0.72)";
    ctx.lineWidth = 1.1;
    ctx.stroke();

    ctx.beginPath();
    ctx.ellipse(0, 0, radius * 0.68, radius * 0.43, 0, 0, TAU);
    ctx.strokeStyle = "rgba(71,39,19,0.62)";
    ctx.lineWidth = 1;
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-radius * 0.34, 0);
    ctx.lineTo(radius * 0.34, 0);
    ctx.moveTo(0, -radius * 0.25);
    ctx.lineTo(0, radius * 0.25);
    ctx.strokeStyle = "rgba(82,45,22,0.52)";
    ctx.lineWidth = 0.85;
    ctx.stroke();
    ctx.restore();
  }

  function draw() {
    const width = state.width;
    const height = state.height;
    context.save();
    context.setTransform(state.dpr, 0, 0, state.dpr, 0, 0);
    context.clearRect(0, 0, width, height);
    drawBackground(context, width, height);
    const geo = geometry();
    drawTarget(context, geo);
    drawSource(context, geo);

    const coins = state.coins.filter((coin) => coin.active)
      .sort((left, right) => (left.y + left.z * 0.08) - (right.y + right.z * 0.08));
    for (const coin of coins) {
      drawCoinFace(context, coin.x, coin.y, coin.z, coin.radius, coin.angle, coin.opacity);
    }
    context.restore();
  }

  function updateLabels() {
    const config = scenario();
    const settled = state.coins.filter((coin) => coin.settled).length;
    const stateNames = {
      ready: "Bereit",
      running: "In Bewegung",
      paused: "Pausiert",
      settled: "Gesetzt",
    };
    labels.seed.textContent = `Seed ${config.seed}`;
    labels.kicker.textContent = config.kicker;
    labels.title.textContent = config.title;
    labels.pill.dataset.state = state.status;
    labels.state.textContent = stateNames[state.status];
    labels.settle.textContent = state.settleTime === null ? `${state.simTime.toFixed(2)} s` : `${state.settleTime.toFixed(2)} s`;
    labels.collisions.textContent = String(state.collisions);
    labels.stable.textContent = `${settled} / ${state.coins.length}`;
    labels.fps.textContent = `${Math.round(state.fps)} fps`;
  }

  function updateControls() {
    playButton.disabled = state.running && !state.paused;
    pauseButton.disabled = !state.running || state.paused;
  }

  function frame(now) {
    const elapsed = Math.min(MAX_FRAME, (now - state.lastFrame) / 1000);
    state.lastFrame = now;
    state.fpsFrames += 1;
    if (now - state.fpsSampleStart >= 500) {
      state.fps = state.fpsFrames * 1000 / (now - state.fpsSampleStart);
      state.fpsFrames = 0;
      state.fpsSampleStart = now;
    }

    if (state.running && !state.paused) {
      state.accumulator += elapsed;
      while (state.accumulator >= FIXED_STEP) {
        simulationStep(FIXED_STEP);
        state.accumulator -= FIXED_STEP;
      }
    }
    draw();
    updateLabels();
    requestAnimationFrame(frame);
  }

  function play() {
    if (state.completed) reset({ autoplay: true });
    else {
      state.running = true;
      state.paused = false;
      state.status = "running";
      updateControls();
    }
  }

  function pause() {
    if (!state.running) return;
    state.paused = true;
    state.status = "paused";
    updateControls();
  }

  function replay() {
    reset({ autoplay: true });
  }

  function selectScenario(key, autoplay = true) {
    if (!SCENARIOS[key]) return;
    state.scenarioKey = key;
    for (const tab of sceneTabs) {
      const selected = tab.dataset.scene === key;
      tab.classList.toggle("is-active", selected);
      tab.setAttribute("aria-selected", String(selected));
    }
    reset({ autoplay });
  }

  function setMotion(value, autoplay = true) {
    if (value !== "normal" && value !== "reduced") return;
    state.motion = value;
    for (const input of motionInputs) input.checked = input.value === value;
    reset({ autoplay });
  }

  function advance(seconds) {
    const stepCount = Math.max(0, Math.ceil(seconds / FIXED_STEP));
    if (!state.completed) {
      state.running = true;
      state.paused = false;
      state.status = "running";
    }
    for (let index = 0; index < stepCount && !state.completed; index += 1) {
      simulationStep(FIXED_STEP);
    }
    draw();
    updateControls();
    updateLabels();
  }

  function advanceToSettle(maximumSeconds = 12) {
    const maximumSteps = Math.max(0, Math.ceil(maximumSeconds / FIXED_STEP));
    if (!state.completed) {
      state.running = true;
      state.paused = false;
      state.status = "running";
    }
    for (let index = 0; index < maximumSteps && !state.completed; index += 1) {
      simulationStep(FIXED_STEP);
    }
    draw();
    updateControls();
    updateLabels();
  }

  function resize() {
    const rectangle = stage.getBoundingClientRect();
    const width = Math.max(1, Math.round(rectangle.width));
    const height = Math.max(1, Math.round(rectangle.height));
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    if (width === state.width && height === state.height && dpr === state.dpr) return;
    state.width = width;
    state.height = height;
    state.dpr = dpr;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
    reset({ autoplay: state.running && !state.paused });
  }

  playButton.addEventListener("click", play);
  pauseButton.addEventListener("click", pause);
  replayButton.addEventListener("click", replay);
  for (const tab of sceneTabs) {
    tab.addEventListener("click", () => selectScenario(tab.dataset.scene));
  }
  for (const input of motionInputs) {
    input.addEventListener("change", () => setMotion(input.value));
  }

  const resizeObserver = new ResizeObserver(resize);
  resizeObserver.observe(stage);

  window.__coinPrototype = Object.freeze({
    snapshot() {
      const settled = state.coins.filter((coin) => coin.settled).length;
      return {
        scenario: state.scenarioKey,
        motion: state.motion,
        status: state.status,
        simTime: Number(state.simTime.toFixed(4)),
        settleTime: state.settleTime === null ? null : Number(state.settleTime.toFixed(4)),
        fps: Number(state.fps.toFixed(1)),
        collisions: state.collisions,
        clipViolations: state.clipViolations,
        settled,
        coinCount: state.coins.length,
        canvas: { width: state.width, height: state.height, dpr: state.dpr },
        overflowX: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        overflowY: document.documentElement.scrollHeight > document.documentElement.clientHeight,
        finite: state.coins.every((coin) => [coin.x, coin.y, coin.z, coin.vx, coin.vy, coin.vz]
          .every(Number.isFinite)),
      };
    },
    play,
    pause,
    replay,
    selectScenario,
    setMotion,
    advance,
    advanceToSettle,
  });

  for (const input of motionInputs) input.checked = input.value === state.motion;
  resize();
  reset();
  requestAnimationFrame(frame);
})();
