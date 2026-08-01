const test = require("node:test");
const assert = require("node:assert/strict");
const engine = require("./theme-engine.js");

test("classifies dark website surfaces into semantic depth", () => {
  assert.equal(engine.classifySurface("rgb(0, 0, 0)", true), "base");
  assert.equal(engine.classifySurface("rgb(50, 50, 50)", true), "surface-0");
  assert.equal(engine.classifySurface("rgb(90, 90, 90)", true), "surface-1");
});

test("classifies light website surfaces into semantic depth", () => {
  assert.equal(engine.classifySurface("rgb(255, 255, 255)", false), "base");
  assert.equal(engine.classifySurface("rgb(243, 242, 239)", false), "surface-0");
  assert.equal(engine.classifySurface("rgb(205, 205, 205)", false), "surface-1");
});

test("preserves saturated media and brand surfaces", () => {
  assert.equal(engine.classifySurface("rgb(10, 102, 194)", false), undefined);
  assert.equal(engine.classifySurface("rgba(255, 255, 255, 0)", false), undefined);
});

test("maps neutral text by contrast while preserving colored accents", () => {
  assert.equal(engine.classifyInk("rgb(255, 255, 255)", "rgb(0, 0, 0)"), "primary");
  assert.equal(engine.classifyInk("rgb(100, 100, 100)", "rgb(0, 0, 0)"), "muted");
  assert.equal(engine.classifyInk("rgb(29, 155, 240)", "rgb(0, 0, 0)"), undefined);
});
