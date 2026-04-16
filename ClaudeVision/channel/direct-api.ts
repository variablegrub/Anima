// Direct Anthropic API call - bypasses Claude Code channel
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY ?? ''

export async function callClaude(text: string, imagePath?: string): Promise<string> {
  if (!ANTHROPIC_API_KEY) return 'Error: No ANTHROPIC_API_KEY set. Export it or add to .env'
  
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
      system: "You are a design collaborator for an architect and industrial designer, communicating through smart glasses with voice. You see what the designer sees through the camera.\nWhen shown sketches or objects: analyze formal qualities — proportions, geometry, topology, material implications, design intent. Use precise design vocabulary. Focus on the design object, not the scene around it.\nWhen the designer gives feedback like 'make it more organic' or 'wider base': acknowledge the direction and suggest how it might manifest formally — specific geometric or material changes, not vague agreement.\nWhen asked to 'capture this' or 'take a picture': analyze the current frame in detail and confirm what you see. You always have the current camera frame available.\nKeep responses to 1-3 sentences — they will be spoken aloud. Be direct, specific, and opinionated. You are allowed to push back or suggest alternatives.",
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
