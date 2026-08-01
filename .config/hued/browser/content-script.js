(() => {
if (globalThis.__huedContentScriptLoaded) return;
globalThis.__huedContentScriptLoaded = true;

const ROOT_ATTRIBUTE = "data-hued";

function isPalette(value) {
  return value && typeof value === "object" && typeof value.panel_bg === "string" && typeof value.text === "string";
}

function applyTheme(theme, disabledHosts = []) {
  const root = document.documentElement;
  if (!theme || !isPalette(theme.palette) || disabledHosts.includes(location.hostname)) {
    root.removeAttribute(ROOT_ATTRIBUTE);
    return;
  }

  const palette = theme.palette;
  const values = {
    "--hued-bg": palette.panel_bg,
    "--hued-surface-0": palette.surface0,
    "--hued-surface-1": palette.surface1,
    "--hued-border": palette.separator,
    "--hued-text": palette.text,
    "--hued-muted": palette.subtext0,
    "--hued-accent": palette.accent,
    "--hued-red": palette.red,
    "--hued-green": palette.green,
    "--hued-yellow": palette.yellow,
  };
  for (const [name, value] of Object.entries(values)) root.style.setProperty(name, value);
  root.style.colorScheme = theme.appearance;
  root.setAttribute(ROOT_ATTRIBUTE, theme.appearance);
  globalThis.HuedThemeEngine?.start();
}

chrome.runtime.sendMessage({ type: "hued:get" }, (state) => {
  if (chrome.runtime.lastError) return;
  applyTheme(state?.activeTheme, state?.disabledHosts ?? []);
});

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "hued:theme") {
    chrome.storage.local.get({ disabledHosts: [] }, ({ disabledHosts }) => applyTheme(message.theme, disabledHosts));
  }
  if (message?.type === "hued:host-policy" && message.host === location.hostname) {
    if (!message.enabled) document.documentElement.removeAttribute(ROOT_ATTRIBUTE);
    else chrome.runtime.sendMessage({ type: "hued:get" }, (state) => applyTheme(state?.activeTheme, state?.disabledHosts ?? []));
  }
});
})();
