# Effect Learning Checklist

## Status Legend
- ✅ Mastered
- 🔄 Partial
- ❌ Not yet

## Core Concepts
- [x] ✅ What is an Effect? (lazy typed computation)
- [x] ✅ Effect<Success, Error, Requirements> - the three params
- [x] ✅ Why errors are typed values, not thrown
- [ ] ❌ What "Requirements" (R) means — Context / Dependency Injection

## Building Blocks
- [x] ✅ Creating Effects (Effect.tryPromise, Effect.sync, Effect.gen/yield*)
- [x] ✅ Schema basics (Struct, String, Number, pipe, int, constraints, optional)
- [x] ✅ Composing Effects with yield* inside .gen
- [ ] ❌ Running Effects (runPromise, runSync, runFork)

## Apple Music Project
- [x] ✅ osascript wrapper (tryPromise with Bun.$)
- [x] ✅ osascriptList (parsing comma-separated output)
- [x] ✅ pagination utility (pure function)
- [x] ✅ library.ts (songs tool with Schema + paginate)
- [x] ✅ playlists.ts (list, play, tracks tools)
- [x] ✅ playback.ts (play, pause, next, prev)
- [x] ✅ volume.ts (get/set with Schema.optional)
- [x] ✅ index.ts (MCP server entry point)
- [ ] ❌ Connecting all tools to the MCP server
- [ ] ❌ Modeling errors as typed union instead of generic Error
- [ ] ❌ Using Effect Context for dependencies (OSAScript service)

## Open Questions
- (none yet)

