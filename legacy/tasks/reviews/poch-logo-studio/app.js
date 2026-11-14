const directions = [
  {
    id: "01",
    name: "Das Brett",
    src: "assets/web/core/01-brett.webp",
    idea: "Die unverwechselbare Poch-Topologie wird auf Außentöpfe, Ring und Mitte reduziert.",
    strength: "Am stärksten mit dem Produkt verbunden und leicht aus dem Gedächtnis zu zeichnen.",
    risk: "Darf nicht wie Kamera, Rotor oder Roulette gelesen werden.",
    motion: "Die Einsätze ordnen sich um die Mitte. Ein Klopfen bringt den Kern ins Spiel.",
    role: "Statisches Hauptzeichen",
    verdict: "Shortlist. Weiter vertiefen.",
    verdictTone: "advance"
  },
  {
    id: "02",
    name: "Der Schlag",
    src: "assets/web/core/02-schlag.webp",
    idea: "Eine ruhige Form zeigt die physische Reaktion auf einen einzigen Klopfimpuls.",
    strength: "Verbindet Name, Handlung, Sound und Haptik in einer Idee.",
    risk: "Muss klar genug von Audio-, Radar- und Impact-Symbolen getrennt bleiben.",
    motion: "Ein trockener Impuls komprimiert den Ring und verschiebt die Mitte träge.",
    role: "Motion und Sound",
    verdict: "Shortlist. Weiter vertiefen.",
    verdictTone: "advance"
  },
  {
    id: "03",
    name: "O wird C",
    src: "assets/web/core/03-o-wird-c.webp",
    idea: "Ein geschlossener Ring öffnet sich durch ein exakt herausgelöstes Fragment.",
    strength: "Die intelligenteste Verbindung aus Wortmarke, Risiko und Öffnung.",
    risk: "Zu perfekte Geometrie würde nach generischem Tech-Zeichen aussehen.",
    motion: "Ein Impuls löst das Fragment. Aus dem O entsteht kontrolliert das C.",
    role: "Typografisches Prinzip",
    verdict: "Idee stark. Geometrie neu zeichnen.",
    verdictTone: "revise"
  },
  {
    id: "04",
    name: "Der Rhythmus",
    src: "assets/web/core/04-rhythmus.webp",
    idea: "Drei haptische Impulse verdichten die Runde zu einem eigenen Taktzeichen.",
    strength: "Direkt, musikalisch und hervorragend mit Sound erweiterbar.",
    risk: "Darf weder Barcode noch WLAN noch Menüindikator werden.",
    motion: "Drei unterschiedliche Beats bauen Spannung auf und enden im Poch.",
    role: "Akustisches Signet",
    verdict: "Interessant. Noch zu abstrakt.",
    verdictTone: "study"
  },
  {
    id: "05",
    name: "Die Achse",
    src: "assets/web/core/05-achse.webp",
    idea: "Die Spiegelstruktur von 1441 wird als abstraktes Architekturzeichen gedacht.",
    strength: "Herkunft wird prägnant, ohne Historienkostüm oder Jahreszahl-Dekoration.",
    risk: "Kann zu leicht wie Mode, Architektur oder Gastronomie wirken.",
    motion: "Zwei Hälften spiegeln sich und rasten an einer gemeinsamen Mitte ein.",
    role: "Herkunftszeichen",
    verdict: "Als Sekundärzeichen prüfen.",
    verdictTone: "study"
  },
  {
    id: "06",
    name: "Die Reihe",
    src: "assets/web/core/06-reihe.webp",
    idea: "Eine geordnete Folge wird an der entscheidenden Stelle geöffnet.",
    strength: "Transportiert Spielrhythmus, Taktik und Fortschritt ohne Kartenklischee.",
    risk: "Kann als Equalizer, Bücherreihe oder Mediensteuerung missverstanden werden.",
    motion: "Elemente schließen eine Folge, bis eine Lücke die nächste Entscheidung öffnet.",
    role: "Spielrhythmus",
    verdict: "Starker Herausforderer für die Shortlist.",
    verdictTone: "advance"
  },
  {
    id: "07",
    name: "Drei Akte",
    src: "assets/web/alt/07-drei-akte.webp",
    idea: "Drei kräftige Bögen bilden eine Runde, bleiben aber als Phasen unterscheidbar.",
    strength: "Übersetzt Melden, Pochen und Ausspielen in ein klares System.",
    risk: "Kann wie Ladeanzeige oder Prozessgrafik wirken.",
    motion: "Drei Bewegungen schließen sich nacheinander zu einer fast vollständigen Runde.",
    role: "Phasenstruktur",
    verdict: "Bewegung stark. Standbild noch nicht eigen genug.",
    verdictTone: "study"
  },
  {
    id: "08",
    name: "Versetzte Mitte",
    src: "assets/web/alt/08-versetzte-mitte.webp",
    idea: "Ein schwerer Mittelpunkt wird sichtbar aus seiner sicheren Achse gedrückt.",
    strength: "Modern, gespannt und ungewöhnlich, ohne laut zu sein.",
    risk: "Der Versatz muss entschieden aussehen, nicht wie ein Layoutfehler.",
    motion: "Der Kern reagiert mit Masse und findet erst nach dem Impuls eine neue Balance.",
    role: "Spannungssystem",
    verdict: "Als Kampagnenmotiv weiterdenken.",
    verdictTone: "study"
  },
  {
    id: "09",
    name: "Der Meridian",
    src: "assets/web/alt/09-meridian.webp",
    idea: "Ein schwerer Ring erhält eine kontrollierte Fuge und einen leicht versetzten Kern.",
    strength: "Ruhig, skalierbar und in jeder Größe sofort stabil.",
    risk: "Die Idee liegt nahe an Uhren-, Audio- und Luxusmarken.",
    motion: "Die Fuge reagiert auf Druck, ohne dass ein dekorativer Glanzlauf nötig wird.",
    role: "Reduktionsprobe",
    verdict: "Sauber, aber zu generisch.",
    verdictTone: "revise"
  },
  {
    id: "10",
    name: "Der Bruch",
    src: "assets/web/alt/10-bruch.webp",
    idea: "Zwei massive Flächen öffnen einen schmalen, spannungsvollen Zwischenraum.",
    strength: "Kraftvoll, direkt und weit entfernt von Kartenspielklischees.",
    risk: "Kann aggressiv, industriell oder nach Fintech wirken.",
    motion: "Die Flächen geben widerständig nach und arretieren hörbar in neuer Position.",
    role: "Herausforderung",
    verdict: "Stoppen. Liest sich wie Pause oder Schlüsselloch.",
    verdictTone: "stop"
  },
  {
    id: "11",
    name: "Topographie",
    src: "assets/web/alt/11-topographie.webp",
    idea: "Wenige organische Konturen führen das Auge in eine ruhige Mitte.",
    strength: "Atmosphärisch, menschlich und stark als sekundäre Markenwelt.",
    risk: "Kann klein unlesbar und groß zu dekorativ werden.",
    motion: "Konturen verdichten sich wie Druckwellen und geben die Mitte frei.",
    role: "Sekundärgrafik",
    verdict: "Gut als Musterwelt, nicht als Hauptlogo.",
    verdictTone: "study"
  },
  {
    id: "12",
    name: "Die Geste",
    src: "assets/web/alt/12-geste.webp",
    idea: "Eine menschlich gesetzte Spur übersetzt das Pochen in eine charaktervolle Bewegung.",
    strength: "Nahbar und lebendig als Gegenpol zur harten Geometrie.",
    risk: "Darf weder Handschriftlogo noch Restaurantmarke werden.",
    motion: "Die Spur entsteht aus einer einzigen entschiedenen Tischbewegung.",
    role: "Menschlicher Akzent",
    verdict: "Stoppen. Wird als Fragezeichen gelesen.",
    verdictTone: "stop"
  }
];

