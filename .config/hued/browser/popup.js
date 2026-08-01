const enabled = document.querySelector("#enabled");
const theme = document.querySelector("#theme");
const hostLabel = document.querySelector("#host");
const errorLabel = document.querySelector("#error");

const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
let host = "";
try {
  host = new URL(tab.url).hostname;
} catch {
  enabled.disabled = true;
}

const state = await chrome.storage.local.get({ disabledHosts: [], activeTheme: undefined, bridgeError: "" });
theme.textContent = state.activeTheme?.name ?? "Waiting for CLI";
hostLabel.textContent = host || "This browser page cannot be themed.";
errorLabel.textContent = state.bridgeError ?? "";
enabled.checked = host !== "" && !state.disabledHosts.includes(host);

enabled.addEventListener("change", async () => {
  await chrome.runtime.sendMessage({ type: "hued:set-host", host, enabled: enabled.checked });
});
