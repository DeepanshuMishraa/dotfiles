#!/usr/bin/env node

import {
  allIdeas,
  asStringArray,
  isoDate,
  readJson,
  requiredText,
  scoreValidation,
  verdictBand,
  writeJson
} from "./lib.mjs";

const [sessionPath, completionPath, outputPath = sessionPath] = process.argv.slice(2);

if (!sessionPath || !completionPath) {
  console.error("Usage: node complete_session.mjs <session.json> <completion.json> [output.json]");
  process.exit(1);
}

try {
  const session = readJson(sessionPath);
  const input = readJson(completionPath);
  const ideas = new Map(allIdeas(session).map((idea) => [idea.id, idea]));
  const validations = Array.isArray(input.validations) ? input.validations : [];
  if (!validations.length) throw new Error("At least one finalist validation is required.");

  const normalized = validations.map((validation, index) => {
    const ideaId = requiredText(validation.ideaId, "validations[" + index + "].ideaId");
    if (!ideas.has(ideaId)) throw new Error("Unknown finalist idea ID: " + ideaId);
    const weightedScore = scoreValidation(validation.scores);
    return {
      ideaId,
      summary: requiredText(validation.summary, ideaId + ".summary"),
      scores: validation.scores,
      weightedScore,
      scoreBand: verdictBand(weightedScore),
      strongestEvidence: asStringArray(validation.strongestEvidence, ideaId + ".strongestEvidence"),
      competitors: asStringArray(validation.competitors, ideaId + ".competitors"),
      disconfirmingEvidence: asStringArray(validation.disconfirmingEvidence, ideaId + ".disconfirmingEvidence"),
      fatalAssumption: requiredText(validation.fatalAssumption, ideaId + ".fatalAssumption"),
      mvp: requiredText(validation.mvp, ideaId + ".mvp"),
      firstUsers: requiredText(validation.firstUsers, ideaId + ".firstUsers"),
      pricingHypothesis: String(validation.pricingHypothesis ?? "").trim() || "Not yet validated",
      validationPlan: asStringArray(validation.validationPlan, ideaId + ".validationPlan"),
      unknowns: asStringArray(validation.unknowns, ideaId + ".unknowns")
    };
  });

  const winnerId = input.winnerId ? String(input.winnerId) : null;
  if (winnerId && !normalized.some((validation) => validation.ideaId === winnerId)) {
    throw new Error("winnerId must reference a validated idea.");
  }

  session.validations = normalized;
  session.winnerId = winnerId;
  session.verdict = requiredText(input.verdict, "verdict");
  session.completedAt = isoDate(input.completedAt);
  session.updatedAt = session.completedAt;
  session.status = winnerId ? "complete" : "no-go";

  writeJson(outputPath, session);
  console.log("Completed idea session with " + normalized.length + " finalist validations.");
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

