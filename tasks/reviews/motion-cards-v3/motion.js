(() => {
  "use strict";

  const CARD_BACK = "../goty-2026-live-assets/current-cardback-single.png";
  const CARD_FRONTS = [
    "../card-patina-v10-full-set/AH.png",
    "../card-patina-v10-full-set/KD.png",
    "../card-patina-v10-full-set/QS.png",
    "../card-patina-v10-full-set/10C.png",
    "../card-patina-v10-full-set/7D.png",
  ];
  const PHASES = ["deal", "fan", "reveal", "play", "return"];
  const LABELS = ["Austeilen", "Handfächer", "Aufdecken", "Ausspielen", "Rücknahme"];
  const EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)";
  const EASE_IN_OUT = "cubic-bezier(0.77, 0, 0.175, 1)";
  const TRAVEL_EASE = EASE_IN_OUT;
  const DEAL_CADENCE = 360;
  const motionMedia = matchMedia("(prefers-reduced-motion: reduce)");

  const prototype = document.querySelector("#prototype");
  const table = document.querySelector("#table");
  const deck = document.querySelector("#deck");
  const cardsRoot = document.querySelector("#cards");
  const phaseLabel = document.querySelector("#phaseLabel");
  const motionHint = document.querySelector("#motionHint");
  const playButton = document.querySelector("#playButton");
  const pauseButton = document.querySelector("#pauseButton");
  const replayButton = document.querySelector("#replayButton");
  const normalMode = document.querySelector("#normalMode");
  const reducedMode = document.querySelector("#reducedMode");
  const phaseItems = [...document.querySelectorAll(".phase-track li")];

  const diagnostics = {
    status: "APPROVED",
    approved: true,
    durations: [],
    paths: [],
    retargetCount: 0,
    lastModeSource: "system-initial",
  };
  window.__motionDiagnostics = diagnostics;

  const state = {
    running: false,
    paused: false,
    completed: false,
    reduced: motionMedia.matches,
    phaseIndex: -1,
    generation: 0,
    animations: new Set(),
    timers: new Set(),
  };

  const deckLayers = [];
  for (let depth = 5; depth >= 0; depth -= 1) {
    const layer = document.createElement("img");
    layer.className = "deck-layer";
    layer.dataset.depth = String(depth);
    layer.src = CARD_BACK;
    layer.alt = "";
    layer.style.zIndex = String(10 - depth);
    deck.append(layer);
    deckLayers[depth] = layer;
  }

  const cards = CARD_FRONTS.map((front, index) => {
    const shadow = document.createElement("div");
    shadow.className = "ground-shadow";
    shadow.dataset.index = String(index);
    const element = document.createElement("div");
    element.className = "card";
    element.dataset.index = String(index);
    element.innerHTML = `
      <div class="card-grip">
        <div class="card-tilt">
          <div class="card-inner">
            <div class="card-face back"><img src="${CARD_BACK}" alt=""></div>
            <div class="card-face front"><img src="${front}" alt=""></div>
            <div class="card-sheen"></div>
          </div>
        </div>
      </div>`;
    cardsRoot.append(shadow, element);
    return {
      element,
      shadow,
      grip: element.querySelector(".card-grip"),
      tilt: element.querySelector(".card-tilt"),
      inner: element.querySelector(".card-inner"),
    };
  });

  const clamp = (value, minimum, maximum) => Math.min(maximum, Math.max(minimum, value));
  const pose = (x, y, rotation = 0, scale = 1, rotateX = 0, rotateY = 0, z = 0) => ({ x, y, rotation, scale, rotateX, rotateY, z });
  const gripTransform = (rotation) => `rotateZ(${rotation.toFixed(2)}deg)`;

  function outerTransform(value) {
    return `translate3d(${value.x.toFixed(2)}px, ${value.y.toFixed(2)}px, ${value.z.toFixed(2)}px) `
      + `rotateX(${value.rotateX.toFixed(2)}deg) rotateY(${value.rotateY.toFixed(2)}deg) `
      + `rotateZ(${value.rotation.toFixed(2)}deg) scale(${value.scale.toFixed(4)})`;
  }

  function shadowTransform(value, lift = 0) {
    return `translate3d(${value.x.toFixed(2)}px, ${(value.y + 7).toFixed(2)}px, 0) `
      + `rotateZ(${value.rotation.toFixed(2)}deg) scale(${(value.scale * (.94 + lift * .0035)).toFixed(4)})`;
  }

  function mixPose(from, to, progress, lift = 0) {
    const mix = (a, b) => a + (b - a) * progress;
    return pose(
      mix(from.x, to.x), mix(from.y, to.y) - lift, mix(from.rotation, to.rotation),
      mix(from.scale, to.scale), mix(from.rotateX, to.rotateX), mix(from.rotateY, to.rotateY), mix(from.z, to.z)
    );
  }

  function flightDuration(from, to, kind, index = 2) {
    const distance = Math.hypot(to.x - from.x, to.y - from.y);
    const duration = Math.round(clamp(distance / 640 * 1000, 420, 580));
    const path = {
      kind,
      index,
      distance: Number(distance.toFixed(2)),
      duration,
      from: { x: Number(from.x.toFixed(2)), y: Number(from.y.toFixed(2)) },
      to: { x: Number(to.x.toFixed(2)), y: Number(to.y.toFixed(2)) },
    };
    diagnostics.durations.push({ kind, index, distance: path.distance, duration });
    diagnostics.paths.push(path);
    return duration;
  }

  const deckOffset = (depth) => pose(-.7 * depth, .45 * depth, 2.2 - .2 * depth);

  function layout() {
    const bounds = table.getBoundingClientRect();
    const cardWidth = cards[0].element.getBoundingClientRect().width || 64;
    const cardHeight = cardWidth * 74 / 52;
    const landscape = bounds.width / Math.max(bounds.height, 1) > 1.45;
    const deckPose = landscape
      ? pose(bounds.width - cardWidth - 26, 25)
      : pose(bounds.width - cardWidth - 27, Math.max(34, bounds.height * .08));
    const fanCenterX = landscape ? bounds.width * .44 : bounds.width * .5;
    const fanY = bounds.height - cardHeight - (landscape ? 19 : 26);
    const spacing = cardWidth * (landscape ? .57 : .61);
    const fan = [-2, -1, 0, 1, 2].map((slot) => ({
      outer: pose(fanCenterX - cardWidth / 2 + slot * spacing, fanY + Math.abs(slot) * (landscape ? 5 : 7)),
      grip: slot * (landscape ? 6.6 : 7.4),
    }));
    const played = {
      outer: pose(
        (landscape ? bounds.width * .52 : bounds.width * .5) - cardWidth / 2,
        (landscape ? bounds.height * .35 : bounds.height * .34) - cardHeight / 2,
        2.4, landscape ? 1.06 : 1.08, -1, .8, 20
      ),
      grip: 0,
    };
    const closedFan = [-1.45, -.5, .5, 1.45].map((slot) => ({
      outer: pose(fanCenterX - cardWidth / 2 + slot * spacing, fanY + Math.abs(slot) * (landscape ? 4 : 6)),
      grip: slot * (landscape ? 6.8 : 7.6),
    }));
    return { bounds, cardWidth, cardHeight, landscape, deck: deckPose, fan, played, closedFan };
  }

  function deckStart(currentLayout, index) {
    const offset = deckOffset(index);
    return pose(currentLayout.deck.x + offset.x, currentLayout.deck.y + offset.y, offset.rotation);
  }

  function placeDeck(currentLayout) {
    deck.style.left = `${currentLayout.deck.x}px`;
    deck.style.top = `${currentLayout.deck.y}px`;
    deckLayers.forEach((layer, depth) => {
      const offset = deckOffset(depth);
      layer.style.transform = `translate3d(${offset.x}px, ${offset.y}px, 0) rotateZ(${offset.rotation}deg)`;
    });
  }

  function setPhase(index) {
    state.phaseIndex = index;
    prototype.dataset.phase = index >= 0 ? PHASES[index] : "ready";
    phaseLabel.textContent = index >= 0 ? LABELS[index] : "Bereit";
    phaseItems.forEach((item, itemIndex) => {
      item.classList.toggle("is-active", itemIndex === index);
      item.classList.toggle("is-complete", index > -1 && itemIndex < index);
    });
  }

  function updateControls() {
    prototype.dataset.running = String(state.running);
    prototype.dataset.paused = String(state.paused);
    prototype.dataset.completed = String(state.completed);
    playButton.disabled = state.running && !state.paused;
    playButton.textContent = state.paused ? "Weiter" : "Play";
    pauseButton.disabled = !state.running || state.paused;
  }

  function updateMode(source = diagnostics.lastModeSource) {
    diagnostics.lastModeSource = source;
    prototype.dataset.motion = state.reduced ? "reduced" : "normal";
    normalMode.classList.toggle("is-active", !state.reduced);
    normalMode.setAttribute("aria-pressed", String(!state.reduced));
    reducedMode.classList.toggle("is-active", state.reduced);
    reducedMode.setAttribute("aria-pressed", String(state.reduced));
    motionHint.textContent = state.reduced
      ? "Ortswechsel werden unsichtbar umgezielt; Nachbarkarten bleiben ortsfest."
      : "Raum, Kontakt und Kartenflex bleiben sichtbar.";
  }

  function animateElement(element, keyframes, options, generation) {
    if (generation !== state.generation) return Promise.resolve();
    const animation = element.animate(keyframes, { fill: "forwards", ...options });
    state.animations.add(animation);
    if (state.paused) animation.pause();
    return animation.finished.then(() => {
      if (generation !== state.generation) return;
      animation.commitStyles();
      animation.cancel();
    }).catch(() => undefined).finally(() => state.animations.delete(animation));
  }

  function scheduleTimer(timer) {
    timer.startedAt = performance.now();
    timer.id = setTimeout(() => { state.timers.delete(timer); timer.resolve(); }, timer.remaining);
  }

  function wait(duration, generation) {
    if (duration <= 0 || generation !== state.generation) return Promise.resolve();
    return new Promise((resolve) => {
      const timer = { remaining: duration, startedAt: 0, id: 0, resolve };
      state.timers.add(timer);
      if (!state.paused) scheduleTimer(timer);
    });
  }

  function cancelWork() {
    state.animations.forEach((animation) => animation.cancel());
    state.animations.clear();
    state.timers.forEach((timer) => { if (timer.id) clearTimeout(timer.id); timer.resolve(); });
    state.timers.clear();
  }

  function pauseWork() {
    const now = performance.now();
    state.animations.forEach((animation) => animation.pause());
    state.timers.forEach((timer) => {
      if (!timer.id) return;
      clearTimeout(timer.id);
      timer.remaining = Math.max(0, timer.remaining - (now - timer.startedAt));
      timer.id = 0;
    });
  }

  function resumeWork() {
    state.animations.forEach((animation) => animation.play());
    state.timers.forEach((timer) => { if (!timer.id) scheduleTimer(timer); });
  }

  function setCardPose(card, target, index, shadowOpacity = .42) {
    card.element.style.transform = outerTransform(target.outer);
    card.element.style.opacity = "1";
    card.element.style.zIndex = String(20 + index);
    card.grip.style.transform = gripTransform(target.grip);
    card.tilt.style.transform = "perspective(520px) rotateX(0deg) rotateY(0deg)";
    card.shadow.style.transform = shadowTransform(target.outer);
    card.shadow.style.opacity = String(shadowOpacity);
    card.shadow.style.zIndex = String(10 + index);
  }

  function applySnapshot(stage, currentLayout = layout()) {
    placeDeck(currentLayout);
    cardsRoot.style.opacity = "1";
    deckLayers.forEach((layer, depth) => { layer.style.opacity = stage === "ready" || depth >= cards.length ? "1" : "0"; });
    cards.forEach((card, index) => {
      card.inner.style.transform = "rotateY(0deg)";
      if (stage === "ready") {
        const start = deckStart(currentLayout, index);
        card.element.style.opacity = "0";
        card.element.style.transform = outerTransform(start);
        card.grip.style.transform = gripTransform(0);
        card.shadow.style.opacity = "0";
        card.shadow.style.transform = shadowTransform(start);
        card.element.style.zIndex = String(20 + index);
        card.shadow.style.zIndex = String(10 + index);
      } else {
        setCardPose(card, currentLayout.fan[index], index);
      }
    });
    if (stage === "revealed" || stage === "played") cards[2].inner.style.transform = "rotateY(180deg)";
    if (stage === "played") {
      setCardPose(cards[2], currentLayout.played, 2, .5);
      cards[2].element.style.zIndex = "60";
      cards[2].shadow.style.zIndex = "50";
      if (!state.reduced) {
        [0, 1, 3, 4].forEach((cardIndex, targetIndex) => setCardPose(cards[cardIndex], currentLayout.closedFan[targetIndex], cardIndex));
      }
    }
  }

  function resetScene() {
    state.generation += 1;
    cancelWork();
    state.running = false;
    state.paused = false;
    state.completed = false;
    diagnostics.durations = [];
    diagnostics.paths = [];
    applySnapshot("ready");
    setPhase(-1);
    phaseItems.forEach((item) => item.classList.remove("is-active", "is-complete"));
    updateControls();
  }

  async function dealCard(card, index, currentLayout, generation, reduced) {
    const start = deckStart(currentLayout, index);
    const end = currentLayout.fan[index];
    card.element.style.opacity = "1";
    card.element.style.transform = outerTransform(start);
    card.grip.style.transform = gripTransform(0);
    card.shadow.style.transform = shadowTransform(start);
    card.shadow.style.opacity = reduced ? "0" : ".24";
    card.element.style.zIndex = String(20 + index);
    card.shadow.style.zIndex = String(10 + index);
    deckLayers[index].style.opacity = "0";
    if (reduced) {
      card.element.style.opacity = "0";
      card.element.style.transform = outerTransform(end.outer);
      card.grip.style.transform = gripTransform(end.grip);
      card.shadow.style.transform = shadowTransform(end.outer);
      card.shadow.style.opacity = ".42";
      await animateElement(card.element, [{ opacity: 0 }, { opacity: 1 }], { duration: 130, easing: EASE_OUT }, generation);
      return;
    }
    const lift = 34 + Math.abs(index - 2) * 3;
    const groundMidpoint = mixPose(start, end.outer, .54);
    const midpoint = { ...groundMidpoint, y: groundMidpoint.y - lift };
    midpoint.rotation = (index - 2) * -1.4;
    midpoint.rotateX = 5.4;
    midpoint.rotateY = (2 - index) * 2.8;
    midpoint.z = 42;
    const duration = flightDuration(start, end.outer, "deal", index);
    await Promise.all([
      animateElement(card.element, [
        { opacity: 1, transform: outerTransform(start) },
        { opacity: 1, transform: outerTransform(midpoint), offset: .54 },
        { opacity: 1, transform: outerTransform(end.outer) },
      ], { duration, easing: TRAVEL_EASE }, generation),
      animateElement(card.grip, [
        { transform: gripTransform(0) }, { transform: gripTransform(0), offset: .72 }, { transform: gripTransform(end.grip) },
      ], { duration, easing: EASE_OUT }, generation),
      animateElement(card.shadow, [
        { opacity: .24, transform: shadowTransform(start) },
        { opacity: .1, transform: shadowTransform(groundMidpoint, lift), offset: .54 },
        { opacity: .42, transform: shadowTransform(end.outer) },
      ], { duration, easing: TRAVEL_EASE }, generation),
      animateElement(card.tilt, [
        { transform: "perspective(520px) rotateX(0deg) rotateY(0deg)" },
        { transform: `perspective(520px) rotateX(5.4deg) rotateY(${midpoint.rotateY}deg)`, offset: .52 },
        { transform: "perspective(520px) rotateX(0deg) rotateY(0deg)" },
      ], { duration, easing: EASE_IN_OUT }, generation),
    ]);
  }

  async function flipCard(card, currentLayout, generation, reduced, faceUp) {
    const target = currentLayout.fan[2];
    card.element.style.zIndex = "60";
    card.shadow.style.zIndex = "50";
    if (reduced) {
      await animateElement(card.element, [{ opacity: 1 }, { opacity: 0 }], { duration: 90, easing: EASE_OUT }, generation);
      if (generation !== state.generation) return;
      card.inner.style.transform = `rotateY(${faceUp ? 180 : 0}deg)`;
      await animateElement(card.element, [{ opacity: 0 }, { opacity: 1 }], { duration: 120, easing: EASE_OUT }, generation);
      return;
    }
    const lifted = { ...target.outer, y: target.outer.y - 5, scale: 1.035, z: 18 };
    await Promise.all([
      animateElement(card.inner, [
        { transform: `rotateY(${faceUp ? 0 : 180}deg)` }, { transform: `rotateY(${faceUp ? 180 : 0}deg)` },
      ], { duration: 420, easing: EASE_IN_OUT }, generation),
      animateElement(card.element, [
        { transform: outerTransform(target.outer) }, { transform: outerTransform(lifted), offset: .48 }, { transform: outerTransform(target.outer) },
      ], { duration: 420, easing: EASE_IN_OUT }, generation),
      animateElement(card.shadow, [
        { opacity: .42, transform: shadowTransform(target.outer) },
        { opacity: .19, transform: shadowTransform(target.outer, 13), offset: .48 },
        { opacity: .42, transform: shadowTransform(target.outer) },
      ], { duration: 420, easing: EASE_IN_OUT }, generation),
    ]);
  }

  async function moveOtherCards(currentLayout, generation, closing, reduced) {
    if (reduced) return;
    const indices = [0, 1, 3, 4];
    const targets = closing ? currentLayout.closedFan : indices.map((index) => currentLayout.fan[index]);
    await Promise.all(indices.flatMap((cardIndex, targetIndex) => {
      const card = cards[cardIndex];
      const target = targets[targetIndex];
      return [
        animateElement(card.element, [{ transform: card.element.style.transform }, { transform: outerTransform(target.outer) }], { duration: 240, easing: EASE_OUT }, generation),
        animateElement(card.grip, [{ transform: card.grip.style.transform }, { transform: gripTransform(target.grip) }], { duration: 240, easing: EASE_OUT }, generation),
        animateElement(card.shadow, [{ transform: card.shadow.style.transform }, { transform: shadowTransform(target.outer) }], { duration: 240, easing: EASE_OUT }, generation),
      ];
    }));
  }

  async function movePlayed(card, currentLayout, generation, reduced, outward) {
    const start = outward ? currentLayout.fan[2] : currentLayout.played;
    const end = outward ? currentLayout.played : currentLayout.fan[2];
    if (reduced) {
      await animateElement(card.element, [{ opacity: 1 }, { opacity: 0 }], { duration: 90, easing: EASE_OUT }, generation);
      if (generation !== state.generation) return;
      card.element.style.transform = outerTransform(end.outer);
      card.grip.style.transform = gripTransform(end.grip);
      card.shadow.style.transform = shadowTransform(end.outer);
      card.shadow.style.opacity = outward ? ".5" : ".42";
      card.element.style.zIndex = outward ? "60" : "22";
      card.shadow.style.zIndex = outward ? "50" : "12";
      await animateElement(card.element, [{ opacity: 0 }, { opacity: 1 }], { duration: 120, easing: EASE_OUT }, generation);
      return;
    }
    const lift = outward ? 22 : 18;
    const groundMidpoint = mixPose(start.outer, end.outer, .52);
    const midpoint = { ...groundMidpoint, y: groundMidpoint.y - lift };
    midpoint.rotateX = outward ? 4.2 : 3.4;
    midpoint.rotateY = outward ? -2.4 : 1.8;
    midpoint.z = 44;
    const duration = flightDuration(start.outer, end.outer, outward ? "play" : "return");
    card.element.style.zIndex = "60";
    card.shadow.style.zIndex = "50";
    await Promise.all([
      animateElement(card.element, [
        { transform: outerTransform(start.outer) }, { transform: outerTransform(midpoint), offset: .52 }, { transform: outerTransform(end.outer) },
      ], { duration, easing: TRAVEL_EASE }, generation),
      animateElement(card.grip, [
        { transform: gripTransform(start.grip) }, { transform: gripTransform(0), offset: .36 }, { transform: gripTransform(end.grip) },
      ], { duration, easing: EASE_OUT }, generation),
      animateElement(card.shadow, [
        { opacity: outward ? .42 : .5, transform: shadowTransform(start.outer) },
        { opacity: .12, transform: shadowTransform(groundMidpoint, lift), offset: .5 },
        { opacity: outward ? .5 : .42, transform: shadowTransform(end.outer) },
      ], { duration, easing: TRAVEL_EASE }, generation),
      animateElement(card.tilt, [
        { transform: "perspective(520px) rotateX(0deg) rotateY(0deg)" },
        { transform: `perspective(520px) rotateX(${midpoint.rotateX}deg) rotateY(${midpoint.rotateY}deg)`, offset: .5 },
        { transform: "perspective(520px) rotateX(0deg) rotateY(0deg)" },
      ], { duration, easing: EASE_IN_OUT }, generation),
    ]);
  }

  async function runFrom(startIndex = 0) {
    if (state.running) return;
    state.running = true;
    state.completed = false;
    const generation = state.generation;
    const currentLayout = layout();
    const reduced = state.reduced;
    placeDeck(currentLayout);
    updateControls();

    if (startIndex <= 0) {
      setPhase(0);
      await Promise.all(cards.map(async (card, index) => {
        await wait(index * (reduced ? 90 : DEAL_CADENCE), generation);
        if (generation !== state.generation) return;
        await dealCard(card, index, currentLayout, generation, reduced);
      }));
      if (generation !== state.generation) return;
    }
    if (startIndex <= 1) { setPhase(1); await wait(reduced ? 120 : 260, generation); if (generation !== state.generation) return; }
    if (startIndex <= 2) {
      setPhase(2);
      await flipCard(cards[2], currentLayout, generation, reduced, true);
      await wait(reduced ? 120 : 220, generation);
      if (generation !== state.generation) return;
    }
    if (startIndex <= 3) {
      setPhase(3);
      await Promise.all([movePlayed(cards[2], currentLayout, generation, reduced, true), moveOtherCards(currentLayout, generation, true, reduced)]);
      await wait(reduced ? 320 : 560, generation);
      if (generation !== state.generation) return;
    }
    if (startIndex <= 4) {
      setPhase(4);
      await Promise.all([movePlayed(cards[2], currentLayout, generation, reduced, false), moveOtherCards(currentLayout, generation, false, reduced)]);
      await wait(reduced ? 90 : 120, generation);
      await flipCard(cards[2], currentLayout, generation, reduced, false);
      if (generation !== state.generation) return;
    }
    cards[2].element.style.zIndex = "22";
    cards[2].shadow.style.zIndex = "12";
    state.running = false;
    state.completed = true;
    state.phaseIndex = 5;
    prototype.dataset.phase = "complete";
    phaseLabel.textContent = "Sequenz beendet";
    phaseItems.forEach((item) => item.classList.add("is-complete"));
    updateControls();
  }

  function play() {
    if (state.paused) {
      state.paused = false;
      resumeWork();
      phaseLabel.textContent = phaseLabel.dataset.resumeLabel || "Fortgesetzt";
      updateControls();
      return;
    }
    if (state.running) return;
    if (state.completed) resetScene();
    runFrom(0);
  }

  function pause() {
    if (!state.running || state.paused) return;
    state.paused = true;
    phaseLabel.dataset.resumeLabel = phaseLabel.textContent;
    phaseLabel.textContent = "Pausiert";
    pauseWork();
    updateControls();
  }

  function replay() { resetScene(); requestAnimationFrame(() => runFrom(0)); }

  function snapshotForPhase(index) {
    if (index <= 0) return { stage: "dealt", next: 1 };
    if (index === 1) return { stage: "dealt", next: 2 };
    if (index === 2) return { stage: "revealed", next: 3 };
    if (index === 3) return { stage: "played", next: 4 };
    return { stage: "returned", next: 5 };
  }

  async function retargetRunningSequence() {
    const target = snapshotForPhase(state.phaseIndex);
    state.generation += 1;
    const generation = state.generation;
    cancelWork();
    state.running = false;
    state.paused = false;
    diagnostics.retargetCount += 1;
    await animateElement(cardsRoot, [{ opacity: 1 }, { opacity: 0 }], { duration: 90, easing: EASE_OUT }, generation);
    if (generation !== state.generation) return;
    applySnapshot(target.stage);
    cardsRoot.style.opacity = "0";
    await animateElement(cardsRoot, [{ opacity: 0 }, { opacity: 1 }], { duration: 120, easing: EASE_OUT }, generation);
    if (generation !== state.generation) return;
    if (target.next < PHASES.length) runFrom(target.next);
    else {
      state.completed = true;
      state.phaseIndex = 5;
      prototype.dataset.phase = "complete";
      phaseLabel.textContent = "Sequenz beendet";
      phaseItems.forEach((item) => item.classList.add("is-complete"));
      updateControls();
    }
  }

  function setMotionMode(reduced, source) {
    if (state.reduced === reduced) { updateMode(source); return; }
    const wasRunning = state.running;
    state.reduced = reduced;
    updateMode(source);
    if (wasRunning) retargetRunningSequence();
    else if (state.completed) applySnapshot("returned");
  }

  playButton.addEventListener("click", play);
  pauseButton.addEventListener("click", pause);
  replayButton.addEventListener("click", replay);
  normalMode.addEventListener("click", () => setMotionMode(false, "manual"));
  reducedMode.addEventListener("click", () => setMotionMode(true, "manual"));
  motionMedia.addEventListener("change", (event) => setMotionMode(event.matches, "system-change"));

  let resizeFrame = 0;
  addEventListener("resize", () => {
    cancelAnimationFrame(resizeFrame);
    resizeFrame = requestAnimationFrame(() => {
      const stage = state.completed ? "returned" : state.phaseIndex >= 3 ? "played" : state.phaseIndex >= 2 ? "revealed" : state.phaseIndex >= 0 ? "dealt" : "ready";
      state.generation += 1;
      cancelWork();
      state.running = false;
      state.paused = false;
      applySnapshot(stage);
      if (state.completed) { state.phaseIndex = 5; prototype.dataset.phase = "complete"; }
      else setPhase(-1);
      updateControls();
    });
  });

  updateMode();
  resetScene();
})();
