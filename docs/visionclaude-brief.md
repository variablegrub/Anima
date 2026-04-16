# VisionClaude Setup Brief — Context & Memory Layer Requirements

**Date:** April 13, 2026
**Author:** Armando Vargas Garcia Figueroa
**Project:** AI-Augmented Design Methodology — 3-Month Proof of Concept
**Purpose:** This document captures everything learned from the VisionClaude setup session to provide full context for building the memory and context layers in a separate conversation.

---

## 1. What VisionClaude Is

VisionClaude is an open-source MCP server (MIT license, github.com/mrdulasolutions/visionclaude) that turns Meta Ray-Ban Smart Glasses (or an iPhone camera) into a perception layer for Claude. The camera streams at 720p@30fps from the glasses, voice input uses Apple Speech Recognition, and TTS uses ElevenLabs Flash v2.5 or Apple's built-in fallback.

The pipeline: Meta Ray-Ban glasses → iPhone (VisionClaude iOS app) → WebSocket → VisionClaude server on Mac mini → Claude → voice response back to phone/glasses.

---

## 2. Current Working Architecture

### What's Running

The system is operational with a **modified Channel server** that bypasses Claude Code and calls the Anthropic API directly. Here's why:

- **Channel Mode** (the recommended mode) routes messages through Claude Code via MCP. However, Claude Code's channel feature is **not yet available** on Armando's account ("Channels are not currently available" error). Messages from the phone reach the server but go nowhere.
- **Gateway Mode** (the standalone alternative) calls the Anthropic API directly but uses HTTP instead of WebSocket. The iOS app only speaks WebSocket, so the phone **cannot connect** to Gateway Mode.
- **The working solution:** We patched the Channel server's `deliver()` function to call the Anthropic API directly instead of routing through Claude Code's MCP channel. Phone connects via WebSocket (which works), server calls Claude API (which works), response goes back to phone (which works).

### File Locations on Armando's Mac Mini

```
Project root:     /Users/variable/Desktop/Design AI/visionclaude/
Channel server:   /Users/variable/Desktop/Design AI/visionclaude/ClaudeVision/channel/
Gateway server:   /Users/variable/Desktop/Design AI/visionclaude/ClaudeVision/server/
iOS app source:   /Users/variable/Desktop/Design AI/visionclaude/ClaudeVision/ios/
MCP config:       /Users/variable/Desktop/Design AI/visionclaude/.mcp.json
State directory:   ~/.claude/channels/visionclaude/
Inbox (images):   ~/.claude/channels/visionclaude/inbox/
Outbox (TTS etc): ~/.claude/channels/visionclaude/outbox/
Token file:       ~/.claude/channels/visionclaude/.channel-token
ElevenLabs .env:  ~/.claude/channels/visionclaude/.env
Gateway .env:     /Users/variable/Desktop/Design AI/visionclaude/ClaudeVision/server/.env
```

### Modified Files

1. **`.mcp.json`** — Fixed path from developer's machine (`/Users/mrdulasolutions/...`) to Armando's (`/Users/variable/...`).

2. **`ClaudeVision/channel/server.ts`** — The `deliver()` function was patched to call the Anthropic API directly instead of relying on Claude Code's channel routing. A backup exists at `server.ts.backup`.

3. **`ClaudeVision/channel/direct-api.ts`** — New file. Contains the `callClaude()` function that makes direct Anthropic API calls with vision support. Currently uses `claude-sonnet-4-20250514` with a basic system prompt.

4. **`ClaudeVision/server/src/index.ts`** — Rate limiter changed from 30 to 300 requests/minute to accommodate the glasses' frame streaming.

5. **iOS app Bundle Identifier** — Changed from `com.claudevision.app` to `com.armandovargas.claudevision` (the original was already registered by someone else).

### How to Start the System

```bash
# Terminal 1 — Start the channel server
cd "/Users/variable/Desktop/Design AI/visionclaude/ClaudeVision/channel"
export ANTHROPIC_API_KEY="sk-ant-..."  # Key is also in the Gateway .env file
bun run server.ts

# iPhone — Open VisionClaude app
# Settings: Host = Mac mini's local IP, Port = 18790, Token = from dashboard
# Camera source: Meta Ray-Ban
```

### Network Details

