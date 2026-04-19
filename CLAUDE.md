# Anima — Claude Code Instructions

## What This Is

Anima is an AI-augmented design methodology system. The codebase started as VisionClaude (an open-source MCP server connecting Meta Ray-Ban glasses to Claude). We're building a memory and intelligence layer on top of it.

**Current phase: Phase 1 — References Through the Glasses**

## Phase 0 — Voice Has Memory ✅ COMPLETE

Goal: Wear the glasses, have a 10-minute design conversation about a lamp sketch, and the agent remembers the entire session, speaks in design language, and handles errors gracefully.

**Validated end-to-end with glasses on April 16, 2026.**

### What was built:
1. **Rolling conversation history** — 15-exchange buffer. Full images for last 2-3 frames, `[image: sketch shown via glasses]` placeholder for older context.
2. **Design-specific system prompt** — Formal analysis, design vocabulary, concise. Communicates through smart glasses with voice.
3. **Retry logic** — Exponential backoff (1s, 2s, 4s) for 529/5xx errors. Max 3 retries.
4. **Frame filtering** — Only calls the API when the WebSocket message contains actual voice text, not on every frame/heartbeat.
5. **Structured session logging** — Every exchange tagged with type (sketch_capture, feedback_pair, decision, rejection, observation, general) written to `~/Desktop/Design AI/Anima Sessions/session-YYYY-MM-DD-HHmmss.json` on server shutdown or `clearHistory()`.

### Files modified in Phase 0:
- `ClaudeVision/channel/direct-api.ts` — Conversation history, design system prompt, retry logic, session logging, mode prefix stripping.
- `ClaudeVision/channel/server.ts` — Frame filtering guard, SIGINT/SIGTERM session save.

---

## Phase 1 Scope (This Is What We're Building Now)

Goal: Show an object through the glasses, discuss it, and the agent decomposes it into structured strategies and stores a reference entry. Come back the next session and the project context is already loaded.

### Phase 1 deliverables:

1. **Reference entry creation from glasses discussions** — When the designer shows an object and discusses it verbally, the agent creates a structured reference entry: the image, the designer's verbal signal, and a formal strategy decomposition. Stored as JSON in the project directory.

2. **Strategy decomposition with 9 categories** — Every reference entry is decomposed into discrete strategies across:
   - `material_treatment` — How materials are finished, joined, or left raw
   - `structural_approach` — How the object holds itself up, distributes load
   - `light_strategy` — How light is created, directed, diffused, or revealed
   - `functional_concept` — What the object does and how
   - `component_logic` — How parts relate and whether they earn multiple roles
   - `surface_quality` — Texture, finish, reflectivity, tactile character
   - `proportion_system` — Height-to-width relationships, visual weight distribution
   - `joint_detail` — How parts meet, visible vs hidden connections
   - `fabrication_technique` — How it's made and how that shows

3. **"Add to project pool" command** — Voice command to move a reference from session memory into the active project pool. Project pool is injected into context on subsequent sessions.

4. **Basic version tracking for sketch captures** — When the designer says "capture this" or "take a picture," create a version entry: image path, verbal description, approximate dimensions, identified strategies. Stored in the project's version tree (flat list for now, branching comes later).

5. **Project directory structure** — JSON files organized by project:
   ```
   ~/Desktop/Design AI/Anima Sessions/
   └── projects/
       └── <project-name>/
           ├── project.json        — brief, locked decisions, materials
           ├── references.json     — reference entries with decomposed strategies
           └── versions.json       — captured sketches and their metadata
   ```

6. **Project memory loads at session start, writes back on session end** — On server start, if a project is active, load `project.json`, `references.json`, and `versions.json` and inject summary into the system prompt. On shutdown or `clearHistory()`, write session entries back to project files.

### Files to modify:
- `ClaudeVision/channel/direct-api.ts` — Main target. Add reference entry creation, strategy decomposition, version capture, project load/save logic.
- `ClaudeVision/channel/server.ts` — Minor: pass project name on startup if needed.

## What Is Explicitly OUT OF SCOPE for Phase 1

Do not build any of these, even if they seem like natural extensions:
- ComfyUI integration or generation pipeline
- Exploration sets
- Global archive or SQLite
- Web UI
- Batch import (drop a folder of images)
- Agent web search for references
- LoRA training pipeline
- Branching version tree (flat list only for now)
- Cross-session pattern analysis or weekly consolidation

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
Session logs:     ~/Desktop/Design AI/Anima Sessions/
Project memory:   ~/Desktop/Design AI/Anima Sessions/projects/
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
- `docs/design-ai-memory-architecture.md` — Full memory system spec (Phases 2-3 inform Phase 1 scope; entry schemas, strategy categories, and project memory structure are all defined here)

## Style

- TypeScript, minimal dependencies
- Small focused commits with clear messages
- Test changes by running the server and verifying WebSocket behavior
- When in doubt, keep it simple — this is a proof of concept