const families = {
  brett: {
    label: "Das Brett",
    baseline: {
      name: "Baseline",
      src: "assets/web/core/01-brett.webp",
      description: "Acht äußere Mulden und ein starkes Zentrum machen die Poch-Topologie zur Marke."
    },
    strength: "Unmittelbar produktspezifisch und auch ohne Wortmarke erklärbar.",
    risk: "Die Segmentierung darf nicht wie Kamera, Rotor oder Roulette wirken.",
    motion: "Die Runde ordnet sich um die Mitte. Ein Impuls aktiviert den Kern.",
    variants: [
      { name: "Acht Mulden", src: "assets/web/variants/brett/brett-a-acht-mulden.webp", description: "Mehr Brett, weniger Rotor.", verdict: "Zu nah an Zahnrad oder Filmrolle.", tone: "revise" },
      { name: "Offener Tisch", src: "assets/web/variants/brett/brett-b-offener-tisch.webp", description: "Eine Öffnung bringt Spannung in die Runde.", verdict: "Weiter. Stärkste offene Variante.", tone: "advance" },
      { name: "Drei Phasen", src: "assets/web/variants/brett/brett-c-drei-phasen.webp", description: "Drei Gewichtsgruppen strukturieren acht Positionen.", verdict: "Bei 24 px zu wenig Phasenunterschied.", tone: "revise" },
      { name: "Menschliche Runde", src: "assets/web/variants/brett/brett-d-menschliche-runde.webp", description: "Optisch korrigiert und minimal organisch.", verdict: "Weiter. Ruhigste Systemform.", tone: "advance" }
    ]
  },
  schlag: {
    label: "Der Schlag",
    baseline: {
      name: "Baseline",
      src: "assets/web/core/02-schlag.webp",
      description: "Ein schwerer Ring reagiert körperlich auf den Moment des Pochens."
    },
    strength: "Name, Handlung, Sound und Haptik werden zu einem Markensystem.",
    risk: "Die Reaktion muss physisch wirken, ohne Radar- oder Audiozeichen zu werden.",
    motion: "Ein trockener Kontakt verformt den Ring und verschiebt den Kern mit Masse.",
    variants: [
      { name: "Druckstelle", src: "assets/web/variants/schlag/schlag-a-druckstelle.webp", description: "Ein einziger präziser Kontakt verändert die Kontur.", verdict: "Weiter. Stärkste Schlag-Silhouette.", tone: "advance" },
      { name: "Träger Kern", src: "assets/web/variants/schlag/schlag-b-traeger-kern.webp", description: "Die Mitte reagiert langsamer als der äußere Ring.", verdict: "Prüfen. Klein etwas Schallplatte.", tone: "study" },
      { name: "Nachhall", src: "assets/web/variants/schlag/schlag-c-nachhall.webp", description: "Ein Reaktionsbogen zeigt die Folge des Impulses.", verdict: "Stoppen. Wirkt wie Power oder Status.", tone: "stop" },
      { name: "Kontakt", src: "assets/web/variants/schlag/schlag-d-kontakt.webp", description: "Ein äußeres Fragment berührt die ruhige Form.", verdict: "Stoppen. Lupe oder Karten-Pin.", tone: "stop" }
    ]
  },
  oc: {
    label: "O wird C",
    baseline: {
      name: "Baseline",
      src: "assets/web/core/03-o-wird-c.webp",
      description: "Eine geschlossene Ordnung öffnet sich durch ein herausgelöstes Fragment."
    },
    strength: "Die Transformation kann direkt in Wortmarke und Startanimation leben.",
    risk: "Zu perfekte Geometrie kippt sofort in ein generisches Tech- oder Ladezeichen.",
    motion: "Der Schlag löst genau ein Fragment. Die geschlossene Form wird kontrolliert geöffnet.",
    variants: [
      { name: "Fragment", src: "assets/web/variants/o-wird-c/oc-a-fragment.webp", description: "Ein schweres passendes Stück bleibt sichtbar erhalten.", verdict: "Weiter. Klarste O/C-Transformation.", tone: "advance" },
      { name: "Keil", src: "assets/web/variants/o-wird-c/oc-b-keil.webp", description: "Eine asymmetrische Öffnung wirkt weniger technisch.", verdict: "Sauber, aber noch zu generisch.", tone: "revise" },
      { name: "Doppelzustand", src: "assets/web/variants/o-wird-c/oc-c-doppelzustand.webp", description: "Geschlossen und offen werden in einer Form lesbar.", verdict: "Stoppen. Kettenglied oder Brille.", tone: "stop" },
      { name: "Klopföffnung", src: "assets/web/variants/o-wird-c/oc-d-klopfoeffnung.webp", description: "Die Ursache der Öffnung bleibt an der Kontur sichtbar.", verdict: "Prüfen. Der Stößel wird schnell zum Zeiger.", tone: "study" }
    ]
  },
  reihe: {
    label: "Die Reihe",
    baseline: {
      name: "Baseline aus deinem Screenshot",
      src: "assets/web/core/06-reihe.webp",
      description: "Fünf Körper bilden eine steigende Folge. Die letzte Form kippt aus der Ordnung."
    },
    strength: "Spielrhythmus und eine menschliche Störung werden sofort sichtbar.",
    risk: "Die Familie darf weder Barcode, Equalizer noch Bücherregal werden.",
    motion: "Eine Folge baut sich auf. Das letzte Element öffnet den nächsten Zug.",
    variants: [
      { name: "Lücke", src: "assets/web/variants/reihe/reihe-a-luecke.webp", description: "Die fehlende Stelle entscheidet den Rhythmus.", verdict: "Prüfen. Klar, aber nah an Neue Folge.", tone: "study" },
      { name: "Aufstieg", src: "assets/web/variants/reihe/reihe-b-aufstieg.webp", description: "Die Werte steigen klarer und kompakter an.", verdict: "Stoppen. Eindeutig Mobilfunk-Signal.", tone: "stop" },
      { name: "Kippmoment", src: "assets/web/variants/reihe/reihe-c-kippmoment.webp", description: "Ein Körper bricht kontrolliert aus der Folge.", verdict: "Weiter. Charaktervollste neue Reihe.", tone: "advance" },
      { name: "Neue Folge", src: "assets/web/variants/reihe/reihe-d-neue-folge.webp", description: "Zwei Gruppen erzählen Ende und Neubeginn.", verdict: "Zu ähnlich zu Baseline und Lücke.", tone: "revise" }
    ]
  }
};

