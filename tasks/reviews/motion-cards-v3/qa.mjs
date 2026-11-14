import { createServer } from "node:http";
import { mkdir, readFile, rm, stat } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, extname, join, normalize, relative } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = normalize(join(scriptDirectory, "../../.."));
const evidenceRoot = join(scriptDirectory, "evidence");
const playwrightPath = process.env.PLAYWRIGHT_CORE_PATH;
const chromiumPath = process.env.CHROMIUM_EXECUTABLE_PATH;

if (!playwrightPath || !chromiumPath) {
  throw new Error("Set PLAYWRIGHT_CORE_PATH and CHROMIUM_EXECUTABLE_PATH before running QA.");
}

const require = createRequire(import.meta.url);
const { chromium } = require(playwrightPath);
const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".png", "image/png"],
]);

const server = createServer(async (request, response) => {
  try {
    const requestPath = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
    const candidate = normalize(join(repositoryRoot, requestPath));
    const withinRoot = relative(repositoryRoot, candidate);
    if (withinRoot.startsWith("..") || withinRoot.includes("../")) throw new Error("Invalid path");
    const filePath = (await stat(candidate)).isDirectory() ? join(candidate, "index.html") : candidate;
    const body = await readFile(filePath);
    response.writeHead(200, { "content-type": mimeTypes.get(extname(filePath)) || "application/octet-stream" });
    response.end(body);
  } catch {
    response.writeHead(404);
    response.end("Not found");
  }
});

await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const { port } = server.address();
const url = `http://127.0.0.1:${port}/tasks/reviews/motion-cards-v3/`;
const browser = await chromium.launch({ executablePath: chromiumPath, headless: true });

const requestedViewport = process.env.QA_VIEWPORT;
const captureScreens = process.env.QA_SKIP_EVIDENCE !== "1";
const viewports = [
  { width: 390, height: 844 },
  { width: 667, height: 375 },
].filter(({ width, height }) => !requestedViewport || requestedViewport === `${width}x${height}`);

function check(name, actual, expected, pass = Object.is(actual, expected)) {
  return { name, pass, actual, expected };
}

async function centers(page) {
  return page.locator(".card").evaluateAll((elements) => elements.map((element, index) => {
    if (index === 2) return null;
    const bounds = element.getBoundingClientRect();
    return { index, x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2 };
  }).filter(Boolean));
}

