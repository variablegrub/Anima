// Direct Anthropic API call - bypasses Claude Code channel
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY ?? ''

const MAX_HISTORY = 15
const FULL_IMAGE_EXCHANGES = 3

type MessageContent = { type: string; [key: string]: any }[]
type Exchange = { user: MessageContent; assistant: string }

const history: Exchange[] = []
let sessionSummary = ''

export function clearHistory(): void {
  history.length = 0
  sessionSummary = ''
}

function stripModePrefix(text: string): string {
  const marker = text.indexOf('\n\nUser: ')
  if (marker !== -1) return text.slice(marker + 8)
  return text
}

function buildMessages(newUserContent: MessageContent): any[] {
  const messages: any[] = []
  const total = history.length

  for (let i = 0; i < total; i++) {
    const exchange = history[i]
    const age = total - 1 - i  // 0 = most recent exchange

    let userContent: MessageContent
    if (age < FULL_IMAGE_EXCHANGES) {
      userContent = exchange.user
    } else {
      const hadImage = exchange.user.some((c) => c.type === 'image')
      userContent = exchange.user.filter((c) => c.type !== 'image')
      if (hadImage) {
        userContent = [{ type: 'text', text: '[image: sketch shown via glasses]' }, ...userContent]
      }
    }

    messages.push({ role: 'user', content: userContent })
    messages.push({ role: 'assistant', content: exchange.assistant })
  }

  messages.push({ role: 'user', content: newUserContent })
  return messages
}

function updateSessionSummary(assistantReply: string): void {
  const firstSentence = assistantReply.split(/[.!?]/)[0].trim()
  const entry = `[${history.length}] ${firstSentence}`
  const lines = sessionSummary ? sessionSummary.split('\n') : []
  lines.push(entry)
  sessionSummary = lines.slice(-3).join('\n')  // keep last 3 lines
}

export async function callClaude(text: string, imagePath?: string): Promise<string> {
  if (!ANTHROPIC_API_KEY) return 'Error: No ANTHROPIC_API_KEY set. Export it or add to .env'

  const userText = stripModePrefix(text)
  const content: MessageContent = []

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

  content.push({ type: 'text', text: userText || 'What do you see?' })

  const messages = buildMessages(content)

  const systemContext = sessionSummary ? `\n\nSession context so far:\n${sessionSummary}` : ''
  const system = "You are a design collaborator for an architect and industrial designer, communicating through smart glasses with voice. You see what the designer sees through the camera.\nWhen shown sketches or objects: analyze formal qualities — proportions, geometry, topology, material implications, design intent. Use precise design vocabulary. Focus on the design object, not the scene around it.\nWhen the designer gives feedback like 'make it more organic' or 'wider base': acknowledge the direction and suggest how it might manifest formally — specific geometric or material changes, not vague agreement.\nWhen asked to 'capture this' or 'take a picture': analyze the current frame in detail and confirm what you see. You always have the current camera frame available.\nKeep responses to 1-3 sentences — they will be spoken aloud. Be direct, specific, and opinionated. You are allowed to push back or suggest alternatives." + systemContext

  const requestBody = JSON.stringify({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    system,
    messages,
  })

  let resp: Response | null = null
  for (let attempt = 0; attempt <= 3; attempt++) {
    if (attempt > 0) {
      const delay = 1000 * Math.pow(2, attempt - 1)  // 1s, 2s, 4s
      console.log(`[claude] retry ${attempt}/3 after ${delay}ms (status ${resp?.status})`)
      await new Promise((resolve) => setTimeout(resolve, delay))
    }
    resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: requestBody,
    })
    if (resp.ok || (resp.status >= 400 && resp.status < 500)) break
  }

  if (!resp!.ok) {
    const err = await resp!.text()
    return `API error ${resp!.status}: ${err.slice(0, 200)}`
  }

  const data = await resp.json() as any
  const reply = data.content?.map((c: any) => c.text || '').join('') || 'No response'

  history.push({ user: content, assistant: reply })
  if (history.length > MAX_HISTORY) history.shift()
  updateSessionSummary(reply)

  return reply
}
