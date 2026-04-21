/**
 * Current task GUI validation entry.
 *
 * Path contract:
 *   .autodev/current-gui-test.js
 *
 * Hard rules:
 * - Update this file for the current task before running GUI validation.
 * - Do not use this file as-is with TODO markers.
 * - Default to headed Playwright. Only set PLAYWRIGHT_HEADLESS=true when the
 *   user explicitly allows headless, or the environment cannot show a browser.
 */

const fs = require("node:fs");
const path = require("node:path");
const { spawn } = require("node:child_process");

const taskMeta = {
  fingerprint: "TODO-current-task",
  step: "TODO-step",
  changedFiles: ["TODO-file"],
  changedModules: ["TODO-module"],
  coveredCases: ["G1 TODO-happy", "G2 TODO-boundary"],
  directMapping: [
    "TODO explain how G1 maps to the changed files/modules",
    "TODO explain how G2 maps to the changed files/modules",
  ],
};

const runId = Date.now();
const evidenceRoot = path.join(process.cwd(), ".autodev", "temp", "gui", `run-${runId}`);
const baseUrl = process.env.GUI_BASE_URL || "http://127.0.0.1:3000";
const headless = process.env.PLAYWRIGHT_HEADLESS === "true";
const slowMo = Number(process.env.PLAYWRIGHT_SLOWMO || 250);

fs.mkdirSync(evidenceRoot, { recursive: true });

const results = {
  passed: 0,
  failed: 0,
  timeline: [],
};

function assertPreparedMetadata() {
  const flat = [
    taskMeta.fingerprint,
    taskMeta.step,
    ...taskMeta.changedFiles,
    ...taskMeta.changedModules,
    ...taskMeta.coveredCases,
    ...taskMeta.directMapping,
  ];

  const hasTodo = flat.some((item) => String(item).includes("TODO"));
  if (hasTodo) {
    throw new Error(
      "Update .autodev/current-gui-test.js for the current task before running GUI validation."
    );
  }
}

function step(message) {
  results.timeline.push(message);
  console.log(`[STEP] ${message}`);
}

function pass(message) {
  results.passed += 1;
  console.log(`[PASS] ${message}`);
}

function fail(message, detail = "") {
  results.failed += 1;
  console.error(`[FAIL] ${message}${detail ? `: ${detail}` : ""}`);
}

function check(condition, message, detail = "") {
  if (!condition) {
    fail(message, detail);
    throw new Error(`${message}${detail ? `: ${detail}` : ""}`);
  }
  pass(message);
}

function startServer() {
  const child = spawn(process.execPath, ["src/app.js"], {
    cwd: process.cwd(),
    stdio: ["ignore", "pipe", "pipe"],
    env: process.env,
  });

  let logs = "";
  child.stdout.on("data", (chunk) => {
    logs += chunk.toString();
  });
  child.stderr.on("data", (chunk) => {
    logs += chunk.toString();
  });

  return {
    child,
    getLogs() {
      return logs;
    },
  };
}

async function waitForHealth(url = `${baseUrl}/api/health`, timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch (_) {
      // retry
    }
    await new Promise((resolve) => setTimeout(resolve, 300));
  }
  throw new Error(`health check timeout: ${url}`);
}

async function seedData() {
  // Prepare only the minimum seed data required for the current task.
}

async function attachEvidence(page, label) {
  const screenshotPath = path.join(evidenceRoot, `${label}.png`);
  await page.screenshot({ path: screenshotPath, fullPage: true });
}

async function runHappyCase(page) {
  step("happy case start");
  // Replace with the current task's direct GUI case.
  await page.goto(baseUrl, { waitUntil: "networkidle" });
  await attachEvidence(page, "happy");
  check(await page.locator("body").count() === 1, "page loaded");
}

async function runBoundaryCase(page) {
  step("boundary case start");
  // Replace with a boundary or negative case that still maps directly
  // to the current change.
  await page.goto(baseUrl, { waitUntil: "networkidle" });
  await attachEvidence(page, "boundary");
  check(await page.locator("body").count() === 1, "boundary case observed");
}

async function run() {
  const { chromium } = require("playwright");

  assertPreparedMetadata();
  console.log(
    JSON.stringify(
      {
        taskMeta,
        baseUrl,
        headless,
        evidenceRoot,
      },
      null,
      2
    )
  );

  const server = process.env.GUI_BASE_URL ? null : startServer();
  let browser = null;

  try {
    if (!process.env.GUI_BASE_URL) {
      await waitForHealth();
    }

    await seedData();

    browser = await chromium.launch({
      headless,
      slowMo,
    });

    const context = await browser.newContext({
      viewport: { width: 1440, height: 960 },
      locale: "en-US",
      acceptDownloads: true,
    });
    const page = await context.newPage();

    await runHappyCase(page);
    await runBoundaryCase(page);
  } finally {
    if (browser) {
      await browser.close();
    }
    if (server) {
      server.child.kill("SIGTERM");
    }
  }

  const timelinePath = path.join(evidenceRoot, "timeline.json");
  fs.writeFileSync(timelinePath, JSON.stringify(results.timeline, null, 2));

  console.log(`GUI evidence: ${evidenceRoot}`);
  console.log(`Result: ${results.passed} passed, ${results.failed} failed`);

  if (results.failed > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  run().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
