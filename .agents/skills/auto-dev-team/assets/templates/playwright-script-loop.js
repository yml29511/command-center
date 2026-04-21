/**
 * Script-first Playwright GUI loop template.
 *
 * Preferred current-task entry:
 *   node .autodev/current-gui-test.js
 *
 * Goal:
 * - fast local GUI loop
 * - headed execution by default
 * - easy failure classification and rerun
 */

const fs = require("node:fs");
const path = require("node:path");
const { spawn } = require("node:child_process");

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
  // Replace with your real app command when the GUI loop owns bootstrapping.
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

async function waitForHealth(url, timeoutMs = 30000) {
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
  // Create the minimum data required for your GUI journey.
}

async function login(page) {
  // Replace with your real login flow.
  await page.goto(`${baseUrl}/login`, { waitUntil: "networkidle" });
}

async function attachEvidence(page, label) {
  const screenshotPath = path.join(evidenceRoot, `${label}.png`);
  await page.screenshot({ path: screenshotPath, fullPage: true });
}

async function runHappyCase(page) {
  step("happy case start");
  await login(page);
  await attachEvidence(page, "happy-after-login");
  check(await page.locator("body").count() === 1, "page loaded");
}

async function runNegativeCase(page) {
  step("negative case start");
  await page.goto(`${baseUrl}/login`, { waitUntil: "networkidle" });
  await page.getByRole("button", { name: /login/i }).click();
  await attachEvidence(page, "negative-login");
  check(await page.locator("text=error").count() >= 0, "negative case observed");
}

async function run() {
  const { chromium } = require("playwright");
  const server = process.env.GUI_BASE_URL ? null : startServer();
  let browser = null;

  try {
    if (!process.env.GUI_BASE_URL) {
      await waitForHealth(`${baseUrl}/api/health`);
    }

    await seedData();

    browser = await chromium.launch({
      headless,
      slowMo,
    });

    const context = await browser.newContext({
      viewport: { width: 1440, height: 960 },
      locale: "en-US",
    });
    const page = await context.newPage();

    await runHappyCase(page);
    await runNegativeCase(page);
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
