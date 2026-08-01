const HOST_NAME = "io.hued.bridge";
const RECONNECT_ALARM = "hued-native-reconnect";

let port;
let reconnectDelay = 1000;
let reconnectTimer;

async function broadcast(message) {
  const tabs = await chrome.tabs.query({});
  await Promise.allSettled(
    tabs
      .filter((tab) => typeof tab.id === "number")
      .map((tab) => chrome.tabs.sendMessage(tab.id, message)),
  );
}

async function storeTheme(theme) {
  await chrome.storage.local.set({ activeTheme: theme, bridgeError: "" });
  await chrome.alarms.clear(RECONNECT_ALARM);
  await broadcast({ type: "hued:theme", theme });
}

async function injectIntoOpenTab(tab) {
	if (typeof tab.id !== "number" || !/^https?:/.test(tab.url ?? "")) return;
	const css = ["styles/generic.css"];
	try {
		const url = new URL(tab.url);
		if (url.hostname === "github.com") css.push("styles/github.css");
		if (url.hostname === "www.notion.so" || url.hostname.endsWith(".notion.site")) css.push("styles/notion.css");
		if (url.hostname === "www.linkedin.com") css.push("styles/linkedin.css");
		if (url.hostname === "x.com" || url.hostname === "twitter.com") css.push("styles/x.css");
		if (url.hostname === "www.youtube.com" || url.hostname === "m.youtube.com") css.push("styles/youtube.css");
		await chrome.scripting.insertCSS({ target: { tabId: tab.id }, files: css });
		await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ["theme-engine.js", "content-script.js"] });
	} catch {
		// Chromium-protected pages cannot accept extension scripts.
	}
}

async function hydrateOpenTabs() {
	const tabs = await chrome.tabs.query({});
	await Promise.allSettled(tabs.map(injectIntoOpenTab));
}

function connect() {
	if (port) return;
	if (reconnectTimer) {
		clearTimeout(reconnectTimer);
		reconnectTimer = undefined;
	}
  try {
    port = chrome.runtime.connectNative(HOST_NAME);
  } catch (error) {
    scheduleReconnect(String(error));
    return;
  }

  port.onMessage.addListener((message) => {
    if (message?.type === "theme" && message.theme) {
      reconnectDelay = 1000;
      void storeTheme(message.theme);
    } else if (message?.type === "error") {
      void chrome.storage.local.set({ bridgeError: message.error });
    }
  });

  port.onDisconnect.addListener(() => {
    const error = chrome.runtime.lastError?.message ?? "Native host disconnected";
    port = undefined;
    scheduleReconnect(error);
  });

  port.postMessage({ type: "get_theme" });
}

function scheduleReconnect(error) {
  void chrome.storage.local.set({ bridgeError: error });
	if (reconnectTimer) clearTimeout(reconnectTimer);
	reconnectTimer = setTimeout(() => {
		reconnectTimer = undefined;
		connect();
	}, reconnectDelay);
	void chrome.alarms.create(RECONNECT_ALARM, { delayInMinutes: 0.5 });
  reconnectDelay = Math.min(reconnectDelay * 2, 30000);
}

chrome.alarms.onAlarm.addListener((alarm) => {
	if (alarm.name === RECONNECT_ALARM && !port) connect();
});

chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(() => {
	connect();
	void hydrateOpenTabs();
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.type === "hued:get") {
	if (!port) connect();
    chrome.storage.local.get(["activeTheme", "disabledHosts"], (state) => sendResponse(state));
    return true;
  }
  if (message?.type === "hued:set-host") {
    chrome.storage.local.get({ disabledHosts: [] }, async ({ disabledHosts }) => {
      const next = new Set(disabledHosts);
      if (message.enabled) next.delete(message.host);
      else next.add(message.host);
      await chrome.storage.local.set({ disabledHosts: [...next].sort() });
      await broadcast({ type: "hued:host-policy", host: message.host, enabled: message.enabled });
      sendResponse({ ok: true });
    });
    return true;
  }
  return false;
});

connect();
void hydrateOpenTabs();
