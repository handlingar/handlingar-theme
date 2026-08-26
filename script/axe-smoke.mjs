#!/usr/bin/env node
/**
 * WCAG 2.1 AA smoke with axe-core.
 *
 * Fixtures (CI):  npm run axe-smoke:fixtures
 * Live Alaveteli: npm run axe-smoke
 *                 AXE_BASE_URL=http://localhost:3000 AXE_LOCALE=sv npm run axe-smoke
 *
 * Fails on critical and serious findings. Stripe (#card-element) and iframes
 * (reCAPTCHA) are excluded so the smoke does not touch those contracts.
 */

import { chromium } from "playwright";
import AxeBuilder from "@axe-core/playwright";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const FAIL_IMPACTS = new Set(["critical", "serious"]);
const TAGS = ["wcag2a", "wcag2aa", "wcag21aa"];
const DEFAULT_PATHS = ["/profile/sign_in", "/body", "/help/about"];

const fixturesMode = process.argv.includes("--fixtures");
const baseUrl = (process.env.AXE_BASE_URL || "http://localhost:3000").replace(
  /\/$/,
  ""
);
const locales = (process.env.AXE_LOCALES || process.env.AXE_LOCALE || "en,sv")
  .split(",")
  .map((item) => item.trim())
  .filter(Boolean);
const livePaths = (process.env.AXE_PATHS || DEFAULT_PATHS.join(","))
  .split(",")
  .map((item) => item.trim())
  .filter(Boolean);

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtureDir = path.join(rootDir, "spec", "a11y", "fixtures");

function fixtureTargets() {
  if (!fs.existsSync(fixtureDir)) {
    throw new Error(`Missing fixtures directory: ${fixtureDir}`);
  }
  return fs
    .readdirSync(fixtureDir)
    .filter((name) => name.endsWith(".html"))
    .sort()
    .map((name) => pathToFileURL(path.join(fixtureDir, name)).href);
}

function liveTargets() {
  const urls = [];
  for (const locale of locales) {
    for (const pagePath of livePaths) {
      const url = new URL(pagePath, `${baseUrl}/`);
      url.searchParams.set("locale", locale);
      urls.push(url.toString());
    }
  }
  return urls;
}

function failingViolations(violations) {
  return violations.filter((violation) => {
    const impact = violation.impact;
    if (FAIL_IMPACTS.has(impact)) return true;
    return violation.nodes.some((node) => FAIL_IMPACTS.has(node.impact));
  });
}

function printViolations(url, violations) {
  console.log(`\n${url}`);
  if (violations.length === 0) {
    console.log("  ok");
    return;
  }
  for (const violation of violations) {
    console.log(`  ${violation.impact}  ${violation.id}  ${violation.help}`);
    console.log(`    ${violation.helpUrl}`);
    for (const node of violation.nodes.slice(0, 5)) {
      console.log(`    - ${node.target.join(" ")}`);
    }
  }
}

async function scanPage(page, url) {
  let lastError;
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      const response = await page.goto(url, {
        waitUntil: "load",
        timeout: 120_000,
      });
      const status = response ? response.status() : 0;
      if (status >= 400) {
        throw new Error(`${url} returned HTTP ${status}`);
      }
      const results = await new AxeBuilder({ page })
        .withTags(TAGS)
        .exclude("#card-element")
        .exclude("form.stripe-form")
        .exclude("iframe")
        .exclude("[aria-hidden='true']")
        .analyze();
      return failingViolations(results.violations);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError;
}

async function main() {
  const targets = fixturesMode ? fixtureTargets() : liveTargets();
  if (targets.length === 0) {
    throw new Error("No axe-smoke targets.");
  }

  if (!fixturesMode) {
    console.log(`Scanning ${targets.length} URLs on ${baseUrl}`);
  } else {
    console.log(`Scanning ${targets.length} fixture(s)`);
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  let failed = 0;
  const errors = [];

  try {
    for (const url of targets) {
      try {
        const violations = await scanPage(page, url);
        printViolations(url, violations);
        failed += violations.length;
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.log(`\n${url}`);
        console.log(`  error  ${message}`);
        errors.push(`${url}: ${message}`);
      }
    }
  } finally {
    await browser.close();
  }

  if (errors.length > 0) {
    if (!fixturesMode) {
      console.error(
        "\nLive scan could not reach Alaveteli. Start Docker on :3000, or set AXE_BASE_URL."
      );
    }
    process.exit(1);
  }

  if (failed > 0) {
    console.error(
      `\naxe-smoke failed: ${failed} critical/serious violation(s) (WCAG 2.1 AA).`
    );
    process.exit(1);
  }

  console.log("\naxe-smoke passed (no critical or serious WCAG 2.1 AA findings).");
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
