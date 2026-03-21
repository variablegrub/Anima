```
         ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
        ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
        ██║     ██║     ███████║██║   ██║██║  ██║█████╗
        ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
        ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
         ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝

        ██╗   ██╗██╗███████╗██╗ ██████╗ ███╗   ██╗
        ██║   ██║██║██╔════╝██║██╔═══██╗████╗  ██║
        ██║   ██║██║███████╗██║██║   ██║██╔██╗ ██║
        ╚██╗ ██╔╝██║╚════██║██║██║   ██║██║╚██╗██║
         ╚████╔╝ ██║███████║██║╚██████╔╝██║ ╚████║
          ╚═══╝  ╚═╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝

        Let Claude see the world through your eyes
```

**ClaudeVision** turns your iPhone (or Meta Ray-Ban glasses) into Claude's eyes and ears. Point your camera, speak naturally, and Claude sees what you see — then responds with voice, using your connected tools like email, calendar, and more.

## How It Works

```
Phone Camera  →  Gateway Server  →  Claude API
Your Voice    →    (your Mac)    →  MCP Tools
Claude Reply  ←                  ←  (email, etc.)
```

1. **You speak** — on-device speech recognition transcribes your voice
2. **Camera captures** — latest frame grabbed as JPEG (~1fps)
3. **Gateway sends** — text + image to Claude via the Anthropic API
4. **Claude responds** — with vision understanding + tool actions
5. **You hear** — text-to-speech reads Claude's response aloud
6. **Loop repeats** — continuous conversation, hands-free

## Quick Start

```bash
git clone https://github.com/mrdulasolutions/visionclaude.git
cd visionclaude
./setup.sh
```

The interactive setup will walk you through everything:
- Check and install dependencies
- Configure your Anthropic API key
- Build the gateway server
- Generate the iOS Xcode project

## Requirements

| Requirement | Version |
|---|---|
| macOS | 13+ |
| Node.js | 18+ |
| Xcode | 15+ (for iOS app) |
| iPhone | iOS 17+ |
| Anthropic API Key | [Get one here](https://console.anthropic.com/settings/keys) |

## Architecture

### Gateway Server (Node.js)

Runs on your Mac. Bridges the iOS app to Claude's API and routes tool calls through MCP servers.

```
server/
├── src/
│   ├── index.ts              # Express entry point (port 18790)
│   ├── claude-client.ts      # Claude Messages API + vision + tool loop
│   ├── mcp-manager.ts        # MCP server lifecycle & tool discovery
│   ├── conversation.ts       # In-memory conversation store
│   └── routes/
│       ├── chat.ts           # POST /chat — main endpoint
│       ├── health.ts         # GET /health — status check
│       ├── tools.ts          # GET /tools — list MCP tools
│       └── config.ts         # GET/POST /config — runtime config
```

**Key feature:** Auto-discovers MCP tools from your Claude Desktop config. Any MCP server you add to Claude Desktop automatically becomes available through the gateway.

### iOS App (Swift/SwiftUI)

Runs on your iPhone. Captures camera + voice, sends to gateway, speaks responses.

```
ios/ClaudeVision/
├── Models/
│   ├── ClaudeConfig.swift        # Gateway connection settings
│   └── ChatModels.swift          # API request/response types
├── Services/
│   ├── ClaudeBridge.swift        # HTTP client → gateway
│   ├── SpeechManager.swift       # STT (Apple Speech) + TTS
│   ├── CameraManager.swift       # AVCaptureSession frame capture
│   ├── FrameSource.swift         # Protocol for camera/Ray-Ban
│   └── AudioSessionManager.swift # Audio session handling
├── ViewModels/
│   └── SessionViewModel.swift    # Pipeline orchestrator
└── Views/
    ├── ContentView.swift         # Camera preview + mic button
    ├── TranscriptView.swift      # Conversation history
    └── SettingsView.swift        # Gateway config UI
```

## API Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Server status + connected MCP tool count |
| `/tools` | GET | List all discovered MCP tools |
| `/chat` | POST | Send text + images, get Claude's response |
| `/config` | GET/POST | View or update system prompt, model |

### Chat Request

```json
{
  "text": "What do you see?",
  "images": ["<base64 JPEG>"],
  "conversation_id": "optional-session-id"
}
```

### Chat Response

```json
{
  "text": "I can see a laptop on a desk with...",
  "tool_calls": [{"name": "read_emails", "result": {...}}],
  "conversation_id": "generated-session-id"
}
```

## Manual Setup

If you prefer not to use the setup script:

### Gateway Server

```bash
cd server
cp .env.example .env
# Edit .env and add your ANTHROPIC_API_KEY
npm install
npm run build
npm start
```

### iOS App

```bash
brew install xcodegen
cd ios
xcodegen generate
open ClaudeVision.xcodeproj
# Set your Development Team in Signing & Capabilities
# Connect your iPhone via USB (Simulators won't work — no camera/mic)
# Select your iPhone in the device dropdown (top toolbar, next to ▶)
# Press ⌘R to build and run
# If "Untrusted Developer": iPhone Settings → General → VPN & Device Management → Trust
```

## Meta Ray-Ban Glasses

ClaudeVision supports Meta Ray-Ban Smart Glasses as an alternative camera source. Instead of your iPhone camera, Claude sees through your glasses — fully hands-free.

### Setup

1. Install the **Meta View** app on your iPhone
2. Pair your glasses via Bluetooth
3. Enable **Developer Mode**: Meta View → Settings → your glasses → Developer Mode → ON
4. Restart your glasses (hold button 15s to power off, press to power on)
5. In ClaudeVision, tap the **eyeglasses icon** or go to Settings → Camera Source → Meta Ray-Ban

### Developer Access

The DAT SDK is included automatically via Swift Package Manager from [github.com/facebook/meta-wearables-dat-ios](https://github.com/facebook/meta-wearables-dat-ios). No manual SDK download needed — Xcode resolves it when you open the project.

The app includes a built-in setup guide (Settings → Meta Ray-Ban → Setup Instructions) that walks users through the pairing and developer mode process.

### Meta Wearables Developer Terms

By using the Wearables Device Access Toolkit, you agree to the [Meta Wearables Developer Terms](https://wearables.developer.meta.com/terms), including the [Acceptable Use Policy](https://wearables.developer.meta.com/acceptable-use-policy).

By enabling Meta integrations, including through this SDK, Meta may collect information about how users' Meta devices communicate with your app. Meta will use this information in accordance with their [Privacy Policy](https://www.meta.com/legal/privacy-policy/). ClaudeVision opts out of analytics by default via `Info.plist` (`MWDAT → Analytics → OptOut = YES`).

## MCP Tools

ClaudeVision automatically discovers tools from your Claude Desktop configuration at:

```
~/Library/Application Support/Claude/claude_desktop_config.json
```

Any MCP server configured there will be available through voice commands. For example:
- "Check my email" → uses email MCP tools
- "What's on my calendar?" → uses calendar MCP tools
- "Send a message to..." → uses messaging MCP tools

## License

MIT

## Disclaimer

This project is not affiliated with, endorsed by, or officially connected to Anthropic, PBC or Meta Platforms, Inc. Claude is a trademark of Anthropic. Meta, Ray-Ban, and the Meta Wearables Device Access Toolkit are trademarks of Meta Platforms, Inc.

---

Built by [@mrdulasolutions](https://github.com/mrdulasolutions)
