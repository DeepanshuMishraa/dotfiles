import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

export const SCORE_WEIGHTS = {
  pain: 18,
  frequency: 10,
  spendSignal: 14,
  reachability: 14,
  differentiation: 10,
  buildability: 12,
  timing: 8,
  founderFit: 9,
  evidenceConfidence: 5
};

export function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error("Could not read JSON from " + path + ": " + error.message);
  }
}

export function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, JSON.stringify(value, null, 2) + "\n", "utf8");
}

export function writeText(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, value.endsWith("\n") ? value : value + "\n", "utf8");
}

export function asStringArray(value, field) {
  if (value === undefined || value === null) return [];
  const values = Array.isArray(value) ? value : [value];
  const normalized = values.map((item) => String(item).trim()).filter(Boolean);
  if (values.length && !normalized.length) {
    throw new Error(field + " must contain meaningful text.");
  }
  return normalized;
}

export function requiredText(value, field) {
  const text = String(value ?? "").trim();
  if (!text) throw new Error(field + " is required.");
  return text;
}

export function isoDate(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) throw new Error("Invalid date: " + value);
  return date.toISOString();
}

export function normalizeTitle(value) {
  return String(value ?? "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export function allIdeas(session) {
  return (session.rounds ?? []).flatMap((round) => round.ideas ?? []);
}

export function scoreValidation(scores) {
  let total = 0;
  for (const [criterion, weight] of Object.entries(SCORE_WEIGHTS)) {
    const score = Number(scores?.[criterion]);
    if (!Number.isFinite(score) || score < 1 || score > 10) {
      throw new Error("Score " + criterion + " must be between 1 and 10.");
    }
    total += (score / 10) * weight;
  }
  return Math.round(total * 10) / 10;
}

export function verdictBand(total) {
  if (total >= 80) return "Pursue validation";
  if (total >= 65) return "Promising but exposed";
  if (total >= 50) return "Weak evidence or fit";
  return "Archive for now";
}

export function markdown(value) {
  const text = String(value ?? "").trim();
  return text ? text.replace(/\|/g, "\\|").replace(/\r?\n/g, " ") : "Not yet researched";
}

export function list(value) {
  const values = asStringArray(value, "list");
  return values.length ? values.join(", ") : "Not specified";
}