const shortlistIds = ["01", "02", "03", "06"];
const directionGrid = document.querySelector("#direction-grid");
const shortlistGrid = document.querySelector("#shortlist-grid");
const iconComparison = document.querySelector("#icon-comparison");
const dialog = document.querySelector("#jury-dialog");
const familySelector = document.querySelector("#family-selector");
const familyPanel = document.querySelector("#family-panel");

function createLockup(direction, className = "") {
  return `
    <div class="mark-stage ${className}">
      <img class="mark-image" src="${direction.src}" alt="${direction.name}: monochrome Logo-Studie" loading="lazy">
      <span class="mark-word">POCH</span>
      <span class="mark-year">1441</span>
    </div>`;
}

function renderDirections() {
  directionGrid.innerHTML = directions.map((direction) => `
    <button class="direction-card" type="button" data-id="${direction.id}" data-view="lockup" aria-label="${direction.name} in der Juryansicht öffnen">
      ${createLockup(direction)}
      <div class="direction-meta">
        <h3>${direction.name}</h3>
        <p>${direction.idea}</p>
        <span class="verdict verdict-${direction.verdictTone}">${direction.verdict}</span>
      </div>
    </button>
  `).join("");
}

function renderFamilySelector(activeKey) {
  familySelector.innerHTML = Object.entries(families).map(([key, family]) => `
    <button class="family-button" type="button" role="tab" data-family="${key}" aria-selected="${key === activeKey}">
      ${family.label}
    </button>
  `).join("");
}

