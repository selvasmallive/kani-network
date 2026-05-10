import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import {
  Presentation,
  PresentationFile,
  column,
  row,
  grid,
  panel,
  text,
  shape,
  rule,
  fill,
  hug,
  fixed,
  wrap,
  grow,
  fr,
  auto,
} from "@oai/artifact-tool";

const outDir = path.resolve("docs/presentations");
const previewDir = path.join(outDir, "kani_enterprise_sandbox_proof_deck_previews");
const layoutDir = path.join(outDir, "kani_enterprise_sandbox_proof_deck_layouts");
const pptxPath = path.join(outDir, "kani_enterprise_sandbox_proof_deck.pptx");

const W = 1920;
const H = 1080;

const palette = {
  paper: "#F7F8F3",
  ink: "#111827",
  muted: "#5B6472",
  line: "#CAD2C5",
  green: "#0E8F6E",
  greenSoft: "#D9F2E9",
  blue: "#2D5BFF",
  blueSoft: "#E1E8FF",
  amber: "#D98A12",
  amberSoft: "#FFF0CE",
  coral: "#C84D3A",
  coralSoft: "#FFE3DD",
  graphite: "#18201D",
  white: "#FFFFFF",
};

const font = "Aptos";

function title(value, options = {}) {
  return text(value, {
    name: options.name ?? "slide-title",
    width: options.width ?? fill,
    height: hug,
    style: {
      fontSize: options.size ?? 54,
      bold: true,
      color: options.color ?? palette.ink,
      typeface: font,
    },
  });
}

function subtitle(value, options = {}) {
  return text(value, {
    name: options.name ?? "slide-subtitle",
    width: options.width ?? wrap(1320),
    height: hug,
    style: {
      fontSize: options.size ?? 25,
      color: options.color ?? palette.muted,
      typeface: font,
    },
  });
}

function small(value, options = {}) {
  return text(value, {
    name: options.name,
    width: options.width ?? fill,
    height: hug,
    style: {
      fontSize: options.size ?? 18,
      bold: options.bold ?? false,
      color: options.color ?? palette.muted,
      typeface: font,
    },
  });
}

