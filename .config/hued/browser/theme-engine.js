((root, factory) => {
  const engine = factory();
  root.HuedThemeEngine = engine;
  if (typeof module === "object" && module.exports) module.exports = engine;
})(typeof globalThis === "object" ? globalThis : this, () => {
  const ROOT_ATTRIBUTE = "data-hued";
  const SKIPPED_TAGS = new Set(["IMG", "VIDEO", "PICTURE", "CANVAS", "IFRAME", "OBJECT", "EMBED"]);
  const TEXT_TAGS = new Set(["A", "BUTTON", "INPUT", "LABEL", "OPTION", "SELECT", "TEXTAREA", "SUMMARY"]);
  const MAX_INITIAL_ELEMENTS = 12000;
  const BATCH_SIZE = 350;
  let started = false;
  let sourceIsDark = true;
  let queue = [];
  let queued = new WeakSet();
  let scheduled = false;

  function parseColor(value) {
    if (typeof value !== "string") return undefined;
    const match = value.match(/^rgba?\(\s*([\d.]+)[, ]+([\d.]+)[, ]+([\d.]+)(?:\s*[,/]\s*([\d.]+%?))?\s*\)$/i);
    if (!match) return undefined;
    const alpha = match[4]?.endsWith("%") ? Number.parseFloat(match[4]) / 100 : Number.parseFloat(match[4] ?? "1");
    return {
      r: Math.max(0, Math.min(255, Number.parseFloat(match[1]))),
      g: Math.max(0, Math.min(255, Number.parseFloat(match[2]))),
      b: Math.max(0, Math.min(255, Number.parseFloat(match[3]))),
      a: Math.max(0, Math.min(1, alpha)),
    };
  }

  function relativeLuminance(color) {
    const linear = (channel) => {
      const value = channel / 255;
      return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    };
    return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
  }

  function saturation(color) {
    const maximum = Math.max(color.r, color.g, color.b);
    const minimum = Math.min(color.r, color.g, color.b);
    return maximum === 0 ? 0 : (maximum - minimum) / maximum;
  }

  function contrast(first, second) {
    const a = relativeLuminance(first);
    const b = relativeLuminance(second);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
  }

  function classifySurface(value, darkSource = sourceIsDark) {
    const color = typeof value === "string" ? parseColor(value) : value;
    if (!color || color.a < 0.08 || saturation(color) > 0.22) return undefined;
    const luminance = relativeLuminance(color);
    if (darkSource) {
      if (luminance <= 0.025) return "base";
      if (luminance <= 0.075) return "surface-0";
      if (luminance <= 0.16) return "surface-1";
      if (luminance <= 0.32) return "overlay";
      return "raised";
    }
    if (luminance >= 0.92) return "base";
    if (luminance >= 0.78) return "surface-0";
    if (luminance >= 0.58) return "surface-1";
    if (luminance >= 0.32) return "overlay";
    return "raised";
  }

  function classifyInk(foregroundValue, backgroundValue) {
    const foreground = typeof foregroundValue === "string" ? parseColor(foregroundValue) : foregroundValue;
    const background = typeof backgroundValue === "string" ? parseColor(backgroundValue) : backgroundValue;
    if (!foreground || !background || foreground.a < 0.2 || saturation(foreground) > 0.25) return undefined;
    const ratio = contrast(foreground, background);
    if (ratio >= 5) return "primary";
    if (ratio >= 2.2) return "muted";
    return "faint";
  }

  function nearestOpaqueBackground(element) {
    let current = element;
    for (let depth = 0; current && depth < 8; depth += 1, current = current.parentElement) {
      const color = parseColor(getComputedStyle(current).backgroundColor);
      if (color && color.a >= 0.8) return color;
    }
    return sourceIsDark ? { r: 0, g: 0, b: 0, a: 1 } : { r: 255, g: 255, b: 255, a: 1 };
  }

  function hasDirectText(element) {
    if (TEXT_TAGS.has(element.tagName)) return true;
    for (const node of element.childNodes) {
      if (node.nodeType === 3 && node.textContent?.trim()) return true;
    }
    return false;
  }

  function hasVisibleNeutralBorder(style) {
    for (const side of ["Top", "Right", "Bottom", "Left"]) {
      if (Number.parseFloat(style[`border${side}Width`]) <= 0) continue;
      const color = parseColor(style[`border${side}Color`]);
      if (color && color.a >= 0.08 && saturation(color) <= 0.25) return true;
    }
    return false;
  }

  function classifyElement(element) {
    if (!(element instanceof Element) || SKIPPED_TAGS.has(element.tagName) || element.closest("[data-hued-preserve]")) return;
    const style = getComputedStyle(element);
    const surface = classifySurface(style.backgroundColor);
    if (surface) element.setAttribute("data-hued-surface", surface);
    else element.removeAttribute("data-hued-surface");

    if (hasDirectText(element)) {
      const ink = classifyInk(style.color, nearestOpaqueBackground(element));
      if (ink) element.setAttribute("data-hued-ink", ink);
      else element.removeAttribute("data-hued-ink");
    }

    if (hasVisibleNeutralBorder(style)) element.setAttribute("data-hued-border", "");
    else element.removeAttribute("data-hued-border");
  }

  function enqueue(element) {
    if (!(element instanceof Element) || queued.has(element)) return;
    queued.add(element);
    queue.push(element);
  }

  function enqueueTree(rootElement, limit = MAX_INITIAL_ELEMENTS) {
    enqueue(rootElement);
    const descendants = rootElement.querySelectorAll?.("*") ?? [];
    for (let index = 0; index < descendants.length && index < limit; index += 1) enqueue(descendants[index]);
  }

  function schedule() {
    if (scheduled || queue.length === 0) return;
    scheduled = true;
    const callback = () => {
      scheduled = false;
      const documentRoot = document.documentElement;
      const activeAppearance = documentRoot.getAttribute(ROOT_ATTRIBUTE);
      if (activeAppearance) documentRoot.removeAttribute(ROOT_ATTRIBUTE);
      const batch = queue.splice(0, BATCH_SIZE);
      for (const element of batch) {
        queued.delete(element);
        if (element.isConnected) classifyElement(element);
      }
      if (activeAppearance) documentRoot.setAttribute(ROOT_ATTRIBUTE, activeAppearance);
      schedule();
    };
    if (typeof requestIdleCallback === "function") requestIdleCallback(callback, { timeout: 120 });
    else setTimeout(callback, 16);
  }

  function detectSourceAppearance() {
    const documentRoot = document.documentElement;
    const activeAppearance = documentRoot.getAttribute(ROOT_ATTRIBUTE);
    if (activeAppearance) documentRoot.removeAttribute(ROOT_ATTRIBUTE);
    const bodyColor = parseColor(getComputedStyle(document.body ?? documentRoot).backgroundColor);
    const rootColor = parseColor(getComputedStyle(documentRoot).backgroundColor);
    const color = bodyColor?.a >= 0.5 ? bodyColor : rootColor?.a >= 0.5 ? rootColor : undefined;
    sourceIsDark = color ? relativeLuminance(color) < 0.42 : matchMedia("(prefers-color-scheme: dark)").matches;
    if (activeAppearance) documentRoot.setAttribute(ROOT_ATTRIBUTE, activeAppearance);
  }

  function start() {
    if (started || typeof document !== "object") return;
    started = true;
    const initialize = () => {
      detectSourceAppearance();
      enqueueTree(document.body ?? document.documentElement);
      schedule();
      const observer = new MutationObserver((mutations) => {
        for (const mutation of mutations) {
          if (mutation.type === "attributes") enqueue(mutation.target);
          for (const node of mutation.addedNodes) {
            if (node instanceof Element) enqueueTree(node, 2500);
          }
        }
        schedule();
      });
      observer.observe(document.documentElement, { subtree: true, childList: true, attributes: true, attributeFilter: ["class", "style"] });
    };
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", initialize, { once: true });
    else initialize();
  }

  return { classifyInk, classifySurface, contrast, parseColor, relativeLuminance, saturation, start };
});