function renderFamily(activeKey) {
  const family = families[activeKey];
  renderFamilySelector(activeKey);
  familyPanel.dataset.family = activeKey;
  familyPanel.innerHTML = `
    <article class="baseline-card">
      <img src="${family.baseline.src}" alt="${family.label}: bisherige Baseline" loading="lazy">
      <div>
        <h3>${family.label}</h3>
        <p><strong>${family.baseline.name}.</strong> ${family.baseline.description}</p>
      </div>
    </article>
    <div class="variant-grid">
      ${family.variants.map((variant, index) => `
        <button class="variant-card" type="button" data-variant="${index}" aria-label="${family.label}, Variante ${variant.name} genauer ansehen">
          <img src="${variant.src}" alt="${family.label}: Variante ${variant.name}" loading="lazy">
          <h3>${variant.name}</h3>
          <p>${variant.description}</p>
          <span class="variant-verdict verdict-${variant.tone}">${variant.verdict}</span>
        </button>
      `).join("")}
    </div>`;
}

function renderShortlist() {
  shortlistGrid.innerHTML = shortlistIds.map((id) => {
    const direction = directions.find((item) => item.id === id);
    return `
      <article class="shortlist-card">
        <img src="${direction.src}" alt="${direction.name}: Symbolstudie der Shortlist" loading="lazy">
        <div>
          <h3>${direction.name}</h3>
          <p><strong>${direction.role}.</strong> ${direction.strength}</p>
        </div>
      </article>`;
  }).join("");
}