async function inspectViewport(viewport) {
  const page = await browser.newPage({ viewport });
  const consoleErrors = [];
  const pageErrors = [];
  const requestErrors = [];
  page.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text()); });
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("requestfailed", (request) => requestErrors.push(`${request.url()} ${request.failure()?.errorText || "failed"}`));
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.goto(url, { waitUntil: "networkidle" });

  const geometry = await page.evaluate(() => {
    const target = document.querySelector("#prototype").getBoundingClientRect();
    return {
      innerWidth,
      innerHeight,
      visualWidth: visualViewport.width,
      visualHeight: visualViewport.height,
      prototypeWidth: target.width,
      prototypeHeight: target.height,
      overflowX: document.documentElement.scrollWidth - innerWidth,
      overflowY: document.documentElement.scrollHeight - innerHeight,
    };
  });

  const structure = await page.evaluate(() => {
    const card = document.querySelector(".card");
    const grip = card.querySelector(".card-grip");
    const shadow = document.querySelector(".ground-shadow");
    const cardsRoot = document.querySelector("#cards");
    const back = document.querySelector(".card-face.back img");
    const deckLayer = document.querySelector(".deck-layer");
    const cardSize = { width: card.offsetWidth, height: card.offsetHeight };
    const tableBounds = document.querySelector("#table").getBoundingClientRect();
    const origin = getComputedStyle(card).transformOrigin.split(" ").map(Number.parseFloat);
    const gripOrigin = getComputedStyle(grip).transformOrigin.split(" ").map(Number.parseFloat);
    return {
      shadowIsSibling: shadow.parentElement === cardsRoot && shadow.nextElementSibling?.classList.contains("card"),
      shadowHasNo3DTilt: !shadow.style.transform.includes("rotateX") && !shadow.style.transform.includes("rotateY"),
      backFit: getComputedStyle(back).objectFit,
      deckFit: getComputedStyle(deckLayer).objectFit,
      sameBackSource: back.currentSrc === deckLayer.currentSrc,
      outerOrigin: [origin[0] / cardSize.width, origin[1] / cardSize.height],
      gripOrigin: [gripOrigin[0] / cardSize.width, gripOrigin[1] / cardSize.height],
      cardSize,
      tableOffset: { x: tableBounds.x, y: tableBounds.y },
      imageFailures: [...document.images].filter((image) => !image.complete || image.naturalWidth === 0).length,
    };
  });

  await page.evaluate(() => {
    window.__v3ShadowFrames = [];
    window.__v3Extractions = [];
    const captured = new Set();
    const extractionObservers = [...document.querySelectorAll(".deck-layer")].map((layer) => {
      const depth = Number(layer.dataset.depth);
      const observer = new MutationObserver(() => {
        if (captured.has(depth) || Number(getComputedStyle(layer).opacity) !== 0) return;
        const card = document.querySelector(`.card[data-index="${depth}"]`);
        const cardBack = card.querySelector(".card-face.back img");
        const deckBounds = layer.getBoundingClientRect();
        const cardBounds = card.getBoundingClientRect();
        const deckCenter = { x: deckBounds.x + deckBounds.width / 2, y: deckBounds.y + deckBounds.height / 2 };
        const cardCenter = { x: cardBounds.x + cardBounds.width / 2, y: cardBounds.y + cardBounds.height / 2 };
        captured.add(depth);
        window.__v3Extractions.push({
          index: depth,
          deckOpacity: Number(getComputedStyle(layer).opacity),
          cardOpacity: Number(getComputedStyle(card).opacity),
          alignmentError: Math.hypot(deckCenter.x - cardCenter.x, deckCenter.y - cardCenter.y),
          sameSource: layer.currentSrc === cardBack.currentSrc,
          sameFit: getComputedStyle(layer).objectFit === getComputedStyle(cardBack).objectFit,
        });
      });
      observer.observe(layer, { attributes: true, attributeFilter: ["style"] });
      return observer;
    });
    window.__v3ExtractionObservers = extractionObservers;

    let recording = true;
    window.__stopV3FrameRecorder = () => { recording = false; };
    const record = () => {
      if (!recording) return;
      const phase = document.querySelector("#prototype").dataset.phase;
      const index = phase === "deal" ? 0 : phase === "play" || phase === "return" ? 2 : -1;
      if (index >= 0) {
        const card = document.querySelector(`.card[data-index="${index}"]`);
        const shadow = document.querySelector(`.ground-shadow[data-index="${index}"]`);
        if (Number(getComputedStyle(shadow).opacity) > .01) {
          const cardMatrix = new DOMMatrix(getComputedStyle(card).transform);
          const shadowMatrix = new DOMMatrix(getComputedStyle(shadow).transform);
          window.__v3ShadowFrames.push({
            phase,
            index,
            cardX: cardMatrix.m41,
            cardY: cardMatrix.m42,
            shadowX: shadowMatrix.m41,
            shadowY: shadowMatrix.m42,
          });
        }
      }
      requestAnimationFrame(record);
    };
    requestAnimationFrame(record);
  });

  await page.locator("#playButton").click();
  await page.waitForTimeout(220);
  await page.locator("#pauseButton").click();
  const pausedBefore = await page.locator('.card[data-index="4"]').evaluate((element) => getComputedStyle(element).transform);
  await page.waitForTimeout(160);
  const pausedAfter = await page.locator('.card[data-index="4"]').evaluate((element) => getComputedStyle(element).transform);
  await page.locator("#playButton").click();
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.phase === "reveal", null, { timeout: 5000 });
  const revealLayering = await page.evaluate(() => ({
    card: Number(getComputedStyle(document.querySelector('.card[data-index="2"]')).zIndex),
    shadow: Number(getComputedStyle(document.querySelector('.ground-shadow[data-index="2"]')).zIndex),
  }));
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.phase === "return", null, { timeout: 5000 });
  await page.waitForTimeout(600);
  const returnLayering = await page.evaluate(() => ({
    card: Number(getComputedStyle(document.querySelector('.card[data-index="2"]')).zIndex),
    shadow: Number(getComputedStyle(document.querySelector('.ground-shadow[data-index="2"]')).zIndex),
  }));
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.completed === "true", null, { timeout: 10000 });

  const normal = await page.evaluate(() => ({
    zStack: [...document.querySelectorAll(".card")].map((element) => Number(getComputedStyle(element).zIndex)),
    durations: window.__motionDiagnostics.durations,
    status: window.__motionDiagnostics.status,
    approved: window.__motionDiagnostics.approved,
    paths: window.__motionDiagnostics.paths,
    shadowFrames: window.__v3ShadowFrames,
    extractions: window.__v3Extractions.sort((a, b) => a.index - b.index),
  }));
  await page.evaluate(() => {
    window.__stopV3FrameRecorder();
    window.__v3ExtractionObservers.forEach((observer) => observer.disconnect());
  });

  await page.locator("#reducedMode").click();
  await page.locator("#replayButton").click();
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.phase === "reveal", null, { timeout: 3000 });
  await page.evaluate(() => {
    const selected = document.querySelector('.card[data-index="2"]');
    let priorTransform = selected.style.transform;
    window.__reducedTeleports = [];
    const observer = new MutationObserver(() => {
      if (selected.style.transform === priorTransform) return;
      priorTransform = selected.style.transform;
      window.__reducedTeleports.push({
        transform: priorTransform,
        opacity: Number(getComputedStyle(selected).opacity),
      });
    });
    observer.observe(selected, { attributes: true, attributeFilter: ["style"] });
    window.__reducedTeleportObserver = observer;
  });
  const reducedBefore = await centers(page);
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.phase === "return", null, { timeout: 3000 });
  const reducedAfter = await centers(page);
  const reducedNeighborJump = Math.max(...reducedBefore.map((before) => {
    const after = reducedAfter.find((candidate) => candidate.index === before.index);
    return Math.hypot(after.x - before.x, after.y - before.y);
  }));
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.completed === "true", null, { timeout: 4000 });
  const reducedTeleports = await page.evaluate(() => {
    window.__reducedTeleportObserver.disconnect();
    return window.__reducedTeleports;
  });

  await page.locator("#normalMode").click();
  await page.locator("#replayButton").click();
  await page.waitForTimeout(240);
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.motion === "reduced", null, { timeout: 1500 });
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.completed === "true", null, { timeout: 5000 });
  const liveRetarget = await page.evaluate(() => ({
    mode: document.querySelector("#prototype").dataset.motion,
    count: window.__motionDiagnostics.retargetCount,
    source: window.__motionDiagnostics.lastModeSource,
  }));

  const durationPass = normal.durations.length === 7 && normal.durations.every(({ duration }) => duration >= 420 && duration <= 580);
  const projectionFor = (kind, index) => {
    const path = normal.paths.find((candidate) => candidate.kind === kind && candidate.index === index);
    const start = {
      x: path.from.x,
      y: path.from.y + 7,
    };
    const end = {
      x: path.to.x,
      y: path.to.y + 7,
    };
    const delta = { x: end.x - start.x, y: end.y - start.y };
    const magnitudeSquared = delta.x ** 2 + delta.y ** 2;
    const samples = normal.shadowFrames.filter((frame) => frame.phase === kind && frame.index === index).map((frame) => {
      const progress = ((frame.shadowX - start.x) * delta.x + (frame.shadowY - start.y) * delta.y) / magnitudeSquared;
      const expected = { x: start.x + delta.x * progress, y: start.y + delta.y * progress };
      return { frame, progress, error: Math.hypot(frame.shadowX - expected.x, frame.shadowY - expected.y) };
    }).filter(({ progress }) => progress > .02 && progress < .98);
    return {
      kind,
      sampledFrames: samples.length,
      maxErrorPx: Math.max(...samples.map(({ error }) => error)),
      maxLiftSeparationPx: Math.max(...samples.map(({ frame }) => frame.shadowY - frame.cardY)),
    };
  };
  const shadowProjections = [projectionFor("deal", 0), projectionFor("play", 2), projectionFor("return", 2)];
  const extractionPass = normal.extractions.length === 5 && normal.extractions.every((item) => (
    item.deckOpacity === 0 && item.cardOpacity === 1 && item.alignmentError < .25 && item.sameSource && item.sameFit
  ));
  const checks = [
    check("viewport width", geometry.innerWidth, viewport.width),
    check("viewport height", geometry.innerHeight, viewport.height),
    check("visual viewport", [geometry.visualWidth, geometry.visualHeight], [viewport.width, viewport.height], geometry.visualWidth === viewport.width && geometry.visualHeight === viewport.height),
    check("prototype bounds", [geometry.prototypeWidth, geometry.prototypeHeight], [viewport.width, viewport.height], geometry.prototypeWidth === viewport.width && geometry.prototypeHeight === viewport.height),
    check("document overflow", [geometry.overflowX, geometry.overflowY], [0, 0], geometry.overflowX === 0 && geometry.overflowY === 0),
    check("all images loaded", structure.imageFailures, 0),
    check("ground shadow is card sibling", structure.shadowIsSibling, true),
    check("ground shadow has no 3D tilt", structure.shadowHasNo3DTilt, true),
    check("deck and flight crop match", [structure.deckFit, structure.backFit, structure.sameBackSource], ["contain", "contain", true], structure.deckFit === "contain" && structure.backFit === "contain" && structure.sameBackSource),
    check("free-flight origin", structure.outerOrigin.map((value) => Number(value.toFixed(2))), [.5, .5], Math.abs(structure.outerOrigin[0] - .5) < .01 && Math.abs(structure.outerOrigin[1] - .5) < .01),
    check("fan grip origin", structure.gripOrigin.map((value) => Number(value.toFixed(2))), [.5, .82], Math.abs(structure.gripOrigin[0] - .5) < .01 && Math.abs(structure.gripOrigin[1] - .82) < .01),
    check("all five opaque deck extractions", normal.extractions, "5 aligned W2 handoffs", extractionPass),
    check(
      "frame-based linear shadow projection for deal/play/return",
      shadowProjections.map(({ kind, sampledFrames, maxErrorPx }) => ({ kind, sampledFrames, maxErrorPx: Number(maxErrorPx.toFixed(3)) })),
      "each path <= 1px over >= 12 moving frames",
      shadowProjections.every(({ sampledFrames, maxErrorPx }) => sampledFrames >= 12 && maxErrorPx <= 1)
    ),
    check(
      "frame-based card lift separates from shadow",
      shadowProjections.map(({ kind, maxLiftSeparationPx }) => ({ kind, maxLiftSeparationPx: Number(maxLiftSeparationPx.toFixed(3)) })),
      "each path >= 20px",
      shadowProjections.every(({ maxLiftSeparationPx }) => maxLiftSeparationPx >= 20)
    ),
    check("active reveal layers above fan", revealLayering, { card: 60, shadow: 50 }, revealLayering.card === 60 && revealLayering.shadow === 50),
    check("return remains above fan through re-entry", returnLayering, { card: 60, shadow: 50 }, returnLayering.card === 60 && returnLayering.shadow === 50),
    check("pause freezes active transform", pausedAfter, pausedBefore),
    check("distance timings bounded", normal.durations.map(({ duration }) => duration), "7 values in 420...580ms", durationPass),
    check("returned slot z-stack", normal.zStack, [20, 21, 22, 23, 24], normal.zStack.join(",") === "20,21,22,23,24"),
    check("review decision is APPROVED", [normal.status, normal.approved], ["APPROVED", true], normal.status === "APPROVED" && normal.approved === true),
    check("reduced neighbor jump", Number(reducedNeighborJump.toFixed(3)), 0, reducedNeighborJump < .01),
    check(
      "reduced selected-card retarget is invisible",
      reducedTeleports.map(({ opacity }) => Number(opacity.toFixed(3))),
      "2 spatial changes at opacity <= 0.02",
      reducedTeleports.length === 2 && reducedTeleports.every(({ opacity }) => opacity <= .02)
    ),
    check("live media retarget", liveRetarget, { mode: "reduced", count: ">=1", source: "system-change" }, liveRetarget.mode === "reduced" && liveRetarget.count >= 1 && liveRetarget.source === "system-change"),
    check("console errors", consoleErrors, [], consoleErrors.length === 0),
    check("page errors", pageErrors, [], pageErrors.length === 0),
    check("request failures", requestErrors, [], requestErrors.length === 0),
  ];

  await page.close();
  return {
    viewport: `${viewport.width}x${viewport.height}`,
    pass: checks.every(({ pass }) => pass),
    checks,
    durations: normal.durations,
    shadowProjection: shadowProjections.map(({ kind, sampledFrames, maxErrorPx, maxLiftSeparationPx }) => ({
      kind,
      sampledFrames,
      maxErrorPx: Number(maxErrorPx.toFixed(3)),
      maxLiftSeparationPx: Number(maxLiftSeparationPx.toFixed(3)),
    })),
    extractions: normal.extractions,
    revealLayering,
    returnLayering,
  };
}