- Server runs on `0.0.0.0:18790` (accessible from LAN)
- iPhone and Mac mini must be on the same Wi-Fi
- Dashboard at `http://localhost:18790` (Channel Mode only)
- WebSocket at `ws://<mac-ip>:18790/ws`
- Health check at `http://localhost:18790/health`
- All unencrypted (ws:// not wss://) — acceptable for home network, needs TLS for client deployment

---

## 3. What Works — First Test Results

### Vision Recognition
- Claude correctly identified a hand sketch as a study sketch of a cylindrical shape
- Once told it was a lamp with two variations, it understood the lamp shape, functioning, and which variation was being pointed at
- It can read formal qualities from sketches: geometry, proportions, implied function

### Voice Pipeline
- ElevenLabs TTS sounds natural
- Response latency is acceptable for a design workflow
- Apple Speech Recognition handles design vocabulary adequately

### Connection Stability
- WebSocket connection is stable once established
- Image frames arrive and are saved correctly to the inbox directory
- The 720p Ray-Ban frames are sufficient for sketch recognition

---

## 4. What Doesn't Work — Problems to Solve

### Problem 1: No Conversation Memory (CRITICAL — This Is What the Next Chat Builds)

**Current behavior:** Every message to Claude is a standalone API call. Each request includes only the system prompt, the current image, and the current voice transcript. Claude has zero memory of what was said 10 seconds ago.

**Observed impact:** When Armando pointed at a sketch and described it as a lamp with two variations, Claude didn't retain that context for follow-up questions. He had to re-explain what the sketch was each time.

**What's needed:**

The `direct-api.ts` file currently sends a single user message per API call:

```typescript
// Current (no memory):
messages.push({ role: 'user', content })
```

This needs to become a conversation with history. The memory layer should handle:

**A. Short-term context (within a design session):**
- Maintain a rolling conversation history (last N messages) so Claude remembers what was just discussed
- Include previous images as references ("the sketch I showed you earlier")
- Track the current design object being discussed ("we're working on a table lamp")

**B. Design session state:**
- What object is being designed (table lamp)
- What design direction has been established (cylindrical, two variations, playful gestures)
- What feedback has been given ("more organic, wider base")
- What references have been shown

**C. Long-term aesthetic memory (future — connects to LoRA training):**
- The designer's style preferences accumulated across sessions
- Material preferences, formal language tendencies
- This is the "aesthetic DNA" that eventually feeds into LoRA training

### Problem 2: Verbose and Redundant Descriptions

**Current behavior:** The system prompt tells Claude to "describe what you see with specificity" which triggers generic scene description: lighting conditions, background objects, desk surface, etc.

**What's needed:** A design-specific system prompt that focuses on:
- Formal qualities (proportions, geometry, topology, material implications)
- Design intent (what is this object trying to do/be?)
- Comparative analysis ("this variation has a wider base than the previous one")
- Concise design language, not exhaustive scene inventory

**Current system prompt (in `direct-api.ts`):**
```
You are a vision assistant seeing through smart glasses. Be concise (1-3 sentences). 
Describe what you see with specificity. Read all visible text exactly.
```

**Should become something like:**
```
You are a design assistant for an architect/industrial designer. When shown sketches or 
objects, analyze formal qualities: proportions, geometry, topology, material implications, 
and design intent. Use precise design vocabulary. Don't describe the scene — focus on the 
design object. Be concise (1-3 sentences) unless asked for detail. When given design 
feedback, acknowledge the intent and suggest how it might manifest formally.
```

### Problem 3: "Take a Picture" Doesn't Work

**Current behavior:** Claude says it can't take pictures. The app streams frames automatically, but Claude doesn't know it has access to the current frame.

**What's needed:** Claude should understand that:
- It always has the current camera frame available
- "Capture this" or "take a picture" means "analyze the current frame in detail and store it as a reference for this design session"
- The app has a QR/scanning mode that might handle explicit captures differently

This connects to the memory layer — a "captured" image should be tagged and stored in session memory as a reference point.

### Problem 4: 529 Overloaded Errors

Intermittent Anthropic API overload errors. Not a configuration issue. Solutions:
- Add retry logic with exponential backoff to `direct-api.ts`
- Optionally fall back to a different model (e.g., Haiku) if Sonnet is overloaded
- Queue messages during outages rather than dropping them

---

## 5. Architecture of `direct-api.ts` (The File That Needs the Memory Layer)

This is the complete current file that handles Claude API calls:

```typescript
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY ?? ''

export async function callClaude(text: string, imagePath?: string): Promise<string> {
  if (!ANTHROPIC_API_KEY) return 'Error: No ANTHROPIC_API_KEY set.'
  
  const messages: any[] = []
  const content: any[] = []
  
  if (imagePath) {
    try {
      const { readFileSync } = await import('fs')
      const buf = readFileSync(imagePath)
      const base64 = buf.toString('base64')
      const ext = imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg'
      content.push({ type: 'image', source: { type: 'base64', media_type: ext, data: base64 } })
    } catch (e) {
      content.push({ type: 'text', text: `(failed to load image: ${e})` })
    }
  }
  
  content.push({ type: 'text', text: text || 'What do you see?' })
  messages.push({ role: 'user', content })
  
  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      system: 'You are a vision assistant seeing through smart glasses. Be concise (1-3 sentences). Describe what you see with specificity. Read all visible text exactly.',
      messages,
    }),
  })
  
  if (!resp.ok) {
    const err = await resp.text()
    return `API error ${resp.status}: ${err.slice(0, 200)}`
  }
  
  const data = await resp.json() as any
  return data.content?.map((c: any) => c.text || '').join('') || 'No response'
}
```

**Key points for modification:**
- `messages` array currently gets one message per call. This is where conversation history goes.
- `system` prompt is where design-specific instructions go.
- `imagePath` comes from the inbox directory where the glasses' frames are saved.
- The function is called from the patched `deliver()` function in `server.ts`.
- The model is `claude-sonnet-4-20250514` — could be parameterized.

---

## 6. Architecture of the Patched `deliver()` Function in `server.ts`

The deliver function in `server.ts` was modified to call `direct-api.ts` instead of relying on Claude Code channels:

```typescript
async function deliver(
  id: string,
  text: string,
  source: "iphone" | "rayban",
  image?: { path: string; name: string }
): Promise<void> {
  // Also send MCP notification (in case channels become available later)
  void mcp.notification({
    method: "notifications/claude/channel",
    params: {
      content: text || (image ? `(image from ${source})` : "(empty)"),
      meta: {
        chat_id: source,
        message_id: id,
        user: "phone",
        source,
        ts: new Date().toISOString(),
        ...(image ? { file_path: image.path } : {}),
      },
    },
  })
  log(`← ${source}: ${text.slice(0, 60)}${image ? ` [+image: ${image.name}]` : ""}`)
  
  // Direct API call
  try {
    const { callClaude } = await import("./direct-api.ts")
    broadcast({ type: "status", status: "thinking" })
    const reply = await callClaude(text, image?.path)
    const audioUrl = await generateTTS(reply)
    const replyId = nextId()
    broadcast({ type: "reply", id: replyId, text: reply, audio_url: audioUrl })
    logActivity({ ts: new Date().toISOString(), direction: "out", source: "claude", text: reply.slice(0, 100) })
    log(`→ reply: ${reply.slice(0, 80)}${reply.length > 80 ? "..." : ""}`)
  } catch (e) {
    log(`API error: ${e}`)
    broadcast({ type: "reply", id: nextId(), text: `Error: ${e}` })
  }
}
```

---

## 7. How the iOS App Sends Data

When the user speaks through the glasses, the iOS app sends a WebSocket message:

```json
{
  "id": "ios-1776102760.620806",
  "text": "[Mode: General] You are a versatile vision assistant. Describe what you see...\n\nUser: Hello Claude",
  "source": "rayban",
  "image": "<base64 encoded JPEG frame from glasses>"
}
```

**Important observation:** The app prepends the mode's system prompt to the user's text. The `[Mode: General]` block at the beginning is injected by the app, not typed by the user. This means:
- The actual user speech is after "User: " in the text field
- The mode prompt could be customized in the app's Settings → Custom Modes
- For the design workflow, a custom "Design Assistant" mode should be created in the app

---

## 8. What the Memory Layer Needs to Do

### Layer 1: Conversation History (Implement First)

Maintain a rolling buffer of the last N message pairs (user + assistant) in memory. Pass this history to every API call so Claude has conversational context.

**Requirements:**
- Store last 10-20 exchanges (configurable)
- Include image references but not full base64 (to manage token usage) — or include the last 2-3 images
- Automatically summarize/compress older messages when the buffer is full
- Clear when a new design session starts (explicit "new session" command or time-based)

### Layer 2: Session State

Track structured metadata about the current design session:

```
Current object: table lamp
Design direction: cylindrical, two variations
  - Variation A: compact, single light mode
  - Variation B: expandable, dual ambient/focused
Materials discussed: aluminium, glass
Feedback history:
  - "make it more organic"
  - "try a wider base"
  - "the proportions feel too tall"
Key reference images: [paths to captured frames]
```

This state should be injected into the system prompt so Claude always knows what's being worked on without the user repeating it.

### Layer 3: Designer Profile (Future — Connects to LoRA)

Accumulated aesthetic preferences across sessions:
- Preferred formal languages (geometric vs organic, minimal vs complex)
- Material preferences
- Reference designers/movements mentioned
- Recurring design principles

This is the data that eventually becomes training data for the LoRA — the "aesthetic DNA" of the practice. For now, just store it; the LoRA training pipeline will consume it later.

---

## 9. Technical Constraints and Considerations

### Token Management
- Each glasses frame is ~96KB JPEG → ~128KB base64 → approximately 1,700 tokens as an image
- With conversation history including images, token usage adds up fast
- Need a strategy: include full images for last 2-3 frames, text-only summaries for older context
- Max context for Sonnet: 200K tokens — plenty of room, but costs matter

### Latency
- Current response time is acceptable
- Adding conversation history increases payload size slightly but shouldn't noticeably affect latency
- The bottleneck is the API call, not the data prep

### Frame Interval
- Currently set to 3.0 seconds in the app
- Not every frame needs to go to the API — only frames paired with voice input
- The app sends frames continuously; the server currently processes every incoming message
- Consider: only call the API when there's actual voice text, not on every frame

### Rate Limiting
- Server rate limit was raised from 30 to 300 requests/minute
- The app sends heartbeats, status checks, and frames — all count against the limit
- API calls should not be triggered by every WebSocket message, only by messages with text content

### API Error Handling
- 529 (overloaded) errors need retry logic
- Consider: exponential backoff, max 3 retries, fallback model
- Queue voice messages during outages rather than dropping them

---

## 10. Security Audit Summary

A Claude Code security review of the iOS source found no malicious code. Issues found are typical early-stage practices:

**High:** Channel token and ElevenLabs key stored in plaintext UserDefaults (should be Keychain). Token exposed in WebSocket URL query string.

**Medium:** Unencrypted ws:// connection (fine for home network, needs TLS for client deployment). Server-supplied audio URLs not validated.

**Low:** QR/barcode contents logged in plaintext. Loose JSON parsing without schema validation.

**For the proof of concept on a home network, all acceptable.** For client deployment (Month 2-3), address the High and Medium items.

---

## 11. Dependencies and Versions

| Component | Version | Notes |
|-----------|---------|-------|
| macOS | 26.3 | On Mac mini |
| Node.js | v22.22.1 | |
| Bun | 1.3.12 | Runs the channel server |
| Xcode | Latest + iOS 26.4 SDK | For building the iOS app |
| XcodeGen | 2.45.3 | Generates Xcode project from spec |
| Claude Code CLI | v2.1.104 | Installed but channels not available |
| MetaWearablesDAT | 0.5.0 | Meta's DAT SDK for glasses |
| Claude model | claude-sonnet-4-20250514 | In direct-api.ts |
| ElevenLabs model | eleven_flash_v2_5 | Low-latency TTS |

---

## 12. What to Build Next (In Priority Order)

1. **Conversation history in `direct-api.ts`** — Rolling buffer of messages so Claude remembers the session
2. **Design-specific system prompt** — Replace generic vision assistant with design-focused instructions
3. **Session state management** — Structured tracking of current design object, direction, feedback
4. **"Capture" command handling** — Make "take a picture" / "capture this" store a reference frame in session memory
5. **Retry logic for API errors** — Exponential backoff for 529s
6. **Custom mode in iOS app** — Create a "Design Assistant" mode that sends appropriate context
7. **Frame filtering** — Only call API when voice text is present, not on every frame

Items 1-4 form the memory layer. Items 5-7 are reliability and optimization.
