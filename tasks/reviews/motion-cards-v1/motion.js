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
  const EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)";
  const EASE_IN_OUT = "cubic-bezier(0.77, 0, 0.175, 1)";
  const MOVE_EASE = "cubic-bezier(0.32, 0.72, 0, 1)";

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

  const state = {
    running: false,
    paused: false,
    completed: false,
    reduced: window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    generation: 0,
    activeAnimations: new Set(),
    timers: new Set(),
  };

  const cards = CARD_FRONTS.map((front, index) => {
    const element = document.createElement("div");
    element.className = "card";
    element.dataset.index = String(index);
    element.innerHTML = `
      <div class="card-shadow"></div>
      <div class="card-tilt">
        <div class="card-inner">
          <div class="card-face back"><img src="${CARD_BACK}" alt=""></div>
          <div class="card-face front"><img src="${front}" alt=""></div>
          <div class="card-sheen"></div>
        </div>
      </div>`;
    cardsRoot.append(element);
    return {
      element,
      shadow: element.querySelector(".card-shadow"),
      tilt: element.querySelector(".card-tilt"),
      inner: element.querySelector(".card-inner"),
      sheen: element.querySelector(".card-sheen"),
    };
  });

  function pose(x, y, rotation = 0, scale = 1, rotateX = 0, rotateY = 0, z = 0) {
    return { x, y, rotation, scale, rotateX, rotateY, z };
  }

  function transform(value) {
    return `translate3d(${value.x.toFixed(2)}px, ${value.y.toFixed(2)}px, ${value.z.toFixed(2)}px) `
      + `rotateX(${value.rotateX.toFixed(2)}deg) rotateY(${value.rotateY.toFixed(2)}deg) `
      + `rotateZ(${value.rotation.toFixed(2)}deg) scale(${value.scale.toFixed(4)})`;
  }

  function mixPose(from, to, progress, lift = 0) {
    const mix = (a, b) => a + (b - a) * progress;
    return pose(
      mix(from.x, to.x),
      mix(from.y, to.y) - lift,
      mix(from.rotation, to.rotation),
      mix(from.scale, to.scale),
      mix(from.rotateX, to.rotateX),
      mix(from.rotateY, to.rotateY),
      mix(from.z, to.z)
    );
  }

  function layout() {
    const bounds = table.getBoundingClientRect();
    const cardWidth = cards[0].element.getBoundingClientRect().width || 64;
    const cardHeight = cardWidth * 74 / 52;
    const landscape = bounds.width / Math.max(bounds.height, 1) > 1.45;
    const deckPose = landscape
      ? pose(bounds.width - cardWidth - 26, 30, 2.2)
      : pose(bounds.width - cardWidth - 27, Math.max(34, bounds.height * 0.08), 2.2);
    const fanCenterX = landscape ? bounds.width * 0.44 : bounds.width * 0.5;
    const fanY = bounds.height - cardHeight - (landscape ? 19 : 26);
    const spacing = landscape ? cardWidth * 0.57 : cardWidth * 0.61;
    const fanOffsets = [-2, -1, 0, 1, 2];
    const fan = fanOffsets.map((slot) => pose(
      fanCenterX - cardWidth / 2 + slot * spacing,
      fanY + Math.abs(slot) * (landscape ? 5 : 7),
      slot * (landscape ? 6.6 : 7.4),
      1,
      Math.abs(slot) * -0.55,
      slot * -0.65,
      Math.abs(slot) * -1
    ));
    const played = pose(
      (landscape ? bounds.width * 0.52 : bounds.width * 0.5) - cardWidth / 2,
      (landscape ? bounds.height * 0.35 : bounds.height * 0.34) - cardHeight / 2,
      2.4,
      landscape ? 1.06 : 1.08,
      -1.6,
      1.2,
      20
    );
    const closedFanSlots = [-1.45, -0.5, 0.5, 1.45];
    const closedFan = closedFanSlots.map((slot) => pose(
      fanCenterX - cardWidth / 2 + slot * spacing,
      fanY + Math.abs(slot) * (landscape ? 4 : 6),
      slot * (landscape ? 6.8 : 7.6),
      1,
      -Math.abs(slot) * 0.5,
      slot * -0.55,
      -Math.abs(slot)
    ));
    return { bounds, cardWidth, cardHeight, landscape, deck: deckPose, fan, played, closedFan };
  }

  function placeDeck(layoutValue) {
    deck.style.left = `${layoutValue.deck.x}px`;
    deck.style.top = `${layoutValue.deck.y}px`;
  }

  function setPhase(phase, label) {
    phaseLabel.textContent = label;
    const activeIndex = PHASES.indexOf(phase);
    phaseItems.forEach((item, index) => {
      item.classList.toggle("is-active", index === activeIndex);
      item.classList.toggle("is-complete", activeIndex > -1 && index < activeIndex);
    });
  }

  function updateControls() {
    prototype.dataset.running = String(state.running);
    prototype.dataset.paused = String(state.paused);
    playButton.disabled = state.running && !state.paused;
    playButton.textContent = state.paused ? "Weiter" : "Play";
    pauseButton.disabled = !state.running || state.paused;
  }

  function updateModeButtons() {
    prototype.dataset.motion = state.reduced ? "reduced" : "normal";
    normalMode.classList.toggle("is-active", !state.reduced);
    normalMode.setAttribute("aria-pressed", String(!state.reduced));
    reducedMode.classList.toggle("is-active", state.reduced);
    reducedMode.setAttribute("aria-pressed", String(state.reduced));
    motionHint.textContent = state.reduced
      ? "Ortswechsel und 3D-Flip werden durch kurze Zustandswechsel ersetzt."
      : "Raum, Kontakt und Kartenflex bleiben sichtbar.";
  }

  function animateElement(element, keyframes, options, generation) {
    if (generation !== state.generation) return Promise.resolve();
    const animation = element.animate(keyframes, { fill: "forwards", ...options });
    state.activeAnimations.add(animation);
    if (state.paused) animation.pause();
    return animation.finished
      .then(() => {
        if (generation !== state.generation) return;
        animation.commitStyles();
        animation.cancel();
      })
      .catch(() => undefined)
      .finally(() => state.activeAnimations.delete(animation));
  }

  function scheduleTimer(timer) {
    timer.startedAt = performance.now();
    timer.id = window.setTimeout(() => {
      state.timers.delete(timer);
      timer.resolve();
    }, timer.remaining);
  }

  function wait(duration, generation) {
    if (duration <= 0 || generation !== state.generation) return Promise.resolve();
    return new Promise((resolve) => {
      const timer = { remaining: duration, startedAt: 0, id: 0, resolve };
      state.timers.add(timer);
      if (!state.paused) scheduleTimer(timer);
    });
  }

  function pauseTimers() {
    const now = performance.now();
    state.timers.forEach((timer) => {
      if (!timer.id) return;
      window.clearTimeout(timer.id);
      timer.remaining = Math.max(0, timer.remaining - (now - timer.startedAt));
      timer.id = 0;
    });
  }

  function resumeTimers() {
    state.timers.forEach((timer) => {
      if (!timer.id) scheduleTimer(timer);
    });
  }

  function cancelWork() {
    state.activeAnimations.forEach((animation) => animation.cancel());
    state.activeAnimations.clear();
    state.timers.forEach((timer) => {
      if (timer.id) window.clearTimeout(timer.id);
      timer.resolve();
    });
    state.timers.clear();
  }

  function resetScene() {
    state.generation += 1;
    cancelWork();
    state.running = false;
    state.paused = false;
    state.completed = false;
    const currentLayout = layout();
    placeDeck(currentLayout);
    deck.style.opacity = "1";
    cards.forEach((card, index) => {
      card.element.style.opacity = "0";
      card.element.style.transform = transform(pose(
        currentLayout.deck.x - index * 0.7,
        currentLayout.deck.y + index * 0.45,
        2.2 - index * 0.2
      ));
      card.element.style.zIndex = String(10 + index);
      card.shadow.style.opacity = "0.2";
      card.shadow.style.transform = "translate3d(0, 7px, -1px) scale(0.94)";
      card.tilt.style.transform = "perspective(520px) rotateX(0deg) rotateY(0deg)";
      card.inner.style.transform = "rotateY(0deg)";
      card.sheen.style.transform = "translateX(-16%)";
      card.sheen.style.opacity = "0.12";
    });
    setPhase(null, "Bereit");
    phaseItems.forEach((item) => item.classList.remove("is-active", "is-complete"));
    updateControls();
  }

  async function fadeSwitch(card, change, generation) {
    await animateElement(card.element, [{ opacity: 1 }, { opacity: 0.18 }], {
      duration: 90,
      easing: EASE_OUT,
    }, generation);
    if (generation !== state.generation) return;
    change();
    await animateElement(card.element, [{ opacity: 0.18 }, { opacity: 1 }], {
      duration: 120,
      easing: EASE_OUT,
    }, generation);
  }

  async function dealCard(card, index, currentLayout, generation) {
    await wait(index * (state.reduced ? 32 : 92), generation);
    if (generation !== state.generation) return;
    const start = pose(
      currentLayout.deck.x - index * 0.7,
      currentLayout.deck.y + index * 0.45,
      2.2 - index * 0.2
    );
    const end = currentLayout.fan[index];
    card.element.style.opacity = "1";
    if (state.reduced) {
      card.element.style.transform = transform(end);
      await animateElement(card.element, [{ opacity: 0 }, { opacity: 1 }], {
        duration: 130,
        easing: EASE_OUT,
      }, generation);
      return;
    }
    const direction = index - 2;
    const midpoint = mixPose(start, end, 0.55, 34 + Math.abs(direction) * 3);
    midpoint.rotation = end.rotation * 0.28 - direction * 1.4;
    midpoint.rotateX = 5.4;
    midpoint.rotateY = -direction * 2.8;
    midpoint.z = 42;
    card.element.style.zIndex = String(20 + index);
    await Promise.all([
      animateElement(card.element, [
        { opacity: 0.35, transform: transform(start) },
        { opacity: 1, transform: transform(midpoint), offset: 0.54 },
        { opacity: 1, transform: transform(end) },
      ], { duration: 610, easing: MOVE_EASE }, generation),
      animateElement(card.shadow, [
        { opacity: 0.22, transform: "translate3d(0, 8px, -1px) scale(0.92)" },
        { opacity: 0.10, transform: "translate3d(10px, 22px, -1px) scale(1.16)", offset: 0.54 },
        { opacity: 0.42, transform: "translate3d(0, 7px, -1px) scale(0.94)" },
      ], { duration: 610, easing: MOVE_EASE }, generation),
      animateElement(card.tilt, [
        { transform: "perspective(520px) rotateX(0deg) rotateY(0deg)" },
        { transform: `perspective(520px) rotateX(5.4deg) rotateY(${-direction * 3.2}deg)`, offset: 0.52 },
        { transform: "perspective(520px) rotateX(0deg) rotateY(0deg)" },
      ], { duration: 610, easing: EASE_IN_OUT }, generation),
      animateElement(card.sheen, [
        { opacity: 0.08, transform: "translateX(-24%)" },
        { opacity: 0.24, transform: "translateX(10%)", offset: 0.56 },
        { opacity: 0.12, transform: "translateX(-8%)" },
      ], { duration: 610, easing: EASE_IN_OUT }, generation),
    ]);
  }

  async function flipCard(card, currentLayout, generation, faceUp) {
    const fanPose = currentLayout.fan[2];
    if (state.reduced) {
      await fadeSwitch(card, () => {
        card.inner.style.transform = `rotateY(${faceUp ? 180 : 0}deg)`;
      }, generation);
      return;
    }
    const lifted = { ...fanPose, y: fanPose.y - 5, scale: 1.035, z: 18 };
    await Promise.all([
      animateElement(card.inner, [
        { transform: `rotateY(${faceUp ? 0 : 180}deg)` },
        { transform: `rotateY(${faceUp ? 180 : 0}deg)` },
      ], { duration: 480, easing: EASE_IN_OUT }, generation),
      animateElement(card.element, [
        { transform: transform(fanPose) },
        { transform: transform(lifted), offset: 0.48 },
        { transform: transform(fanPose) },
      ], { duration: 480, easing: EASE_IN_OUT }, generation),
      animateElement(card.shadow, [
        { opacity: 0.42, transform: "translate3d(0, 7px, -1px) scale(0.94)" },
        { opacity: 0.19, transform: "translate3d(3px, 13px, -1px) scale(1.05)", offset: 0.48 },
        { opacity: 0.42, transform: "translate3d(0, 7px, -1px) scale(0.94)" },
      ], { duration: 480, easing: EASE_IN_OUT }, generation),
      animateElement(card.sheen, [
        { opacity: 0.10, transform: "translateX(-18%)" },
        { opacity: 0.28, transform: "translateX(26%)", offset: 0.5 },
        { opacity: 0.12, transform: "translateX(-6%)" },
      ], { duration: 480, easing: EASE_IN_OUT }, generation),
    ]);
  }

  function remainingCards() {
    return cards.filter((_, index) => index !== 2);
  }

  async function closeFan(currentLayout, generation, closing) {
    const others = remainingCards();
    const targets = closing ? currentLayout.closedFan : [
      currentLayout.fan[0], currentLayout.fan[1], currentLayout.fan[3], currentLayout.fan[4],
    ];
    others.forEach((card, index) => {
      if (state.reduced) card.element.style.transform = transform(targets[index]);
    });
    if (state.reduced) return;
    await Promise.all(others.map((card, index) => animateElement(card.element, [
      { transform: card.element.style.transform },
      { transform: transform(targets[index]) },
    ], { duration: 240, easing: EASE_OUT }, generation)));
  }

  async function movePlayed(card, currentLayout, generation, outward) {
    const start = outward ? currentLayout.fan[2] : currentLayout.played;
    const end = outward ? currentLayout.played : currentLayout.fan[2];
    if (state.reduced) {
      await fadeSwitch(card, () => {
        card.element.style.transform = transform(end);
        card.shadow.style.opacity = outward ? "0.5" : "0.42";
      }, generation);
      return;
    }
    const midpoint = mixPose(start, end, 0.52, outward ? 22 : 18);
    midpoint.rotateX = outward ? 4.2 : 3.4;
    midpoint.rotateY = outward ? -2.4 : 1.8;
    midpoint.z = 44;
    const duration = outward ? 540 : 500;
    card.element.style.zIndex = "60";
    await Promise.all([
      animateElement(card.element, [
        { transform: transform(start) },
        { transform: transform(midpoint), offset: 0.52 },
        { transform: transform(end) },
      ], { duration, easing: MOVE_EASE }, generation),
      animateElement(card.shadow, [
        { opacity: outward ? 0.42 : 0.50, transform: "translate3d(0, 7px, -1px) scale(0.94)" },
        { opacity: 0.12, transform: "translate3d(9px, 20px, -1px) scale(1.18)", offset: 0.5 },
        { opacity: outward ? 0.50 : 0.42, transform: `translate3d(0, ${outward ? 10 : 7}px, -1px) scale(${outward ? 0.9 : 0.94})` },
      ], { duration, easing: MOVE_EASE }, generation),
      animateElement(card.tilt, [
        { transform: "perspective(520px) rotateX(0deg) rotateY(0deg)" },
        { transform: `perspective(520px) rotateX(${midpoint.rotateX}deg) rotateY(${midpoint.rotateY}deg)`, offset: 0.5 },
        { transform: "perspective(520px) rotateX(-1deg) rotateY(0.8deg)" },
      ], { duration, easing: EASE_IN_OUT }, generation),
      animateElement(card.sheen, [
        { opacity: 0.10, transform: "translateX(-10%)" },
        { opacity: 0.25, transform: "translateX(18%)", offset: 0.52 },
        { opacity: 0.12, transform: "translateX(-4%)" },
      ], { duration, easing: EASE_IN_OUT }, generation),
    ]);
  }

  async function runSequence() {
    if (state.running) return;
    state.running = true;
    state.completed = false;
    const generation = state.generation;
    const currentLayout = layout();
    placeDeck(currentLayout);
    updateControls();

    setPhase("deal", "Austeilen");
    await Promise.all(cards.map((card, index) => dealCard(card, index, currentLayout, generation)));
    if (generation !== state.generation) return;
    deck.style.opacity = "0.72";

    setPhase("fan", "Handfächer");
    await wait(state.reduced ? 180 : 320, generation);
    if (generation !== state.generation) return;

    setPhase("reveal", "Aufdecken");
    cards[2].element.style.zIndex = "50";
    await flipCard(cards[2], currentLayout, generation, true);
    await wait(state.reduced ? 160 : 320, generation);
    if (generation !== state.generation) return;

    setPhase("play", "Ausspielen");
    await Promise.all([
      movePlayed(cards[2], currentLayout, generation, true),
      closeFan(currentLayout, generation, true),
    ]);
    await wait(state.reduced ? 360 : 760, generation);
    if (generation !== state.generation) return;

    setPhase("return", "Rücknahme");
    await Promise.all([
      movePlayed(cards[2], currentLayout, generation, false),
      closeFan(currentLayout, generation, false),
    ]);
    await wait(state.reduced ? 120 : 180, generation);
    await flipCard(cards[2], currentLayout, generation, false);
    if (generation !== state.generation) return;

    cards[2].element.style.zIndex = "12";
    state.running = false;
    state.completed = true;
    setPhase(null, "Sequenz beendet");
    phaseItems.forEach((item) => item.classList.add("is-complete"));
    updateControls();
  }

  function play() {
    if (state.paused) {
      state.paused = false;
      state.activeAnimations.forEach((animation) => animation.play());
      resumeTimers();
      phaseLabel.textContent = phaseLabel.dataset.resumeLabel || "Fortgesetzt";
      updateControls();
      return;
    }
    if (state.running) return;
    if (state.completed) resetScene();
    runSequence();
  }

  function pause() {
    if (!state.running || state.paused) return;
    state.paused = true;
    phaseLabel.dataset.resumeLabel = phaseLabel.textContent;
    phaseLabel.textContent = "Pausiert";
    state.activeAnimations.forEach((animation) => animation.pause());
    pauseTimers();
    updateControls();
  }

  function replay() {
    resetScene();
    window.requestAnimationFrame(() => runSequence());
  }

  function setMotionMode(reduced) {
    if (state.reduced === reduced) return;
    state.reduced = reduced;
    updateModeButtons();
    replay();
  }

  playButton.addEventListener("click", play);
  pauseButton.addEventListener("click", pause);
  replayButton.addEventListener("click", replay);
  normalMode.addEventListener("click", () => setMotionMode(false));
  reducedMode.addEventListener("click", () => setMotionMode(true));

  let resizeFrame = 0;
  window.addEventListener("resize", () => {
    window.cancelAnimationFrame(resizeFrame);
    resizeFrame = window.requestAnimationFrame(() => {
      const shouldRestart = state.running || state.completed;
      resetScene();
      if (shouldRestart) runSequence();
    });
  });

  updateModeButtons();
  resetScene();
})();
