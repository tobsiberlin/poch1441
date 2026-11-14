import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, extname, join, normalize, relative } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = normalize(join(scriptDirectory, "../../.."));
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
const url = `http://127.0.0.1:${port}/tasks/reviews/motion-cards-v2/`;
const browser = await chromium.launch({ executablePath: chromiumPath, headless: true });

const viewports = [
  { width: 390, height: 844 },
  { width: 667, height: 375 },
];

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
      imageFailures: [...document.images].filter((image) => !image.complete || image.naturalWidth === 0).length,
    };
  });

  await page.locator("#playButton").click();
  await page.waitForTimeout(220);
  const extraction = await page.evaluate(() => ({
    cardOpacity: Number(getComputedStyle(document.querySelector('.card[data-index="0"]')).opacity),
    topLayerOpacity: Number(getComputedStyle(document.querySelector('.deck-layer[data-depth="0"]')).opacity),
  }));
  await page.locator("#pauseButton").click();
  const pausedBefore = await page.locator('.card[data-index="4"]').evaluate((element) => getComputedStyle(element).transform);
  await page.waitForTimeout(160);
  const pausedAfter = await page.locator('.card[data-index="4"]').evaluate((element) => getComputedStyle(element).transform);
  await page.locator("#playButton").click();
  await page.waitForFunction(() => document.querySelector("#prototype").dataset.completed === "true", null, { timeout: 8000 });

  const normal = await page.evaluate(() => ({
    zStack: [...document.querySelectorAll(".card")].map((element) => Number(getComputedStyle(element).zIndex)),
    durations: window.__motionDiagnostics.durations,
    status: window.__motionDiagnostics.status,
    approved: window.__motionDiagnostics.approved,
  }));

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
    check("opaque deck extraction", extraction, { cardOpacity: 1, topLayerOpacity: 0 }, extraction.cardOpacity === 1 && extraction.topLayerOpacity === 0),
    check("pause freezes active transform", pausedAfter, pausedBefore),
    check("distance timings bounded", normal.durations.map(({ duration }) => duration), "7 values in 420...580ms", durationPass),
    check("returned slot z-stack", normal.zStack, [20, 21, 22, 23, 24], normal.zStack.join(",") === "20,21,22,23,24"),
    check("output remains REVIEW", [normal.status, normal.approved], ["REVIEW", false], normal.status === "REVIEW" && normal.approved === false),
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
  };
}

try {
  const results = [];
  for (const viewport of viewports) results.push(await inspectViewport(viewport));
  const report = {
    status: "REVIEW",
    approved: false,
    deterministic: true,
    pass: results.every(({ pass }) => pass),
    assets: { cardBack: "W2", cardFronts: "V10" },
    viewports: results,
  };
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  if (!report.pass) process.exitCode = 1;
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