function metric(value, label, color = palette.ink) {
  return column({ width: fill, height: hug, gap: 6 }, [
    text(value, {
      name: `metric-${label.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
      width: fill,
      height: hug,
      style: { fontSize: 54, bold: true, color, typeface: font },
    }),
    text(label, {
      name: `metric-label-${label.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
      width: fill,
      height: hug,
      style: { fontSize: 18, color: palette.muted, typeface: font },
    }),
  ]);
}

function statusPill(label, fillColor, color = palette.ink) {
  return panel(
    {
      name: `pill-${label.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
      width: hug,
      height: hug,
      padding: { x: 18, y: 8 },
      fill: fillColor,
      borderRadius: "rounded-full",
    },
    text(label, {
      width: hug,
      height: hug,
      style: { fontSize: 17, bold: true, color, typeface: font },
    }),
  );
}

function bodyLine(value, color = palette.ink) {
  return row({ width: fill, height: hug, gap: 14, align: "center" }, [
    shape({ width: fixed(9), height: fixed(9), fill: color, borderRadius: "rounded-full" }),
    text(value, {
      width: fill,
      height: hug,
      style: { fontSize: 24, color: palette.ink, typeface: font },
    }),
  ]);
}

function slideScaffold(slide, children, opts = {}) {
  slide.background.fill = opts.background ?? palette.paper;
  slide.compose(
    column(
      {
        name: "slide-root",
        width: fill,
        height: fill,
        padding: { x: 86, y: 58 },
        gap: opts.gap ?? 34,
      },
      children,
    ),
    { frame: { left: 0, top: 0, width: W, height: H }, baseUnit: 8 },
  );
}

function twoCol(leftChildren, rightChildren, ratio = [fr(1), fr(1)]) {
  return grid(
    {
      name: "two-col",
      width: fill,
      height: fill,
      columns: ratio,
      columnGap: 62,
      rows: [fr(1)],
    },
    [
      column({ width: fill, height: fill, gap: 24 }, leftChildren),
      column({ width: fill, height: fill, gap: 24 }, rightChildren),
    ],
  );
}

function evidenceTable(rows) {
  return column({ name: "evidence-table", width: fill, height: hug, gap: 0 }, [
    row({ width: fill, height: hug, gap: 0 }, [
      panel({ width: fixed(360), padding: { x: 16, y: 12 }, fill: palette.graphite }, small("Evidence", { color: palette.white, bold: true, size: 18 })),
      panel({ width: fixed(360), padding: { x: 16, y: 12 }, fill: palette.graphite }, small("Result", { color: palette.white, bold: true, size: 18 })),
      panel({ width: grow(1), padding: { x: 16, y: 12 }, fill: palette.graphite }, small("Proof value", { color: palette.white, bold: true, size: 18 })),
    ]),
    ...rows.map((r, i) =>
      row({ width: fill, height: hug, gap: 0 }, [
        panel({ width: fixed(360), padding: { x: 16, y: 11 }, fill: i % 2 ? palette.white : "#EEF2EA" }, small(r[0], { size: 18, color: palette.ink, bold: true })),
        panel({ width: fixed(360), padding: { x: 16, y: 11 }, fill: i % 2 ? palette.white : "#EEF2EA" }, small(r[1], { size: 18, color: r[3] ?? palette.ink, bold: true })),
        panel({ width: grow(1), padding: { x: 16, y: 11 }, fill: i % 2 ? palette.white : "#EEF2EA" }, small(r[2], { size: 18, color: palette.muted })),
      ]),
    ),
  ]);
}

function controlTable(rows) {
  return column({ name: "control-table", width: fill, height: hug, gap: 0 }, [
    row({ width: fill, height: hug, gap: 0 }, [
      panel({ width: fixed(390), padding: { x: 16, y: 12 }, fill: palette.graphite }, small("Domain", { color: palette.white, bold: true, size: 17 })),
      panel({ width: fixed(270), padding: { x: 16, y: 12 }, fill: palette.graphite }, small("Status", { color: palette.white, bold: true, size: 17 })),
      panel({ width: grow(1), padding: { x: 16, y: 12 }, fill: palette.graphite }, small("Next evidence", { color: palette.white, bold: true, size: 17 })),
    ]),
    ...rows.map((r, i) =>
      row({ width: fill, height: hug, gap: 0 }, [
        panel({ width: fixed(390), padding: { x: 16, y: 10 }, fill: i % 2 ? palette.white : "#EEF2EA" }, small(r[0], { size: 17, color: palette.ink, bold: true })),
        panel({ width: fixed(270), padding: { x: 16, y: 10 }, fill: i % 2 ? palette.white : "#EEF2EA" }, small(r[1], { size: 17, color: r[3], bold: true })),
        panel({ width: grow(1), padding: { x: 16, y: 10 }, fill: i % 2 ? palette.white : "#EEF2EA" }, small(r[2], { size: 17, color: palette.muted })),
      ]),
    ),
  ]);
}

function addCover(presentation) {
  const slide = presentation.slides.add();
  slide.background.fill = palette.graphite;
  slide.compose(
    grid(
      {
        name: "cover-root",
        width: fill,
        height: fill,
        padding: { x: 96, y: 72 },
        columns: [fr(1.08), fr(0.92)],
        rows: [auto, fr(1), auto],
        columnGap: 56,
        rowGap: 32,
      },
      [
        row({ columnSpan: 2, width: fill, height: hug, gap: 14, align: "center" }, [
          shape({ width: fixed(14), height: fixed(14), fill: palette.green, borderRadius: "rounded-full" }),
          small("KANI Private Settlement Network", { color: "#D7E5DC", bold: true, size: 19 }),
        ]),
        column({ width: fill, height: fill, gap: 26, justify: "center" }, [
          text("Sandbox proof for enterprise review", {
            name: "cover-title",
            width: fill,
            height: hug,
            style: { fontSize: 76, bold: true, color: palette.white, typeface: font },
          }),
          text("Implemented settlement lifecycle, live GKE validator evidence, and the controls still required before production.", {
            name: "cover-subtitle",
            width: wrap(880),
            height: hug,
            style: { fontSize: 28, color: "#C8D9CF", typeface: font },
          }),
          row({ width: fill, height: hug, gap: 14 }, [
            statusPill("SANDBOX ONLY", palette.greenSoft, palette.green),
            statusPill("REAL VALUE FALSE", palette.amberSoft, palette.amber),
            statusPill("GKE PILOT RUNNING", palette.blueSoft, palette.blue),
          ]),
        ]),
        column({ width: fill, height: fill, gap: 18, justify: "center" }, [
          text("42", { name: "cover-block-number", width: fill, height: hug, style: { fontSize: 180, bold: true, color: palette.green, typeface: font } }),
          text("latest finalized block in the day-zero cloud smoke test", { name: "cover-block-label", width: wrap(650), height: hug, style: { fontSize: 24, color: "#D7E5DC", typeface: font } }),
          rule({ width: fixed(260), stroke: palette.amber, weight: 5 }),
          text("3 validators running / 0 restarts / 0 pending transactions", { name: "cover-proof-line", width: wrap(690), height: hug, style: { fontSize: 23, color: "#D7E5DC", typeface: font } }),
        ]),
        small("Research and evidence package - May 10, 2026", { columnSpan: 2, color: "#A9B9AF", size: 16 }),
      ],
    ),
    { frame: { left: 0, top: 0, width: W, height: H }, baseUnit: 8 },
  );
}

function addSlides(presentation) {
  let slide = presentation.slides.add();
  slideScaffold(slide, [
    title("What is enterprise-ready in this sandbox?"),
    subtitle("The sandbox MVP is implemented and observable. Enterprise readiness now means evidence depth, repeatable drills, control matrices, and signoffs while production value remains blocked."),
    grid({ width: fill, height: hug, columns: [fr(1), fr(1), fr(1)], columnGap: 34 }, [
      metric("Implemented", "end-to-end sandbox MVP", palette.green),
      metric("Running", "GKE validator pilot", palette.blue),
      metric("Blocked", "real-value production use", palette.coral),
    ]),
    rule({ width: fill, stroke: palette.line, weight: 2 }),
    twoCol(
      [
        bodyLine("Payments can be minted, transferred, screened, finalized, audited, and reported.", palette.green),
        bodyLine("Three permissioned validators are running in GKE with the legacy scheduler paused.", palette.blue),
        bodyLine("The CAD 200 guardrail is configured for observation, not as a hard spending cap.", palette.amber),
      ],
      [
        bodyLine("Production ingress, real-value settlement, custody, redemption, and external onboarding remain disabled.", palette.coral),
        bodyLine("Enterprise hardening now focuses on billing review, failure drills, restore drills, and security review.", palette.amber),
        bodyLine("The package creates reusable research data and a presentation-ready proof deck.", palette.green),
      ],
    ),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Architecture: message, screen, settle, finalize"),
    subtitle("KANI links financial messaging to ledger finality through compliance-gated transaction intake and permissioned validators."),
    row({ width: fill, height: fixed(430), gap: 18, align: "center" }, [
      panel({ width: grow(1), height: fixed(330), padding: 24, fill: palette.white, borderRadius: 12 }, column({ width: fill, height: hug, gap: 14 }, [small("1", { color: palette.green, bold: true, size: 26 }), title("Institution API", { size: 31 }), small("Native payment and ISO messages enter the sandbox boundary.", { size: 20 })])),
      text("->", { width: fixed(42), height: hug, style: { fontSize: 38, bold: true, color: palette.line, typeface: font } }),
      panel({ width: grow(1), height: fixed(330), padding: 24, fill: palette.white, borderRadius: 12 }, column({ width: fill, height: hug, gap: 14 }, [small("2", { color: palette.amber, bold: true, size: 26 }), title("Compliance", { size: 31 }), small("Rules allow, hold, or block before settlement.", { size: 20 })])),
      text("->", { width: fixed(42), height: hug, style: { fontSize: 38, bold: true, color: palette.line, typeface: font } }),
      panel({ width: grow(1), height: fixed(330), padding: 24, fill: palette.white, borderRadius: 12 }, column({ width: fill, height: hug, gap: 14 }, [small("3", { color: palette.blue, bold: true, size: 26 }), title("Ledger", { size: 31 }), small("Accounts, balances, journals, audit events, and blocks persist in PostgreSQL.", { size: 20 })])),
      text("->", { width: fixed(42), height: hug, style: { fontSize: 38, bold: true, color: palette.line, typeface: font } }),
      panel({ width: grow(1), height: fixed(330), padding: 24, fill: palette.white, borderRadius: 12 }, column({ width: fill, height: hug, gap: 14 }, [small("4", { color: palette.green, bold: true, size: 26 }), title("Validators", { size: 31 }), small("Permissioned PoA validators append finalized blocks.", { size: 20 })])),
    ]),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Ledger controls are already visible in the MVP"),
    subtitle("The sandbox demonstrates settlement mechanics without enabling production value movement."),
    twoCol(
      [
        metric("KCAD_TEST", "test asset used in cloud smoke", palette.green),
        metric("875,000", "CORP_A post-test balance", palette.blue),
        metric("125,000", "CORP_B post-test balance", palette.amber),
      ],
      [
        bodyLine("Mint and transfer paths run through ledger validation.", palette.green),
        bodyLine("No-negative-balance and request validation are covered by smoke tests.", palette.blue),
        bodyLine("Journal, audit, and report surfaces give reviewers traceability.", palette.amber),
        bodyLine("Production assets remain disabled until legal and compliance gates pass.", palette.coral),
      ],
      [fr(0.9), fr(1.1)],
    ),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Validator finality: three identities, two votes, one block path"),
    subtitle("The day-zero smoke test finalized through the continuous GKE validator path while the legacy scheduler remained paused."),
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], columnGap: 52 }, [
      column({ width: fill, height: fill, gap: 24 }, [
        metric("3", "validator pods running", palette.green),
        metric("0", "pod restarts at capture", palette.blue),
        metric("0", "pending transactions after smoke", palette.amber),
      ]),
      column({ width: fill, height: fill, gap: 22 }, [
        panel({ padding: 24, fill: palette.greenSoft, borderRadius: 12 }, bodyLine("validator-a: 2/2 Running", palette.green)),
        panel({ padding: 24, fill: palette.blueSoft, borderRadius: 12 }, bodyLine("validator-b: 2/2 Running", palette.blue)),
        panel({ padding: 24, fill: palette.amberSoft, borderRadius: 12 }, bodyLine("validator-c: produced latest block 42", palette.amber)),
        rule({ width: fill, stroke: palette.line, weight: 2 }),
        small("Latest finality participants: validator-c and validator-a.", { size: 22, color: palette.ink, bold: true }),
      ]),
    ]),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("ISO and compliance are wired into the same settlement path"),
    subtitle("The ISO test flow does not bypass the ledger. It maps into the same transaction, screening, finality, audit, and reporting path."),
    row({ width: fill, height: fixed(500), gap: 20, align: "center" }, [
      panel({ width: grow(1), height: fixed(400), padding: 26, fill: palette.white, borderRadius: 12 }, column({ width: fill, height: hug, gap: 16 }, [title("pacs.008", { size: 36, color: palette.blue }), small("Inbound payment message parsed into debtor, creditor, asset, and amount.", { size: 22 })])),
      text("->", { width: fixed(48), height: hug, style: { fontSize: 36, bold: true, color: palette.line, typeface: font } }),
      panel({ width: grow(1), height: fixed(400), padding: 26, fill: palette.white, borderRadius: 12 }, column({ width: fill, height: hug, gap: 16 }, [title("Compliance", { size: 36, color: palette.amber }), small("Sandbox STP allows approved test transfers and blocks self-transfer.", { size: 22 })])),
      text("->", { width: fixed(48), height: hug, style: { fontSize: 36, bold: true, color: palette.line, typeface: font } }),
      panel({ width: grow(1), height: fixed(400), padding: 26, fill: palette.white, borderRadius: 12 }, column({ width: fill, height: hug, gap: 16 }, [title("ACSC", { size: 52, color: palette.green }), small("Status returned after settlement path acceptance and finality evidence.", { size: 22 })])),
    ]),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Cloud runtime proof is concrete, not conceptual"),
    subtitle("The sandbox is deployed with running Google Cloud services and a live validator path."),
    evidenceTable([
      ["Cloud Run API", "ready", "kani-sandbox-api serving 100 percent latest revision", palette.green],
      ["Cloud SQL", "RUNNABLE", "PostgreSQL 16, db-g1-small, backups and PITR enabled", palette.green],
      ["GKE", "RUNNING", "One e2-medium node running three validator pods", palette.green],
      ["Scheduler", "PAUSED", "Legacy validator job paused while GKE is active", palette.amber],
      ["Budget", "CAD 200", "50, 80, and 100 percent threshold alerts configured", palette.blue],
    ]),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Day-zero smoke result: settlement lifecycle passed"),
    subtitle("The live test exercised mint, transfer, ISO, compliance, finality, reports, and pending-queue cleanup."),
    grid({ width: fill, height: fill, columns: [fr(0.85), fr(1.15)], columnGap: 52 }, [
      column({ width: fill, height: fill, gap: 24 }, [
        metric("42", "latest finalized block", palette.green),
        metric("ACSC", "ISO status", palette.blue),
        metric("0", "pending transactions", palette.amber),
      ]),
      evidenceTable([
        ["Mint transaction", "c40bd07e", "Treasury test issuance entered the ledger", palette.green],
        ["Transfer transaction", "02a141d0", "CORP_A to CORP_B transfer finalized", palette.green],
        ["ISO transaction", "bc4667c2", "ISO-originated payment returned ACSC", palette.blue],
        ["Compliance events", "20", "Compliance report populated", palette.amber],
        ["Audit reports", "verified", "Settlement and validator reports available", palette.green],
      ]),
    ]),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Enterprise sandbox control matrix"),
    subtitle("The controls are strong enough for sandbox review. Some domains remain intentionally design-only or blocked."),
    controlTable([
      ["Sandbox boundary", "ready", "Keep production and real-value gates blocked", palette.green],
      ["Ledger and payment lifecycle", "ready", "Add one-month replay evidence", palette.green],
      ["Validator operations", "ready for observation", "Run controlled restart/failure drill", palette.blue],
      ["Cloud SQL recovery", "configured", "Execute restore-to-separate-target drill", palette.blue],
      ["Security review", "partial", "Open formal review and remediation register", palette.amber],
      ["HSM/KMS signing", "design-only", "Do not enable until approved", palette.amber],
      ["Production ingress", "design-only", "Keep mTLS/OIDC/Cloud Armor gated", palette.amber],
      ["Real-value settlement", "blocked", "Requires legal, compliance, and executive approvals", palette.coral],
    ]),
  ], { gap: 28 });

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("What remains before calling it enterprise-ready sandbox"),
    subtitle("The next phase is evidence depth: repeated observations, controlled failure, recovery proof, and signoff discipline."),
    twoCol(
      [
        bodyLine("First billing review after Google Cloud billing data catches up.", palette.amber),
        bodyLine("Weekly GKE observation with pod restarts, finality, logs, and pending count.", palette.green),
        bodyLine("Controlled validator restart or failure drill.", palette.blue),
        bodyLine("Cloud SQL restore-to-separate-target drill.", palette.amber),
      ],
      [
        bodyLine("Sandbox API key rotation evidence.", palette.blue),
        bodyLine("Formal security review register and remediation tracker.", palette.amber),
        bodyLine("Operator and reviewer signoff fields for evidence packs.", palette.green),
        bodyLine("One-month closeout on June 10, 2026.", palette.green),
      ],
    ),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Research data generated for reuse"),
    subtitle("The pack is structured so it can support technical review, investor material, patent support, and future audit evidence."),
    evidenceTable([
      ["Readiness report", "Markdown", "Narrative summary for enterprise sandbox review", palette.green],
      ["Controls matrix", "CSV", "Domain, status, evidence, next action, presentation use", palette.blue],
      ["Metrics dataset", "CSV", "Measured proof points from the day-zero sandbox run", palette.blue],
      ["Evidence index", "CSV", "Artifact map with primary use and confidentiality notes", palette.green],
      ["Structured summary", "YAML", "Machine-readable readiness snapshot", palette.amber],
      ["PowerPoint deck", "PPTX", "Editable presentation for research and stakeholder review", palette.green],
    ]),
  ]);

  slide = presentation.slides.add();
  slideScaffold(slide, [
    title("Recommended conclusion"),
    subtitle("Use this exact positioning to avoid over-claiming while still showing real progress."),
    grid({ width: fill, height: fill, columns: [fr(1.1), fr(0.9)], columnGap: 58 }, [
      column({ width: fill, height: fill, gap: 22, justify: "center" }, [
        text("KANI has an implemented, observable sandbox MVP.", { name: "conclusion-main", width: fill, height: hug, style: { fontSize: 60, bold: true, color: palette.ink, typeface: font } }),
        text("The sandbox proves the settlement lifecycle end to end. Enterprise readiness work is now about repeatable evidence, drills, controls, and approvals.", { name: "conclusion-sub", width: wrap(900), height: hug, style: { fontSize: 28, color: palette.muted, typeface: font } }),
      ]),
      column({ width: fill, height: fill, gap: 22, justify: "center" }, [
        statusPill("CALL IT: ENTERPRISE SANDBOX EVIDENCE READY", palette.greenSoft, palette.green),
        statusPill("DO NOT CALL IT: PRODUCTION READY", palette.coralSoft, palette.coral),
        statusPill("KEEP: SANDBOX ONLY", palette.amberSoft, palette.amber),
        rule({ width: fill, stroke: palette.line, weight: 2 }),
        small("Next checkpoint: billing and runtime review between May 11 and May 13, 2026.", { size: 22, color: palette.ink, bold: true }),
      ]),
    ]),
  ]);
}

function validateLayout(layoutText, slideNumber) {
  const layout = JSON.parse(layoutText);
  const failures = [];
  for (const el of layout.elements ?? []) {
    const bbox = el.bbox;
    if (!bbox || bbox.length !== 4) continue;
    const [x, y, w, h] = bbox;
    if (x < -2 || y < -2 || x + w > W + 2 || y + h > H + 2) {
      failures.push(`slide ${slideNumber}: element ${el.name ?? el.id} outside slide bounds`);
    }
    if (el.textLayout && el.text) {
      const height = el.textLayout.height ?? 0;
      const widths = (el.textLayout.lines ?? []).map((line) => line.width ?? 0);
      const maxWidth = widths.length ? Math.max(...widths) : 0;
      if (height > h + 4) failures.push(`slide ${slideNumber}: text ${el.name ?? el.textPreview} height overflow`);
      if (maxWidth > w + 4) failures.push(`slide ${slideNumber}: text ${el.name ?? el.textPreview} width overflow`);
    }
  }
  return failures;
}

async function writeBlob(blob, filePath) {
  const buffer = Buffer.from(await blob.arrayBuffer());
  await writeFile(filePath, buffer);
}

async function main() {
  await mkdir(outDir, { recursive: true });
  await mkdir(previewDir, { recursive: true });
  await mkdir(layoutDir, { recursive: true });

  const presentation = Presentation.create({ slideSize: { width: W, height: H } });
  addCover(presentation);
  addSlides(presentation);

  const layoutFailures = [];
  for (let i = 0; i < presentation.slides.count; i += 1) {
    const slide = presentation.slides.getItem(i);
    const png = await slide.export({ format: "png" });
    await writeBlob(png, path.join(previewDir, `slide-${String(i + 1).padStart(2, "0")}.png`));
    const layoutBlob = await slide.export({ format: "layout" });
    const layoutText = await layoutBlob.text();
    await writeFile(path.join(layoutDir, `slide-${String(i + 1).padStart(2, "0")}.layout.json`), layoutText, "utf8");
    layoutFailures.push(...validateLayout(layoutText, i + 1));
  }

  if (layoutFailures.length) {
    throw new Error(`Layout validation failed:\n${layoutFailures.join("\n")}`);
  }

  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(pptxPath);

  const savedBytes = await (await import("node:fs/promises")).readFile(pptxPath);
  const imported = await PresentationFile.importPptx(savedBytes);
  const parityDir = path.join(outDir, "kani_enterprise_sandbox_proof_deck_pptx_parity");
  await mkdir(parityDir, { recursive: true });
  for (let i = 0; i < imported.slides.count; i += 1) {
    const png = await imported.slides.getItem(i).export({ format: "png" });
    await writeBlob(png, path.join(parityDir, `slide-${String(i + 1).padStart(2, "0")}.png`));
  }

  console.log(
    JSON.stringify(
      {
        status: "ok",
        slides: presentation.slides.count,
        pptxPath,
        previewDir,
        layoutDir,
        pptxParityPreviewDir: parityDir,
        layoutFailures: 0,
      },
      null,
      2,
    ),
  );
}

await main();
