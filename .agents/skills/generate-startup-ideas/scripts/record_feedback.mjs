#!/usr/bin/env node

import { allIdeas, isoDate, readJson, requiredText, writeJson } from "./lib.mjs";

const [sessionPath, feedbackPath, outputPath = sessionPath] = process.argv.slice(2);

if (!sessionPath || !feedbackPath) {
  console.error("Usage: node record_feedback.mjs <session.json> <feedback.json> [output.json]");
  process.exit(1);
}

try {
  const session = readJson(sessionPath);
  const input = readJson(feedbackPath);
  const ideas = new Map(allIdeas(session).map((idea) => [idea.id, idea]));
  const reactions = Array.isArray(input.reactions) ? input.reactions : [];
  const seen = new Set();

  if (!reactions.length) throw new Error("Feedback must contain at least one reaction.");

  const normalized = reactions.map((reaction, index) => {
    const ideaId = requiredText(reaction.ideaId, "reactions[" + index + "].ideaId");
    const value = requiredText(reaction.reaction, ideaId + ".reaction").toLowerCase();
    if (!ideas.has(ideaId)) throw new Error("Unknown idea ID: " + ideaId);
    if (!["love", "maybe", "no"].includes(value)) throw new Error("Invalid reaction for " + ideaId);
    if (seen.has(ideaId)) throw new Error("Duplicate feedback for " + ideaId);
    seen.add(ideaId);
    return {
      ideaId,
      reaction: value,
      reason: String(reaction.reason ?? "").trim() || null
    };
  });

  const event = {
    createdAt: isoDate(input.createdAt),
    reactions: normalized
  };
  session.feedback = [...(session.feedback ?? []), event];

  const latest = new Map();
  for (const feedback of session.feedback) {
    for (const reaction of feedback.reactions ?? []) latest.set(reaction.ideaId, reaction);
  }

  const buckets = { love: new Map(), maybe: new Map(), no: new Map() };
  const reasons = [];
  for (const reaction of latest.values()) {
    const idea = ideas.get(reaction.ideaId);
    for (const tag of idea?.tags ?? []) {
      const count = buckets[reaction.reaction].get(tag) ?? 0;
      buckets[reaction.reaction].set(tag, count + 1);
    }
    if (reaction.reason) {
      reasons.push({
        ideaId: reaction.ideaId,
        reaction: reaction.reaction,
        reason: reaction.reason
      });
    }
  }

  const rankedTags = (bucket) =>
    [...bucket.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map(([tag, count]) => ({ tag, count }));

  session.tasteProfile = {
    lovedTags: rankedTags(buckets.love),
    maybeTags: rankedTags(buckets.maybe),
    rejectedTags: rankedTags(buckets.no),
    explicitReasons: reasons
  };
  session.updatedAt = event.createdAt;
  session.status = "feedback-recorded";

  writeJson(outputPath, session);
  console.log("Recorded " + normalized.length + " reactions.");
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

