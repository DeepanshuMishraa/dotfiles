# Idea session schema

## Intake input

```json
{
  "sessionId": "optional-stable-id",
  "createdAt": "optional-ISO-timestamp",
  "mode": "open-web",
  "answers": {
    "founderAdvantage": ["web development", "founder communities"],
    "taste": ["B2B", "visual products"],
    "constraints": ["solo founder", "seven-day MVP"],
    "avoid": ["regulated health", "marketplaces"]
  }
}
```

## Round input

```json
{
  "roundNumber": 1,
  "stage": "exploration",
  "createdAt": "2026-08-10T12:00:00.000Z",
  "sources": [
    {
      "id": "SRC-01",
      "url": "https://example.com/source",
      "title": "Original source",
      "sourceType": "forum",
      "publishedAt": "2026-08-01",
      "accessedAt": "2026-08-10",
      "signal": "Teams describe a repeated manual workflow.",
      "evidenceState": "observed"
    }
  ],
  "ideas": [
    {
      "id": "IDEA-01",
      "title": "Example idea",
      "customer": "Small software teams",
      "problem": "A narrow repeated problem",
      "product": "A concise product mechanism",
      "signal": "Observed workflow evidence",
      "whyFounder": "Matches the founder's experience",
      "ideaShape": "workflow-automation",
      "tags": ["b2b", "developer-tool"],
      "sourceIds": ["SRC-01"],
      "exploratory": false,
      "parentIdeaIds": []
    }
  ]
}
```

## Feedback input

```json
{
  "createdAt": "2026-08-10T12:05:00.000Z",
  "reactions": [
    {
      "ideaId": "IDEA-01",
      "reaction": "love",
      "reason": "Clear buyer and visual demo"
    }
  ]
}
```

Allowed reactions are `love`, `maybe`, and `no`.

## Completion input

```json
{
  "completedAt": "2026-08-10T13:00:00.000Z",
  "winnerId": "IDEA-01",
  "verdict": "Pursue a seven-day validation test.",
  "validations": [
    {
      "ideaId": "IDEA-01",
      "summary": "Evidence-backed conclusion",
      "scores": {
        "pain": 8,
        "frequency": 7,
        "spendSignal": 6,
        "reachability": 9,
        "differentiation": 7,
        "buildability": 9,
        "timing": 7,
        "founderFit": 9,
        "evidenceConfidence": 7
      },
      "strongestEvidence": ["SRC-01"],
      "competitors": ["Existing substitute"],
      "disconfirmingEvidence": ["Important counter-signal"],
      "fatalAssumption": "The assumption most likely to kill the idea",
      "mvp": "Smallest useful product wedge",
      "firstUsers": "Reachable first-user description",
      "pricingHypothesis": "Unvalidated pricing hypothesis",
      "validationPlan": [
        "Day 1 action",
        "Day 2 action",
        "Day 3 action"
      ],
      "unknowns": ["Unknown willingness to pay"]
    }
  ]
}
```

Scripts add calculated totals and session status. Keep source IDs and idea IDs stable across rounds.

