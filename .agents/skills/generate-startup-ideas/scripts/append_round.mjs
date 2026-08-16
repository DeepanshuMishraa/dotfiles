#!/usr/bin/env node

import {
  allIdeas,
  asStringArray,
  isoDate,
  normalizeTitle,
  readJson,
  requiredText,
  writeJson
} from "./lib.mjs";

const [sessionPath, roundPath, outputPath = sessionPath] = process.argv.slice(2);

if (!sessionPath || !roundPath) {
  console.error("Usage: node append_round.mjs <session.json> <round.json> [output.json]");
  process.exit(1);
}

try {
  const session = readJson(sessionPath);
  const input = readJson(roundPath);
  const ideas = Array.isArray(input.ideas) ? input.ideas : [];
  const sources = Array.isArray(input.sources) ? input.sources : [];

  if (!ideas.length) throw new Error("The round must contain at least one idea.");

  const existingIdeas = allIdeas(session);
  const existingIds = new Set(existingIdeas.map((idea) => idea.id));
  const existingTitles = new Set(existingIdeas.map((idea) => normalizeTitle(idea.title)));
  const sourceMap = new Map((session.researchLedger ?? []).map((source) => [source.id, source]));

  for (const source of sources) {
    const normalized = {
      id: requiredText(source.id, "source.id"),
      url: requiredText(source.url, "source.url"),
      title: requiredText(source.title, "source.title"),
      sourceType: requiredText(source.sourceType, "source.sourceType"),
      publishedAt: source.publishedAt ? String(source.publishedAt) : null,
      accessedAt: source.accessedAt ? String(source.accessedAt) : isoDate().slice(0, 10),
      signal: requiredText(source.signal, "source.signal"),
      evidenceState: String(source.evidenceState ?? "observed")
    };
    if (!["observed", "inferred", "exploratory", "unknown"].includes(normalized.evidenceState)) {
      throw new Error("Invalid evidence state for " + normalized.id);
    }
    const previous = sourceMap.get(normalized.id);
    if (previous && (previous.url !== normalized.url || previous.signal !== normalized.signal)) {
      throw new Error("Source ID " + normalized.id + " conflicts with an existing source.");
    }
    sourceMap.set(normalized.id, normalized);
  }

  const normalizedIdeas = ideas.map((idea, index) => {
    const id = requiredText(idea.id, "ideas[" + index + "].id");
    const title = requiredText(idea.title, "ideas[" + index + "].title");
    const normalizedTitle = normalizeTitle(title);
    if (existingIds.has(id)) throw new Error("Duplicate idea ID: " + id);
    if (existingTitles.has(normalizedTitle)) throw new Error("Duplicate idea title: " + title);
    existingIds.add(id);
    existingTitles.add(normalizedTitle);

    const sourceIds = asStringArray(idea.sourceIds, "idea.sourceIds");
    for (const sourceId of sourceIds) {
      if (!sourceMap.has(sourceId)) throw new Error("Unknown source ID " + sourceId + " for " + id);
    }

    return {
      id,
      title,
      customer: requiredText(idea.customer, id + ".customer"),
      problem: requiredText(idea.problem, id + ".problem"),
      product: requiredText(idea.product, id + ".product"),
      signal: requiredText(idea.signal, id + ".signal"),
      whyFounder: requiredText(idea.whyFounder, id + ".whyFounder"),
      ideaShape: requiredText(idea.ideaShape, id + ".ideaShape"),
      tags: asStringArray(idea.tags, id + ".tags"),
      sourceIds,
      exploratory: Boolean(idea.exploratory),
      parentIdeaIds: asStringArray(idea.parentIdeaIds, id + ".parentIdeaIds")
    };
  });

  const expectedRound = (session.rounds?.length ?? 0) + 1;
  const roundNumber = Number(input.roundNumber ?? expectedRound);
  if (roundNumber !== expectedRound) {
    throw new Error("Expected round " + expectedRound + " but received " + roundNumber + ".");
  }

  session.researchLedger = [...sourceMap.values()];
  session.rounds = [
    ...(session.rounds ?? []),
    {
      roundNumber,
      stage: String(input.stage ?? (roundNumber === 1 ? "exploration" : "refinement")),
      createdAt: isoDate(input.createdAt),
      ideas: normalizedIdeas
    }
  ];
  session.updatedAt = isoDate(input.createdAt);
  session.status = "awaiting-feedback";

  writeJson(outputPath, session);
  console.log("Appended round " + roundNumber + " with " + normalizedIdeas.length + " ideas.");
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

