#!/usr/bin/env node
import { promises as fs } from "node:fs";
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import os from "node:os";
import path from "node:path";

const args = parseArgs(process.argv.slice(2));
const limit = args.limit == null ? 2000 : args.limit;

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--limit") out.limit = Number(argv[++i]);
    if (arg === "--no-redact") out.noRedact = true;
  }
  return out;
}

async function walkFiles(root, predicate) {
  const out = [];
  let entries;
  try {
    entries = await fs.readdir(root, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const entry of entries) {
    const file = path.join(root, entry.name);
    if (entry.isDirectory()) out.push(...(await walkFiles(file, predicate)));
    else if (entry.isFile() && predicate(file, entry.name)) out.push(file);
  }
  return out;
}

async function readJsonl(file) {
  const raw = await fs.readFile(file, "utf8").catch(() => "");
  const out = [];
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    try {
      out.push(JSON.parse(line));
    } catch {
      /* skip malformed history lines */
    }
  }
  return out;
}

function toMs(value) {
  if (value == null) return 0;
  if (typeof value === "number") return value < 1e12 ? Math.round(value * 1000) : Math.round(value);
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function textFromContent(content) {
  if (typeof content === "string") return content.trim() || null;
  if (Array.isArray(content)) {
    const text = content
      .map((part) => (typeof part === "string" ? part : part?.text || ""))
      .join("\n")
      .trim();
    return text || null;
  }
  if (content?.parts && Array.isArray(content.parts)) {
    const text = content.parts
      .map((part) => (typeof part === "string" ? part : part?.text || ""))
      .join("\n")
      .trim();
    return text || null;
  }
  return null;
}

function roleOf(message) {
  const role =
    message?.role ??
    message?.sender ??
    message?.from ??
    (typeof message?.author === "string" ? message.author : message?.author?.role);
  return typeof role === "string" ? role.toLowerCase() : "";
}

const USER_ROLES = new Set(["user", "human", "you", "prompt"]);

function messageText(message) {
  if (typeof message === "string") return message.trim() || null;
  for (const key of ["text", "message", "prompt", "value", "display"]) {
    if (typeof message?.[key] === "string" && message[key].trim()) return message[key].trim();
  }
  return textFromContent(message?.content);
}

function messageTs(message, fallback = 0) {
  return toMs(message?.ts ?? message?.timestamp ?? message?.created_at ?? message?.create_time ?? message?.time) || fallback;
}

async function readJsonFile(file, maxBytes = 8 * 1024 * 1024) {
  const stat = await fs.stat(file).catch(() => null);
  if (!stat || stat.size > maxBytes) return null;
  try {
    return JSON.parse(await fs.readFile(file, "utf8"));
  } catch {
    return null;
  }
}

function idFor(message) {
  return createHash("sha256")
    .update(`${message.source}|${message.chatId}|${message.ts}|${message.text}`)
    .digest("hex")
    .slice(0, 16);
}

function redact(text) {
  if (args.noRedact) return text;
  return text
    .replace(/\bsk-proj-[A-Za-z0-9_-]{20,}\b/g, "[redacted]")
    .replace(/\bsk-[A-Za-z0-9_-]{20,}\b/g, "[redacted]")
    .replace(/\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{20,}\b/g, "[redacted]")
    .replace(/\bAKIA[0-9A-Z]{16}\b/g, "[redacted]")
    .replace(/\bAIza[0-9A-Za-z_-]{35}\b/g, "[redacted]")
    .replace(/\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b/g, "[redacted]")
    .replace(/\b(?:api[_-]?key|token|secret|password|passwd|pwd)\s*[:=]\s*["']?[^"'\s]{8,}/gi, "[redacted]");
}

async function fetchClaude() {
  const messages = [];
  const files = await walkFiles(path.join(os.homedir(), ".claude", "projects"), (_p, name) => name.endsWith(".jsonl"));
  for (const file of files) {
    const stat = await fs.stat(file).catch(() => null);
    for (const entry of await readJsonl(file)) {
      if (entry?.type !== "user" || entry?.isMeta) continue;
      const text = textFromContent(entry?.message?.content);
      if (text) messages.push({ text, source: "claude", ts: toMs(entry.timestamp) || stat?.mtimeMs || 0, chatId: path.basename(file, ".jsonl") });
    }
  }
  for (const entry of await readJsonl(path.join(os.homedir(), ".claude", "history.jsonl"))) {
    const text = messageText(entry);
    if (text) messages.push({ text, source: "claude", ts: toMs(entry.timestamp), chatId: entry.project || "history" });
  }
  return messages;
}

async function fetchCodex() {
  const messages = [];
  const roots = [
    path.join(os.homedir(), ".codex", "sessions"),
    path.join(os.homedir(), ".codex", "archived_sessions"),
  ];
  for (const root of roots) {
    for (const file of await walkFiles(root, (_p, name) => name.endsWith(".jsonl"))) {
      const stat = await fs.stat(file).catch(() => null);
      let chatId = path.basename(file, ".jsonl");
      for (const entry of await readJsonl(file)) {
        const payload = entry?.payload;
        if (entry?.type === "session_meta" && payload?.session_id) chatId = payload.session_id;
        if (entry?.type !== "event_msg" || payload?.type !== "user_message") continue;
        const text = typeof payload.message === "string" ? payload.message.trim() : "";
        if (text) messages.push({ text, source: "codex", ts: toMs(entry.timestamp) || stat?.mtimeMs || 0, chatId });
      }
    }
  }
  for (const entry of await readJsonl(path.join(os.homedir(), ".codex", "history.jsonl"))) {
    const text = typeof entry?.text === "string" ? entry.text.trim() : "";
    if (text) messages.push({ text, source: "codex", ts: toMs(entry.ts), chatId: entry.session_id || "history" });
  }
  return messages;
}

function sqliteJson(dbPath, sql) {
  return new Promise((resolve) => {
    const child = spawn("sqlite3", ["-json", dbPath, sql], { stdio: ["ignore", "pipe", "ignore"] });
    let stdout = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.on("error", () => resolve([]));
    child.on("close", (code) => {
      if (code !== 0 || !stdout.trim()) return resolve([]);
      try {
        resolve(JSON.parse(stdout));
      } catch {
        resolve([]);
      }
    });
  });
}

function collectObjects(value, source, chatId, ts = 0) {
  const messages = [];
  function add(text, item = {}, localChatId = chatId) {
    const clean = typeof text === "string" ? text.trim() : "";
    if (!clean) return;
    messages.push({ text: clean, source, ts: messageTs(item, ts), chatId: String(localChatId || chatId || source) });
  }
  function visit(node, localChatId = chatId) {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) {
      for (const child of node) visit(child, localChatId);
      return;
    }
    const role = roleOf(node);
    const id = node.conversationId || node.composerId || node.sessionID || node.session_id || localChatId;
    if (USER_ROLES.has(role)) add(messageText(node), node, id);
    if (!role && typeof node.text === "string" && "commandType" in node) add(node.text, node, id);
    for (const child of Object.values(node)) {
      if (child && typeof child === "object") visit(child, id);
    }
  }
  visit(value, chatId);
  return messages;
}

function userDataRoots(appName) {
  const home = os.homedir();
  if (process.platform === "darwin") return [path.join(home, "Library", "Application Support", appName, "User")];
  if (process.platform === "win32") return [path.join(process.env.APPDATA || path.join(home, "AppData", "Roaming"), appName, "User")];
  return [path.join(process.env.XDG_CONFIG_HOME || path.join(home, ".config"), appName, "User")];
}

function sourceFromStorageKey(key, fallback) {
  const lower = String(key || "").toLowerCase();
  if (lower.includes("copilot")) return "copilot";
  if (lower.includes("cline") || lower.includes("claude-dev")) return "cline";
  if (lower.includes("roo")) return "roo";
  if (lower.includes("continue")) return "continue";
  if (lower.includes("codeium") || lower.includes("cascade") || lower.includes("windsurf")) return "windsurf";
  if (lower.includes("gemini")) return "gemini";
  return fallback;
}

function sourceFromExtensionDir(dir, fallback) {
  const lower = path.basename(dir).toLowerCase();
  if (lower.includes("github.copilot")) return "copilot";
  if (lower.includes("cline") || lower.includes("claude-dev")) return "cline";
  if (lower.includes("roo")) return "roo";
  if (lower.includes("continue")) return "continue";
  if (lower.includes("codeium") || lower.includes("windsurf")) return "windsurf";
  if (lower.includes("gemini")) return "gemini";
  return fallback;
}

async function collectJsonTree(root, source) {
  const messages = [];
  const files = await walkFiles(root, (_p, name) => /\.(json|jsonl)$/i.test(name));
  for (const file of files) {
    const stat = await fs.stat(file).catch(() => null);
    if (!stat || stat.size > 8 * 1024 * 1024) continue;
    if (file.endsWith(".jsonl")) {
      for (const entry of await readJsonl(file)) {
        messages.push(...collectObjects(entry, source, path.basename(path.dirname(file)), stat.mtimeMs));
      }
    } else {
      const data = await readJsonFile(file);
      if (data) messages.push(...collectObjects(data, source, path.basename(path.dirname(file)), stat.mtimeMs));
    }
  }
  return messages;
}

async function fetchVSCodeWorkspace(appName, fallbackSource) {
  const messages = [];
  const sql =
    "select key, value from ItemTable where key like '%composer%' " +
    "or key like '%chat%' or key like '%prompt%' or key like '%copilot%' " +
    "or key like '%cline%' or key like '%roo%' or key like '%continue%' " +
    "or key like '%codeium%' or key like '%cascade%' or key like 'aiService.%'";
  for (const root of userDataRoots(appName).map((userRoot) => path.join(userRoot, "workspaceStorage"))) {
    for (const db of await walkFiles(root, (_p, name) => name === "state.vscdb")) {
      const stat = await fs.stat(db).catch(() => null);
      for (const row of await sqliteJson(db, sql)) {
        if (typeof row?.value !== "string" || !row.value.trim()) continue;
        try {
          messages.push(...collectObjects(JSON.parse(row.value), sourceFromStorageKey(row.key, fallbackSource), path.basename(path.dirname(db)), stat?.mtimeMs || 0));
        } catch {
          /* non-json value */
        }
      }
    }
  }
  return messages;
}

async function fetchVSCodeGlobalAgents() {
  const messages = [];
  const apps = ["Code", "Code - Insiders", "VSCodium", "Cursor", "Windsurf", "Trae"];
  const interesting = /(copilot|cline|claude-dev|roo|continue|codeium|windsurf|gemini)/i;
  for (const app of apps) {
    for (const root of userDataRoots(app).map((userRoot) => path.join(userRoot, "globalStorage"))) {
      let entries = [];
      try {
        entries = await fs.readdir(root, { withFileTypes: true });
      } catch {
        continue;
      }
      for (const entry of entries) {
        if (!entry.isDirectory() || !interesting.test(entry.name)) continue;
        const dir = path.join(root, entry.name);
        const source = sourceFromExtensionDir(dir, "vscode");
        messages.push(...(await collectJsonTree(dir, source)));
        for (const db of await walkFiles(dir, (_p, name) => name === "state.vscdb")) {
          const rows = await sqliteJson(db, "select key, value from ItemTable where key like '%chat%' or key like '%history%' or key like '%task%' or key like '%session%'");
          const stat = await fs.stat(db).catch(() => null);
          for (const row of rows) {
            if (typeof row?.value !== "string" || !row.value.trim()) continue;
            try {
              messages.push(...collectObjects(JSON.parse(row.value), sourceFromStorageKey(row.key, source), entry.name, stat?.mtimeMs || 0));
            } catch {
              /* non-json value */
            }
          }
        }
      }
    }
  }
  return messages;
}

async function fetchCursor() {
  return fetchVSCodeWorkspace("Cursor", "cursor");
}

async function fetchWindsurf() {
  return [...(await fetchVSCodeWorkspace("Windsurf", "windsurf")), ...(await collectJsonTree(path.join(os.homedir(), ".codeium"), "windsurf"))];
}

async function fetchTrae() {
  return fetchVSCodeWorkspace("Trae", "trae");
}

async function fetchGemini() {
  const files = await walkFiles(path.join(os.homedir(), ".gemini", "tmp"), (file, name) => name.endsWith(".json") && file.split(path.sep).includes("chats"));
  const messages = [];
  for (const file of files) {
    try {
      messages.push(...collectObjects(JSON.parse(await fs.readFile(file, "utf8")), "gemini", path.basename(file, ".json")));
    } catch {
      /* skip */
    }
  }
  return messages;
}

async function fetchOpenCode() {
  const root = path.join(os.homedir(), ".local", "share", "opencode");
  const files = await walkFiles(root, (file, name) => name.endsWith(".json") && /session|message|part|storage/i.test(file));
  const messages = [];
  for (const file of files) {
    const data = await readJsonFile(file);
    if (data) messages.push(...collectObjects(data, "opencode", path.basename(path.dirname(file))));
  }
  const db = path.join(root, "opencode.db");
  const tables = await sqliteJson(db, "select name from sqlite_master where type='table'");
  for (const { name } of tables) {
    if (!/message|part|session/i.test(name)) continue;
    const safeName = String(name).replaceAll('"', '""');
    const rows = await sqliteJson(db, `select * from "${safeName}" limit 5000`);
    for (const row of rows) {
      messages.push(...collectObjects(row, "opencode", row.session_id || row.sessionID || name));
    }
  }
  return messages;
}

async function fetchContinue() {
  return collectJsonTree(path.join(os.homedir(), ".continue"), "continue");
}

async function fetchAider() {
  const messages = [];
  let dir = process.cwd();
  for (;;) {
    const file = path.join(dir, ".aider.chat.history.md");
    const raw = await fs.readFile(file, "utf8").catch(() => "");
    if (raw) {
      const stat = await fs.stat(file).catch(() => null);
      for (const block of raw.split(/^#{1,6}\s+/m)) {
        if (!/^(?:user|human)\b/i.test(block.trim())) continue;
        const text = block.replace(/^(?:user|human)\b[:\s-]*/i, "").trim();
        if (text) messages.push({ text, source: "aider", ts: stat?.mtimeMs || 0, chatId: file });
      }
    }
    const next = path.dirname(dir);
    if (next === dir) break;
    dir = next;
  }
  return messages;
}

const groups = await Promise.all([
  fetchClaude(),
  fetchCodex(),
  fetchCursor(),
  fetchGemini(),
  fetchOpenCode(),
  fetchWindsurf(),
  fetchTrae(),
  fetchVSCodeGlobalAgents(),
  fetchContinue(),
  fetchAider(),
]);

const seen = new Set();
const messages = [];
for (const message of groups.flat()) {
  const clean = typeof message.text === "string" ? message.text.trim() : "";
  if (!clean) continue;
  const key = `${message.source}|${message.chatId}|${message.ts}|${clean}`;
  if (seen.has(key)) continue;
  seen.add(key);
  messages.push({ ...message, text: clean });
}

messages.sort((a, b) => b.ts - a.ts);
const sliced = Number.isFinite(limit) ? messages.slice(0, limit) : messages;
const output = {
  schemaVersion: "rageprompt-skill-history-v1",
  generatedAt: new Date().toISOString(),
  count: sliced.length,
  sources: Object.fromEntries(
    [...new Set(sliced.map((message) => message.source))]
      .sort()
      .map((source) => [source, sliced.filter((message) => message.source === source).length])
  ),
  messages: sliced.map((message) => ({
    id: idFor(message),
    source: message.source,
    chatId: message.chatId,
    createdAt: message.ts ? new Date(message.ts).toISOString() : null,
    text: redact(message.text),
  })),
};

console.log(JSON.stringify(output, null, 2));