function renderComparison() {
  iconComparison.innerHTML = shortlistIds.map((id) => {
    const direction = directions.find((item) => item.id === id);
    const sizes = [60, 40, 24];
    return `
      <div class="icon-row">
        <h3>${direction.name}</h3>
        ${sizes.map((size) => `
          <div class="icon-cell" style="--size: ${size}px">
            <img src="${direction.src}" alt="" aria-hidden="true">
            <span>${size} px</span>
          </div>`).join("")}
      </div>`;
  }).join("");
}

function openDirection(id) {
  const direction = directions.find((item) => item.id === id);
  document.querySelector("#dialog-visual").innerHTML = `<img src="${direction.src}" alt="${direction.name}: große monochrome Logo-Studie">`;
  document.querySelector("#dialog-number").textContent = `Richtung ${direction.id}`;
  document.querySelector("#dialog-title").textContent = direction.name;
  document.querySelector("#dialog-idea").textContent = direction.idea;
  document.querySelector("#dialog-verdict").textContent = direction.verdict;
  document.querySelector("#dialog-strength").textContent = direction.strength;
  document.querySelector("#dialog-risk").textContent = direction.risk;
  document.querySelector("#dialog-motion").textContent = direction.motion;
  dialog.showModal();
}

function openVariant(familyKey, variantIndex) {
  const family = families[familyKey];
  const variant = family.variants[variantIndex];
  document.querySelector("#dialog-visual").innerHTML = `<img src="${variant.src}" alt="${family.label}: Variante ${variant.name}">`;
  document.querySelector("#dialog-number").textContent = `${family.label} vertieft`;
  document.querySelector("#dialog-title").textContent = variant.name;
  document.querySelector("#dialog-idea").textContent = variant.description;
  document.querySelector("#dialog-verdict").textContent = variant.verdict;
  document.querySelector("#dialog-strength").textContent = family.strength;
  document.querySelector("#dialog-risk").textContent = family.risk;
  document.querySelector("#dialog-motion").textContent = family.motion;
  dialog.showModal();
}

renderDirections();
renderShortlist();
renderComparison();
renderFamily("brett");

directionGrid.addEventListener("click", (event) => {
  const card = event.target.closest(".direction-card");
  if (card) openDirection(card.dataset.id);
});

familySelector.addEventListener("click", (event) => {
  const button = event.target.closest(".family-button");
  if (button) renderFamily(button.dataset.family);
});

familyPanel.addEventListener("click", (event) => {
  const card = event.target.closest(".variant-card");
  if (card) openVariant(familyPanel.dataset.family, Number(card.dataset.variant));
});

document.querySelectorAll(".view-button").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".view-button").forEach((item) => item.classList.toggle("is-active", item === button));
    document.querySelectorAll(".direction-card").forEach((card) => { card.dataset.view = button.dataset.view; });
  });
});

document.querySelector(".dialog-close").addEventListener("click", () => dialog.close());
dialog.addEventListener("click", (event) => {
  if (event.target === dialog) dialog.close();
});

const motionDemo = document.querySelector("#motion-demo");
let motionTimer;
motionDemo.addEventListener("click", () => {
  window.clearTimeout(motionTimer);
  motionDemo.classList.remove("is-playing");
  requestAnimationFrame(() => {
    motionDemo.classList.add("is-playing");
    motionTimer = window.setTimeout(() => motionDemo.classList.remove("is-playing"), 520);
  });
});
