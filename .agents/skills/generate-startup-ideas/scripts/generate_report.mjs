#!/usr/bin/env node

import { allIdeas, list, markdown, readJson, writeText } from "./lib.mjs";

const [sessionPath, reportPath] = process.argv.slice(2);

if (!sessionPath || !reportPath) {
  console.error("Usage: node generate_report.mjs <session.json> <report.md>");
  process.exit(1);
}

try {
  const session = readJson(sessionPath);
  const ideas = allIdeas(session);
  const ideaMap = new Map(ideas.map((idea) => [idea.id, idea]));
  const sourceMap = new Map((session.researchLedger ?? []).map((source) => [source.id, source]));
  const validationMap = new Map((session.validations ?? []).map((validation) => [validation.ideaId, validation]));
  const winner = session.winnerId ? ideaMap.get(session.winnerId) : null;
  const winnerValidation = session.winnerId ? validationMap.get(session.winnerId) : null;

  const latestReaction = new Map();
  for (const event of session.feedback ?? []) {
    for (const reaction of event.reactions ?? []) latestReaction.set(reaction.ideaId, reaction);
  }

  const lines = [];
  lines.push("# Startup Idea Machine Report");
  lines.push("");
  lines.push("Generated from session `" + markdown(session.sessionId) + "` on " + markdown(session.updatedAt) + ".");
  lines.push("");
  lines.push("## Decision");
  lines.push("");
  lines.push("- **Winner:** " + (winner ? markdown(winner.title) + " (" + winner.id + ")" : "No winner selected"));
  lines.push("- **Verdict:** " + markdown(session.verdict));
  lines.push("- **Weighted score:** " + (winnerValidation ? winnerValidation.weightedScore + "/100 — " + winnerValidation.scoreBand : "Not yet scored"));
  lines.push("- **Next test:** " + markdown(winnerValidation?.validationPlan?.[0]));
  lines.push("");
  lines.push("## Founder profile");
  lines.push("");
  lines.push("- **Advantage:** " + list(session.profile?.founderAdvantage));
  lines.push("- **Taste:** " + list(session.profile?.taste));
  lines.push("- **Constraints:** " + list(session.profile?.constraints));
  lines.push("- **Avoid:** " + list(session.profile?.avoid));
  lines.push("- **Hunt mode:** " + markdown(session.mode));
  lines.push("");
  lines.push("## How the machine learned");
  lines.push("");
  lines.push("- **Idea rounds:** " + (session.rounds?.length ?? 0));
  lines.push("- **Ideas generated:** " + ideas.length);
  lines.push("- **Love signals:** " + formatTagCounts(session.tasteProfile?.lovedTags));
  lines.push("- **Maybe signals:** " + formatTagCounts(session.tasteProfile?.maybeTags));
  lines.push("- **Rejected signals:** " + formatTagCounts(session.tasteProfile?.rejectedTags));
  lines.push("");

  if ((session.tasteProfile?.explicitReasons ?? []).length) {
    lines.push("### Explicit founder reactions");
    lines.push("");
    for (const item of session.tasteProfile.explicitReasons) {
      lines.push("- **" + item.ideaId + " · " + item.reaction.toUpperCase() + ":** " + markdown(item.reason));
    }
    lines.push("");
  }

  const latestRound = session.rounds?.[session.rounds.length - 1];
  lines.push("## Current idea burst");
  lines.push("");
  if (latestRound?.ideas?.length) {
    lines.push("Round " + latestRound.roundNumber + " contains " + latestRound.ideas.length + " ideas. React with `Love`, `Maybe`, or `No` using the idea IDs.");
    lines.push("");
    for (const idea of latestRound.ideas) {
      lines.push("### " + idea.id + " — " + markdown(idea.title) + (idea.exploratory ? " _(exploratory)_" : ""));
      lines.push("");
      lines.push("- **Customer:** " + markdown(idea.customer));
      lines.push("- **Pain:** " + markdown(idea.problem));
      lines.push("- **Product:** " + markdown(idea.product));
      lines.push("- **Signal:** " + markdown(idea.signal));
      lines.push("- **Why this idea:** " + markdown(idea.whyFounder));
      lines.push("- **Shape:** " + markdown(idea.ideaShape));
      lines.push("- **Evidence:** " + formatSources(idea.sourceIds, sourceMap));
      lines.push("");
    }
  } else {
    lines.push("No idea round has been generated yet.");
    lines.push("");
  }

  lines.push("## Finalist leaderboard");
  lines.push("");
  if ((session.validations ?? []).length) {
    lines.push("| Idea | Score | Band | Fatal assumption |");
    lines.push("| --- | ---: | --- | --- |");
    for (const validation of [...session.validations].sort((a, b) => b.weightedScore - a.weightedScore)) {
      const idea = ideaMap.get(validation.ideaId);
      lines.push("| " + markdown(idea?.title ?? validation.ideaId) + " | " + validation.weightedScore + " | " + validation.scoreBand + " | " + markdown(validation.fatalAssumption) + " |");
    }
  } else {
    lines.push("No finalists have been validated yet.");
  }
  lines.push("");

  if (winner && winnerValidation) {
    lines.push("## Winning idea");
    lines.push("");
    lines.push("### " + markdown(winner.title));
    lines.push("");
    lines.push("- **Customer:** " + markdown(winner.customer));
    lines.push("- **Pain:** " + markdown(winner.problem));
    lines.push("- **Product:** " + markdown(winner.product));
    lines.push("- **Signal:** " + markdown(winner.signal));
    lines.push("- **Founder connection:** " + markdown(winner.whyFounder));
    lines.push("- **MVP wedge:** " + markdown(winnerValidation.mvp));
    lines.push("- **First users:** " + markdown(winnerValidation.firstUsers));
    lines.push("- **Pricing hypothesis:** " + markdown(winnerValidation.pricingHypothesis));
    lines.push("");
    lines.push("### Evidence for and against");
    lines.push("");
    lines.push("- **Summary:** " + markdown(winnerValidation.summary));
    lines.push("- **Strongest evidence:** " + formatSources(winnerValidation.strongestEvidence, sourceMap));
    lines.push("- **Disconfirming evidence:** " + list(winnerValidation.disconfirmingEvidence));
    lines.push("- **Fatal assumption:** " + markdown(winnerValidation.fatalAssumption));
    lines.push("- **Unknowns:** " + list(winnerValidation.unknowns));
    lines.push("");
    lines.push("### Competitors and substitutes");
    lines.push("");
    for (const competitor of winnerValidation.competitors.length ? winnerValidation.competitors : ["Not yet researched"]) {
      lines.push("- " + markdown(competitor));
    }
    lines.push("");
    lines.push("### Seven-day validation plan");
    lines.push("");
    winnerValidation.validationPlan.forEach((step, index) => {
      lines.push((index + 1) + ". " + markdown(step));
    });
    lines.push("");
  }

  lines.push("## Idea journey");
  lines.push("");
  for (const round of session.rounds ?? []) {
    lines.push("### Round " + round.roundNumber + " — " + markdown(round.stage));
    lines.push("");
    lines.push("| ID | Idea | Customer | Shape | Reaction |");
    lines.push("| --- | --- | --- | --- | --- |");
    for (const idea of round.ideas ?? []) {
      const reaction = latestReaction.get(idea.id);
      const reactionText = reaction ? reaction.reaction.toUpperCase() + (reaction.reason ? ": " + reaction.reason : "") : "Unrated";
      lines.push("| " + idea.id + " | " + markdown(idea.title) + (idea.exploratory ? " _(exploratory)_" : "") + " | " + markdown(idea.customer) + " | " + markdown(idea.ideaShape) + " | " + markdown(reactionText) + " |");
    }
    lines.push("");
  }

  lines.push("## Evidence ledger");
  lines.push("");
  if ((session.researchLedger ?? []).length) {
    lines.push("| ID | Source | Date | State | Signal |");
    lines.push("| --- | --- | --- | --- | --- |");
    for (const source of session.researchLedger) {
      const title = "[" + markdown(source.title) + "](" + source.url + ")";
      lines.push("| " + source.id + " | " + title + " | " + markdown(source.publishedAt ?? "Undated") + " | " + markdown(source.evidenceState) + " | " + markdown(source.signal) + " |");
    }
  } else {
    lines.push("No public sources have been recorded yet.");
  }
  lines.push("");
  lines.push("## Limits");
  lines.push("");
  lines.push("Public research and generated ideas do not prove demand, willingness to pay, acquisition cost, retention, market size, or technical feasibility. The winner is a testable hypothesis. Validate it through real behavior and customer conversations before committing significant time or money.");

  writeText(reportPath, lines.join("\n"));
  console.log("Generated Markdown report at " + reportPath);
} catch (error) {
  console.error(error.message);
  process.exit(1);
}

function formatTagCounts(items = []) {
  return items.length ? items.map((item) => item.tag + " (" + item.count + ")").join(", ") : "None yet";
}

function formatSources(ids = [], sourceMap) {
  if (!ids.length) return "Not yet researched";
  return ids
    .map((id) => {
      const source = sourceMap.get(id);
      return source ? "[" + markdown(source.title) + "](" + source.url + ")" : id;
    })
    .join(", ");
}
