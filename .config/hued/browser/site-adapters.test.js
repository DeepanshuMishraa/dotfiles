const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = __dirname;
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));

function cssForMatch(match) {
  const entry = manifest.content_scripts.find((script) => script.matches.includes(match));
  assert.ok(entry, `missing manifest entry for ${match}`);
  return entry.css.map((file) => fs.readFileSync(path.join(root, file), "utf8")).join("\n");
}

test("LinkedIn adapter owns canvas, cards, text, and actions", () => {
  const css = cssForMatch("https://www.linkedin.com/*");
  for (const token of ["--color-background-canvas", ".feed-shared-update-v2", "--color-text", "--color-action"]) {
    assert.match(css, new RegExp(token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});

test("X adapter owns the feed, navigation, composer, and menus", () => {
  const css = cssForMatch("https://x.com/*");
  for (const token of ['header[role="banner"]', '[data-testid="primaryColumn"]', '[data-testid="cellInnerDiv"]', '[role="menu"]']) {
    assert.ok(css.includes(token), `X adapter missing ${token}`);
  }
});

test("YouTube adapter owns core design tokens and surfaces", () => {
  const css = cssForMatch("https://www.youtube.com/*");
  for (const token of ["--yt-spec-base-background", "ytd-masthead", "ytd-guide-renderer", "yt-chip-cloud-chip-renderer"]) {
    assert.ok(css.includes(token), `YouTube adapter missing ${token}`);
  }
});

test("GitHub adapter covers current and legacy Primer tokens", () => {
  const css = cssForMatch("https://github.com/*");
  for (const token of ["--bgColor-default", "--button-primary-bgColor-rest", "--color-canvas-default", "--color-btn-primary-bg"]) {
    assert.ok(css.includes(token), `GitHub adapter missing ${token}`);
  }
});
