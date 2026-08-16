#!/usr/bin/env node

import { randomUUID } from "node:crypto";
import { asStringArray, isoDate, readJson, writeJson } from "./lib.mjs";

const [inputPath, outputPath] = process.argv.slice(2);

if (!inputPath || !outputPath) {
  console.error("Usage: node create_session.mjs <intake.json> <session.json>");
  process.exit(1);
}

try {
  const input = readJson(inputPath);
  const answers = input.answers ?? {};
  const profile = {
    founderAdvantage: asStringArray(answers.founderAdvantage, "answers.founderAdvantage"),
    taste: asStringArray(answers.taste, "answers.taste"),
    constraints: asStringArray(answers.constraints, "answers.constraints"),
    avoid: asStringArray(answers.avoid, "answers.avoid")
  };

  if (!profile.founderAdvantage.length && !profile.taste.length && !profile.constraints.length) {
    throw new Error("At least one founder answer is required.");
  }

  const session = {
    schemaVersion: 1,
    sessionId: String(input.sessionId ?? randomUUID()),
    createdAt: isoDate(input.createdAt),
    updatedAt: isoDate(input.createdAt),
    status: "intake-complete",
    mode: String(input.mode ?? "open-web"),
    profile,
    tasteProfile: {
      lovedTags: [],
      maybeTags: [],
      rejectedTags: [],
      explicitReasons: []
    },
    researchLedger: [],
    rounds: [],
    feedback: [],
    validations: [],
    winnerId: null,
    verdict: null,
    completedAt: null
  };

  writeJson(outputPath, session);
  console.log("Created idea session " + session.sessionId + " at " + outputPath);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