async function captureEvidence(viewport) {
  const label = `${viewport.width}x${viewport.height}`;
  const screenDirectory = join(evidenceRoot, label);
  await mkdir(screenDirectory, { recursive: true });
  const page = await browser.newPage({ viewport });
  await page.emulateMedia({ reducedMotion: "no-preference" });
  await page.goto(url, { waitUntil: "networkidle" });
  const frames = [];
  const capture = async (index) => {
    const filename = `frame-${String(index).padStart(2, "0")}.png`;
    const path = join(screenDirectory, filename);
    const buffer = await page.screenshot({ path });
    frames.push({ filename, data: buffer.toString("base64") });
  };

  await capture(0);
  await page.locator("#playButton").click();
  const startedAt = Date.now();
  for (let index = 1; index <= 14; index += 1) {
    const remaining = index * 330 - (Date.now() - startedAt);
    if (remaining > 0) await page.waitForTimeout(remaining);
    await capture(index);
  }
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.completed === "true", null, { timeout: 4000 });
  await capture(15);
  await page.close();

  const cellWidth = Math.round(viewport.width / 2);
  const sheetWidth = cellWidth * 4;
  const sheetPage = await browser.newPage({ viewport: { width: sheetWidth, height: 200 } });
  const images = frames.map(({ filename, data }) => `<figure><img src="data:image/png;base64,${data}" alt=""><figcaption>${filename}</figcaption></figure>`).join("");
  await sheetPage.setContent(`<!doctype html><style>
    * { box-sizing: border-box; }
    html, body { margin: 0; background: #080709; }
    main { display: grid; grid-template-columns: repeat(4, ${cellWidth}px); }
    figure { position: relative; margin: 0; overflow: hidden; }
    img { display: block; width: 100%; height: auto; }
    figcaption { position: absolute; right: 4px; bottom: 4px; padding: 2px 4px; border-radius: 3px; color: #d7c48d; background: rgb(0 0 0 / 70%); font: 8px ui-monospace, monospace; }
  </style><main>${images}</main>`);
  await sheetPage.waitForFunction(() => [...document.images].every((image) => image.complete && image.naturalWidth > 0));
  const contactSheet = join(evidenceRoot, `contact-sheet-${label}.png`);
  await sheetPage.screenshot({ path: contactSheet, fullPage: true });
  await sheetPage.close();
  return {
    viewport: label,
    screens: `evidence/${label}/frame-00.png...frame-15.png`,
    contactSheet: `evidence/contact-sheet-${label}.png`,
    frameCount: frames.length,
    intervalMs: 330,
  };
}

try {
  if (captureScreens) {
    await rm(evidenceRoot, { recursive: true, force: true });
    await mkdir(evidenceRoot, { recursive: true });
  }
  const results = [];
  const evidence = [];
  for (const viewport of viewports) {
    results.push(await inspectViewport(viewport));
    if (captureScreens) evidence.push(await captureEvidence(viewport));
  }
  const report = {
    status: "APPROVED",
    approved: true,
    deterministic: true,
    pass: results.every(({ pass }) => pass),
    assets: { cardBack: "W2", cardFronts: "V10" },
    viewports: results,
    evidence,
  };
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  if (!report.pass) process.exitCode = 1;
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
