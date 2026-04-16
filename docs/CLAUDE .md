# Anima — Claude Code Instructions

## What This Is

Anima is an AI-augmented design methodology system. The codebase started as VisionClaude (an open-source MCP server connecting Meta Ray-Ban glasses to Claude). We're building a memory and intelligence layer on top of it.

**Current phase: Phase 0 — Voice Has Memory**

## Phase 0 Scope (This Is What We're Building Now)

Goal: Wear the glasses, have a 10-minute design conversation about a lamp sketch, and the agent remembers the entire session, speaks in design language, and handles errors gracefully.

### Files to modify:
- `ClaudeVision/channel/direct-api.ts` — Main target. Add conversation history, design system prompt, retry logic, structured logging.
- `ClaudeVision/channel/server.ts` — Minor changes only: frame filtering (skip API calls when no voice text present).

### Phase 0 deliverables:
1. **Rolling conversation history** — Last 15-20 exchanges. Full images for last 2-3 frames, text-only summaries for older context.
2. **Design-specific system prompt** — Formal analysis, design vocabulary, concise. Not generic scene description.
3. **Retry logic** — Exponential backoff for 529 (overloaded) errors. Max 3 retries.
4. **Frame filtering** — Only call the API when the WebSocket message contains voice text, not on every frame/heartbeat.
5. **Structured session logging** — Every exchange tagged with type (sketch_capture, feedback_pair, decision, rejection, observation) at the moment it happens. Written to a session JSON file on session end.

## What Is Explicitly OUT OF SCOPE

Do not build any of these in Phase 0, even if they seem like natural extensions:
- Reference system (decomposed strategies, reference pools, entry schemas)
- Version tracking (branching version tree, curation status)
- ComfyUI integration or generation pipeline
- Exploration sets
- Project memory (cross-session persistence)
- Global archive or SQLite
- Web UI
- LoRA training pipeline
- Managed Agent integration (we're using direct API calls for now)

## Architecture Context

### Current working pipeline:
```
Meta Ray-Ban glasses → iPhone (VisionClaude app) → WebSocket → 
Channel server (server.ts on Mac mini) → direct-api.ts → Anthropic API → 
TTS (ElevenLabs) → response back to phone/glasses
```

### Key paths on this machine:
```
Repo root:        /Users/variable/Desktop/Design AI/visionclaude/
Channel server:   ClaudeVision/channel/server.ts
Direct API:       ClaudeVision/channel/direct-api.ts
Server backup:    ClaudeVision/channel/server.ts.backup
Project docs:     docs/
```

### How to start the system:
```bash
cd ClaudeVision/channel
export ANTHROPIC_API_KEY="..." 
bun run server.ts
```

### iOS app sends WebSocket messages like:
```json
{
  "id": "ios-1776102760.620806",
  "text": "[Mode: General] ...\n\nUser: Hello Claude",
  "source": "rayban",
  "image": "<base64 JPEG>"
}
```
The actual user speech is after "User: " — the mode prompt prefix is injected by the app.

## Technical Constraints

- Runtime: Bun (not Node)
- Model: claude-sonnet-4-20250514
- Each glasses frame: ~96KB JPEG → ~1,700 tokens as image
- Keep conversation history token-aware: full images for last 2-3 frames only
- API calls cost money — don't add unnecessary calls
- All data stays local (no cloud sync, no external services except Anthropic API and ElevenLabs TTS)

## Documentation

- `docs/visionclaude-brief.md` — Full setup context, file locations, what works/doesn't, iOS app behavior
- `docs/design-ai-memory-architecture.md` — Full memory system spec (most of this is future phases, but the entry tagging schema and session memory structure inform Phase 0 logging)

## Style

- TypeScript, minimal dependencies
- Small focused commits with clear messages
- Test changes by running the server and verifying WebSocket behavior
- When in doubt, keep it simple — this is a proof of concept
