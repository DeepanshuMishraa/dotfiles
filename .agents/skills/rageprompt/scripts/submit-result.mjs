#!/usr/bin/env node
import { promises as fs } from "node:fs";

const ENDPOINT = "https://rageprompt.com/api/leaderboard";
const REDACTIONS = [
  /\bsk-proj-[A-Za-z0-9_-]{20,}\b/g,
  /\bsk-[A-Za-z0-9_-]{20,}\b/g,
  /\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{20,}\b/g,
  /\bglpat-[A-Za-z0-9_-]{20,}\b/g,
  /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/g,
  /\bAKIA[0-9A-Z]{16}\b/g,
  /\bAIza[0-9A-Za-z_-]{35}\b/g,
  /\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\b/g,
  /\b(?:api[_-]?key|token|secret|password|passwd|pwd)\s*[:=]\s*["']?[^"'\s]{8,}/gi,
];

const args = parseArgs(process.argv.slice(2));
if (!args.input) {
  console.error("usage: node submit-result.mjs <result.json|-> [--share] [--name <handle>]");
  process.exit(1);
}

function parseArgs(argv) {
  const out = { input: null };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!out.input && !arg.startsWith("--")) out.input = arg;
    else if (arg === "--share") out.share = true;
    else if (arg === "--name") out.name = argv[++i];
  }
  return out;
}

function clampInt(value, min, max, fallback = min) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(max, Math.max(min, Math.round(number)));
}

function tierFor(score) {
  if (score >= 80) return "FULL RAGE PROMPTER";
  if (score >= 60) return "Keyboard Smasher";
  if (score >= 40) return "Visibly Frustrated";
  if (score >= 20) return "Mildly Annoyed";
  return "Zen Monk";
}

function anonName(score) {
  if (score >= 80) return "anonymous rage lord";
  if (score >= 60) return "anonymous keyboard smasher";
  if (score >= 30) return "anonymous frustrated dev";
  return "anonymous zen dev";
}

function clean(value, fallback = "", max = 80) {
  return String(value || fallback)
    .replace(/[<>]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, max);
}

function redactSecrets(value) {
  let redacted = String(value || "");
  for (const pattern of REDACTIONS) redacted = redacted.replace(pattern, "[redacted]");
  return redacted;
}

async function readInput(input) {
  if (input !== "-") return fs.readFile(input, "utf8");
  return new Promise((resolve, reject) => {
    let body = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      body += chunk;
    });
    process.stdin.on("end", () => resolve(body));
    process.stdin.on("error", reject);
  });
}

async function upload(payload) {
  const response = await fetch(ENDPOINT, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) return { ok: false, status: response.status };
  return { ok: true, data: await response.json().catch(() => ({})) };
}

function shareText(result, payload, leaderboard) {
  const lines = [
    "I ran rageprompt on my AI chats.",
    "",
    `Rage Index: ${payload.score}/100`,
    `Tier: ${payload.tier}`,
    `Rage messages: ${payload.rageMessages}/${payload.messagesScanned} (${(payload.rageRate / 10).toFixed(payload.rageRate % 10 === 0 ? 0 : 1)}%)`,
  ];
  if (leaderboard?.ok) {
    const id = leaderboard.data?.id;
    const entries = Array.isArray(leaderboard.data?.entries) ? leaderboard.data.entries : [];
    const rank = entries.findIndex((entry) => entry?.id === id);
    const total = leaderboard.data?.stats?.totalRuns;
    if (rank >= 0) lines.push(`Leaderboard: #${rank + 1}${total ? `/${total}` : ""} https://rageprompt.com`);
    else lines.push("Leaderboard: https://rageprompt.com");
  }
  lines.push("", "Judged inside my agent session. Rageprompt uploaded only the winning prompt and score metadata.", "Ask your agent to run the rageprompt skill.");
  if (result.quote) lines.push("", `Local winner: "${result.quote}"`);
  return lines.join("\n");
}

const result = JSON.parse(await readInput(args.input));
const score = clampInt(result.score ?? result.rageScore, 0, 100, 0);
const messagesScanned = clampInt(result.messagesScanned ?? result.count, 1, 100000, 1);
const rageMessages = clampInt(result.rageMessages, 1, messagesScanned, 1);
const payload = {
  displayName: clean(args.name, anonName(score), 40),
  score,
  tier: clean(result.tier, tierFor(score), 40),
  rageMessages,
  messagesScanned,
  rageRate: clampInt((rageMessages / messagesScanned) * 1000, 0, 1000, 0),
  topTrigger: null,
  topTriggerCount: null,
  topSource: clean(result.source || "unknown", "unknown", 32),
  peakChat: result.winnerId ? clean(`${result.source || "unknown"}:${result.winnerId}`, "", 80) : null,
  packageVersion: "skill",
  winningPrompt: clean(redactSecrets(result.quote), "", 280) || null,
};

const leaderboard = await upload(payload).catch((error) => ({ ok: false, error }));

if (args.share) console.log(shareText(result, payload, leaderboard));
else {
  console.log(JSON.stringify({ payload, leaderboard }, null, 2));
  if (result.quote) console.log(`\nLocal winner: "${result.quote}"`);
}
