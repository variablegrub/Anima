# Design AI — Memory System Architecture & Project Brief Update

**Date:** April 15, 2026
**Author:** Armando Vargas Garcia Figueroa + Claude
**Project:** AI-Augmented Design Methodology — 3-Month Proof of Concept
**Purpose:** Comprehensive specification for the memory system ("Design Mind"), informed by the VisionClaude setup and memory architecture planning sessions.

---

## 1. Core Concept: The Design Mind

The memory system is not a database or an archive. It is a **design mind** — an active, relational knowledge system that accumulates design intelligence through conversation, connects ideas the designer hasn't explicitly linked, and surfaces relevant knowledge at the right moment.

Unlike a second brain (Notion, Obsidian, Roam) where the designer manually organizes and links, the agent builds connections automatically through every design conversation. The designer curates, the agent cross-references. The designer evaluates, the agent identifies patterns. The designer makes decisions, the agent remembers the reasoning and applies it forward.

The system sits between a tool and a collaborator: it doesn't design, but it carries the accumulated intelligence of every decision across every session and every project. It surfaces unsolicited connections when it recognizes relevance — "the base treatment you're struggling with connects to a folding strategy from a previous project."

---

## 2. Three-Layer Memory Architecture

### Layer 1 — Session Memory (Working Memory)

**Lifespan:** Active in RAM during a design session. Written to disk as structured log on session end.
**Purpose:** Maintain full conversational context so the agent remembers what was discussed seconds or minutes ago.

**Contents:**
- **Conversation history** — Rolling buffer of the last 10-20 message exchanges (configurable). Includes image references for the last 2-3 frames, text-only summaries for older context.
- **Version tree** — Every variation generated or captured, tracked as a branching tree (not a flat list). Versions carry: the image, the prompt used, ComfyUI parameters, seed, ControlNet settings, LoRA weights, curation status (generated → seen → acknowledged → starred → locked → rejected).
- **Feedback chains** — Linked sequences: version 3 → "stretch the neck" → version 4 → "too much, back off" → version 5. Every piece of feedback is stored as a pair: what the designer said → what the agent interpreted → what parameters changed → whether the result was accepted.
- **Exploration sets** — Coordinated batches of variations that differ along defined axes (see Section 4).
- **Captured frames** — Specific images the designer asked to preserve as reference points during the session.
- **Active references** — The 3-5 references currently influencing generation, shifting throughout the session as design direction evolves.

### Layer 2 — Project Memory (Cross-Session Persistence)

**Lifespan:** Created when a project starts, persists across all sessions for that project.
**Purpose:** When a new session starts, the agent loads project memory and has full context from day one.

**Contents:**
- **Locked decisions** — Confirmed design directions: "we're going with aluminium and glass." The agent treats these as constraints unless explicitly reopened.
- **Rejected directions** — Directions explored and killed, with rationale: "tried wood, rejected — felt too warm against the aluminium." If the designer starts re-exploring a rejected direction, the agent flags it: "We explored something similar in session 4 and moved away from it — want to revisit deliberately?"
- **Reference pool** — The 10-20 references actively informing this project, curated from the global archive. Each reference carries decomposed strategies and the designer's original commentary (see Section 3).
- **Evolving design brief** — Materials, functional concept, constraints, dimensions, manufacturing considerations. Updated as decisions lock.
- **Key reference images** — The versions explicitly starred or locked, not every variation. These are the curated outputs that could feed LoRA retraining.
- **Preference counters** — How many times certain choices were made or rejected within this project. Informs generation weighting.

### Layer 3 — Global Archive (Designer Profile, Cross-Project)

**Lifespan:** Grows forever across all projects.
**Purpose:** Accumulated aesthetic intelligence that defines the designer's practice.

**Contents:**
- **Full reference library** — Every reference ever analyzed, with decomposed strategies fully indexed (see Section 3). Searchable by strategy type, material, design principle, or project origin.
- **Language mappings** — What specific terms mean to this designer. "Warmer" might mean amber tones and soft lighting. "Less plastic" might mean matte finishes or more handcrafted irregularity. These mappings are gold — they allow the agent to translate atmospheric direction into concrete parameters.
- **Aesthetic patterns** — Tendencies observed across projects. This designer gravitates toward asymmetry. Rejects anything too polished. Prefers showing joints and connections. Responds to contrast between heavy and light elements. Curves are always large-radius, never tight.
- **Material and form instincts** — Across all projects, keeps returning to aluminium, glass, concrete. Almost never chooses wood. These become soft defaults for new projects.
- **Communication style** — How direct is the feedback? Precise instructions ("rotate 15 degrees") or atmospheric direction ("make it feel more grounded")? Small steps or big jumps? Shapes how the agent presents options.
- **Cross-reference index** — Which strategies relate to which design problems, built through weekly consolidation. Enables the agent to surface connections across projects.

---

## 3. Reference System

References are the core fuel of the design mind. They are not images to copy — they are **decomposed strategies** that can be recombined with any form.

### Three Tiers of References

**Global archive** — Every reference ever analyzed, fully decomposed. Grows across all projects. Searchable by strategy, material, principle, project origin.

**Project reference pool (10-20)** — References actively informing the current project. Curated deliberately from the global archive. The agent consults these when generating variations.

**Active references (3-5)** — The subset currently influencing generation in this session. Shifts as the conversation evolves. The agent uses these to inform immediate parameter choices. Injected into API context for generation calls (keeps token budget tight).

The boundary between archive and project pool is porous upward: if the agent recognizes that a strategy from the archive (not in the project pool) would be relevant, it surfaces a suggestion.

### Three Entry Paths

**Captured (through the glasses)** — The richest entry. Designer shows a reference through VisionClaude, discusses it verbally. The agent captures: the image, the designer's verbal signal (what they pointed to and why), its own analysis and strategy decomposition, applicability tags for the current project. This is what the two lamp reference examples demonstrate.

**Imported (batch with discussion)** — Designer drops a folder of images. The agent presents each one and the designer gives their take: what matters, what to discard, what specific element caught their eye. Same quality of decomposition as a glasses capture, different workflow. Critical: the designer must discuss each reference, not just drop files — the verbal signal is what makes entries valuable.

**Sourced (agent web search)** — Designer asks the agent to find references. Works at different levels of specificity:
- Specific: "Find me that Ingo Maurer lamp with the exposed bulb in the wing"
- Categorical: "Find me lamps that use tension cables as structural elements"
- Cross-domain: "Find me examples of Japanese joinery wood-to-wood connections without fasteners"

The agent searches, filters through the lens of current project context (knows the material palette, active references, what the pool is missing), and presents candidates. The designer discusses and decides which enter the pool. Rejected search results still get logged with reasons — signal for future searches.

### Reference Entry Schema

Each reference entry contains:

```
id: unique identifier
origin: captured | imported | sourced
source_image: path to the image file
source_query: (for sourced) the search query and agent's selection rationale

designer_signal: the designer's own words about what matters
  - raw transcript or text
  - what they pointed to specifically

agent_analysis: Claude's formal decomposition (~130 words, design vocabulary)

strategies: [
  {
    id: strategy unique identifier
    category: material_treatment | structural_approach | light_strategy |
              functional_concept | component_logic | surface_quality |
              proportion_system | joint_detail | fabrication_technique
    description: what the strategy is and how it works
    abstracted_principle: the transferable idea (e.g., "show the joint, don't hide it")
  }
]

curation_status: archive_only | in_project_pool | active
project_associations: [which projects reference this]
relationships: [
  { target_id: ..., type: "similar_strategy" | "contrasts_with" | "same_principle" | ... }
]

metadata:
  date_added: timestamp
  source_designer: (if known) who designed the referenced object
  materials: [materials present in the reference]
  rejected_for: (if rejected from a project pool) reason
```

### Strategy Decomposition Categories

When analyzing a reference, the agent decomposes it into discrete strategies across these categories:

- **Material treatment** — How materials are finished, joined, or left raw (sheared edge honesty, brushed surface, patina)
- **Structural approach** — How the object holds itself up, distributes load, creates rigidity (folded channel base, cantilever, tensioned cable)
- **Light strategy** — How light is created, directed, diffused, or revealed (slit emission, translucent diffusion, ambient glow, directed spot)
- **Functional concept** — What the object does and how (multi-configuration, single gesture, transformable)
- **Component logic** — How parts relate to each other, whether they earn multiple roles (dual-purpose handle, visible cable as decoration)
- **Surface quality** — Texture, finish, reflectivity, tactile character (matte industrial, warm gloss, raw concrete)
- **Proportion system** — Height-to-width relationships, visual weight distribution, monumental vs intimate scale
- **Joint detail** — How parts meet, visible vs hidden connections, transition quality
- **Fabrication technique** — How it's made and how that shows (sheet metal folding, cast form, turned on lathe, 3D printed layers)

---

## 4. Exploration Sets

Exploration is not iteration. Iteration is linear (made this → got feedback → changed it). Exploration maps the design space around a seed form simultaneously.

### Concept

A seed form (e.g., cylindrical lamp, 40cm tall, 8cm radius) is the **origin of a coordinate system.** The agent's job is to show meaningful slices of the space around it so the designer can orient and say "that region, go deeper there."

But variation isn't just parametric (taller/wider). True design exploration applies **different strategies from the reference pool** to the same seed. The agent generates a family of variations where each one applies a different reference strategy: one uses the shadow gap base from reference 1, another applies the multi-configuration principle from reference 2, another borrows the material joint approach from reference 3.

### Three Exploration Modes

**Structured** — The designer defines what to vary: "Show me this form at three heights and two materials." The agent generates the grid.

**Intelligent** — The agent chooses what to vary based on project memory and the active reference pool. Biases exploration toward directions the designer's preferences suggest, avoiding territory likely to be rejected.

**Discovery** — The agent deliberately introduces a dimension the designer hasn't mentioned. Informed by references and the design brief, but intentionally pushing beyond stated parameters. Riskiest mode, most valuable when it works.

### Exploration Set Schema

```
id: unique identifier
seed_version: the version this set explores from
mode: structured | intelligent | discovery
parameters_varied: [
  { axis: "base_treatment", values: ["flared", "folded_channel", "shadow_gap", "weighted_disc"] }
]
references_applied: [
  { reference_id: ..., strategy_id: ..., applied_to: "which aspect of the form" }
]
variations: [version_ids generated in this set]
designer_response: {
  pattern_observed: "drawn to taller proportions regardless of base type"
  selections: [which versions starred/locked]
  rejections: [which versions rejected, with reasons]
}
```

The designer's response across the set is captured as a pattern, not just per-version preferences. "Across this exploration set, all accepted variations had height above 45cm" is a richer signal than "liked version 7a."

---

## 5. Version Tracking

### Version Tree Structure

Versions form a branching tree, not a flat list. Version 5 might spawn two directions: 6a (brass) and 6b (aluminium). The designer can say "combine the base from 6a with the top from 6b."

### Version Types

The schema handles both early-stage sketch captures and full AI-generated variations:

- **sketch_capture** — Image captured through glasses or imported. Carries: the image, designer's verbal description, approximate dimensions, identified strategies.
- **ai_generated** — Produced by ComfyUI. Carries: full parameter state (prompt, seed, ControlNet settings, LoRA weights, model version), which references influenced the generation, which exploration set it belongs to.

### Version Entry Schema

```
id: unique identifier (supports branching: v7a, v7b)
type: sketch_capture | ai_generated
parent_version: what this derived from
branch_label: human-readable name ("folded channel base")

image_path: path to the image file
thumbnail_path: path to thumbnail

# For ai_generated only:
generation_params: {
  prompt: full text prompt used
  negative_prompt: if applicable
  seed: generation seed
  controlnet: { model, strength, preprocessor, source_image }
  lora: { model, weight }
  model: base model used
  steps: inference steps
  cfg_scale: classifier-free guidance scale
  sampler: sampler name
  resolution: width x height
}

curation_status: generated | seen | acknowledged | starred | locked | rejected
designer_feedback: "the proportions feel right but the base is too heavy"
agent_interpretation: "reduce base diameter by 15%, maintain height"

exploration_set_id: if part of an exploration set
relationships: [
  { target_id: ..., type: "derived_from" | "branched_from" | "combined_with" | "rejected_in_favor_of" }
]

# For LoRA training pipeline:
training_eligible: boolean (starred or locked = true)
training_caption: natural language description for Flux LoRA (30-100 words)
rejection_caption: what was wrong (for negative training examples)
```

---

## 6. Cost-Optimized Memory Operations

### Problem with Post-Session Consolidation

The original approach — a full Claude API call after every session to review the session log — is redundant and expensive. Claude was already present for every exchange. Paying it to re-read and re-interpret the same conversation doubles the cost for the same comprehension.

### Solution: Incremental Tagging During Session

Every time the agent processes feedback, generates a variation, or registers a decision, it writes a structured entry **at that moment** — tagged with its type. The cognitive work of understanding "stretch the neck" and translating it to parameters is already happening. The agent just writes that interpretation down as structured data in the same turn.

**During session (zero extra cost):**
The agent tags every exchange as it happens:
- Version created → version entry with full parameters
- Feedback received → feedback-pair entry (designer said → agent interpreted → accepted?)
- Decision locked → decision entry with rationale
- Direction rejected → rejection entry with reason
- Reference discussed → reference entry with strategy decomposition
- Pattern observed → observation entry (candidate, not confirmed)

**After session (local script, near-zero cost):**
A script scans tagged entries and:
- Updates project memory counters (how many times aluminium was chosen, sharp angles rejected)
- Checks which observations recur across 3+ sessions
- Promotes confirmed patterns to project memory
- Flags candidate observations for global memory review
- Merges duplicate strategy nodes that describe the same move

**Weekly (one Claude API call):**
Reviews flagged observations across all sessions that week. Extracts confirmed language mappings and aesthetic patterns. Promotes to global memory. This is the only LLM cost — one call per week on a curated subset.

Future: the weekly review is a strong candidate for the local 7B-13B model once running, further reducing API dependency.

---

## 7. Entry Format & Relationships (Graph-as-Fields)

### Why Not a Graph Database

A formal graph database (Neo4j) adds schema design, traversal algorithms, graph maintenance, and visualization complexity. For Month 1-2 with one project and 30-40 references, the overhead exceeds the benefit.

Claude is already a graph engine — when given well-structured, richly tagged entries, it discovers connections in its reasoning at query time without pre-computed edges.

### Implementation: Structured Entries with Relationship Fields

Every entry (reference, version, decision, observation) shares a base format:

```
{
  id: unique identifier
  type: reference | version | decision | rejection | feedback_pair |
        observation | exploration_set | language_mapping | strategy
  
  project_id: which project (null for global)
  session_id: which session created it
  timestamp: when created
  
  # The graph structure:
  relationships: [
    { target_id: "ref_003", type: "demonstrates" },
    { target_id: "ver_012", type: "derived_from" },
    { target_id: "dec_005", type: "rejected_for" },
    { target_id: "strat_008", type: "applies_principle" }
  ]
  
  # Relationship types:
  # demonstrates — reference demonstrates a strategy
  # applies_to — strategy applies to a version or project
  # derived_from — version derived from another version
  # inspired_by — version or decision inspired by a reference
  # rejected_for — direction rejected, links to rejection entry
  # contradicts — two strategies or decisions in tension
  # evolved_into — earlier version evolved into later one
  # same_principle — two strategies express the same underlying idea
  # combined_with — version combines elements from multiple sources
  
  # Designer-facing summary (for the browsable archive):
  designer_summary: human-readable description of what this entry is
  
  # Agent-facing metadata (for retrieval and reasoning):
  tags: [searchable tags]
  confidence: 0.0-1.0 (for observations not yet confirmed)
  scope: session | project | global
}
```

### Storage

- **Session memory:** JSON files in a session directory. One file per session, containing all entries created during that session.
- **Project memory:** JSON files in a project directory. Consolidated entries that persist across sessions. Loaded on session start.
- **Global archive:** SQLite database. Enables efficient querying across projects: "find all references with light_strategy entries," "show language mappings with confidence > 0.8."

### Migration Path

When the archive grows large enough that Claude can't hold the relevant subset in context (hundreds of references, dozens of projects), the relationship fields migrate into a graph database. The data is already structured for it — relationships are explicit, typed, and bidirectional. The migration is mechanical, not conceptual.

The graph visualization (the node map Armando envisions) can be generated from relationship fields at any point. A frontend component reads entries, follows relationships, and draws the network. This becomes a Phase 5 deliverable visualizing data collected since Week 1.

---

## 8. Two Views: Designer-Facing & Agent-Facing

The same data serves two audiences. Every entry is both a piece of the agent's operational context and a node in the designer's browsable knowledge base.

### Designer-Facing View

Visual, browsable, spatial. The designer opens the archive and sees:
- References organized by strategy type, material, or project
- Version trees as visual branching diagrams with thumbnails
- "Everything about light diffusion strategies" as a grid with commentary
- Their own verbal reactions highlighted alongside the agent's analysis
- The graph of connections between references, strategies, and projects

Use cases: beginning of a project (inspiration), during a crit (process documentation), years later (new project touches similar territory), client presentations.

### Agent-Facing View

Structured, queryable, weighted. The agent needs:
- Tagged entries with confidence scores
- Strategy classifications for retrieval ranking
- Parameter histories for generation
- Rejection logs for avoidance
- Fast cross-reference lookup

### Designer-Only Data

The designer's verbal reactions, sketches, curated pools, version trees with starred selections. Intellectual property and design process documentation.

### Agent-Only Data

Confidence scores on observations, token usage logs, parameter correlation statistics, prompt templates. Debugging and optimization data.

### Shared Data

Decomposed strategies, feedback pairs, language mappings. The agent uses them operationally; the designer can review them as a mirror on their own practice.

---

## 9. Four Learning Mechanisms

### 1. Prompt Template Adjustment (Fast, Within Session)

Not ML. The agent rewrites its own ComfyUI prompts based on stored language mappings. When global memory says "warmer = amber tones + soft lighting" for this designer, prompt construction changes accordingly. Works from Week 1 with just session memory.

### 2. Preference Database (Medium-Term, Across Sessions)

Not ML. Structured querying across the version tree. "Across 40 variations, which were starred? What parameters correlate with acceptance?" SQL queries surface patterns: "variations with rougher textures and warm metals accepted 3x more than polished surfaces." The agent uses this to bias generation parameters.

### 3. LoRA Retraining (Slow, Periodic)

Actual ML. The memory system is the bridge between curation and training.

**Training data source:** The version tree with curation status. Each version carries an image, full parameters, and the designer's feedback at the moment of evaluation. The design conversation *is* the annotation process — no separate labeling step.

**Curation gradient:** Versions have status: generated → seen → acknowledged → starred → locked. Early LoRA runs (Month 1-2) train on starred + locked because volume is low. Later runs can be more selective.

**Negative examples:** Explicitly rejected variations with their parameters and rejection reasons are training signal. Captioned with what was wrong, at lower/negative weight in Flux LoRA training.

**Trigger:** After 20-30 curated outputs accumulate (not after every session). Maybe every few weeks.

### 4. Archive Knowledge (Ongoing, Cross-Project)

Longest-horizon. As the agent processes more projects, it builds understanding of the practice's design language — relationships between project types, client types, and aesthetic choices. The cross-reference index built during weekly consolidation enables this.

For scaling to multiple practices: if every entry is tagged with project type, design domain, and practice ID from the start, cross-practice analysis becomes possible without data migration.

---

## 10. VisionClaude Integration

### Current State

VisionClaude is operational with a patched Channel server calling the Anthropic API directly (see VisionClaude Setup Brief for full details). The `direct-api.ts` file handles Claude API calls but is currently stateless — every message is a standalone call with no conversation history.

### Integration Architecture

The Managed Agent replaces the direct API call. VisionClaude's server routes voice + vision input to the Managed Agent instead of calling the Anthropic API raw. The agent maintains conversation history, accesses memory files, and tags entries — all within the same interaction.

When the designer says "version 6 was better, go back to that direction" through the glasses, the voice pipeline hits the same memory store as the web interface. One agent, one memory system, multiple input paths.

### Design-Specific System Prompt

Replace the current generic vision assistant prompt:

```
Current (in direct-api.ts):
"You are a vision assistant seeing through smart glasses. Be concise (1-3 sentences).
Describe what you see with specificity. Read all visible text exactly."

Replace with:
"You are a design assistant for an architect/industrial designer. When shown sketches
or objects, analyze formal qualities: proportions, geometry, topology, material
implications, and design intent. Use precise design vocabulary. Don't describe the
scene — focus on the design object. Be concise (1-3 sentences) unless asked for
detail. When given design feedback, acknowledge the intent and suggest how it might
manifest formally. You have access to the current design session context, project
memory, and reference library."
```

### Frame Filtering

Not every glasses frame should trigger an API call. Only frames paired with voice input go to the agent. The server filters: if the WebSocket message contains text content, process it; if it's just a heartbeat or status frame, skip.

### "Capture" Command

"Take a picture" / "capture this" should: analyze the current frame in detail, tag it as a reference capture or version capture depending on context, store it in session memory with the designer's verbal signal, and confirm what was captured.

---

## 11. Phased Build Plan

### Phase 1 — Voice Has Memory (Week 1)

**Deliverable:** Wear the glasses, have a 10-minute conversation about a sketch, Claude remembers the whole session.

- Set up Claude Managed Agent with conversation history buffer
- Replace raw API call in `direct-api.ts` with agent that maintains rolling context
- Implement design-specific system prompt
- Basic structured logging: every exchange tagged with type at the moment it happens
- Add retry logic with exponential backoff for 529 errors
- Frame filtering: only call API when voice text is present

**No references, no version tracking, no exploration.** Just: Claude remembers what you said 30 seconds ago and speaks in design language.

### Phase 2 — References Through the Glasses (Week 2-3)

**Deliverable:** Show a lamp reference, discuss it, agent decomposes strategies and stores a reference entry.

- Define and implement entry schemas: reference, version, feedback-pair, strategy
- Reference entry creation from glasses discussions (captured path)
- Strategy decomposition with designer's verbal signal preserved
- Basic version tracking for sketches (not AI generations yet)
- Session memory writes tagged entries to disk on session end
- Project directory structure: JSON files organized by project
- "Add to project pool" command for moving references from archive to active pool

### Phase 3 — Project Memory Across Sessions (Week 4)

**Deliverable:** Come back the next morning, agent knows full project context.

- Project memory loads at session start
- Session memory writes back to project memory on session end
- Lightweight local consolidation script: count preference recurrences, update decision status, flag candidate patterns
- Active reference set management: agent tracks and shifts active references during session
- Rejection log with "revisit deliberately?" flag when re-approaching killed directions
- Locked decision tracking: agent treats locked decisions as constraints

### Phase 4 — Generation Loop with Full Tracking (Month 2)

**Deliverable:** ComfyUI connected, full version tree with parameter state, exploration sets.

- ComfyUI integration via comfyui-mcp
- Full version entry schema: prompt, seed, ControlNet, LoRA weights, model
- Branching version tree with curation controls (star, lock, reject)
- Exploration sets: structured mode first, then intelligent and discovery
- Batch import with discussion flow
- Agent-sourced web search for references
- Reference strategies applied to generation: "apply shadow gap base from reference 1"
- Web UI for uploading sketches, displaying variations, curating outputs

### Phase 5 — Global Memory, LoRA Pipeline, Design Mind (Month 3)

**Deliverable:** Designer profile forming, LoRA training data pipeline, browsable archive.

- Weekly consolidation: one Claude API call reviewing flagged observations, extracting language mappings
- Global archive in SQLite: queryable across projects
- Language mapping confirmed through repetition across sessions
- LoRA training data export: starred/locked versions with captions, rejected versions as negatives
- Designer-facing archive: browsable grid by strategy, visual version trees, commentary highlighted
- Graph visualization of the relationship network
- Client presentation export from curated project data

---

## 12. Updated Technical Constraints

### Token Management for VisionClaude

- Each glasses frame: ~96KB JPEG → ~128KB base64 → ~1,700 tokens as image
- Strategy: full images for last 2-3 frames, text-only summaries for older context
- Active references (3-5) injected as text descriptions, not images, to save tokens
- Max context for Sonnet: 200K tokens — room available, but costs scale with history length

### Storage

- Session memory: JSON files, one per session (~50-200KB depending on length)
- Project memory: JSON files per project directory (~500KB-2MB over project lifetime)
- Global archive: SQLite database (scales to thousands of entries efficiently)
- Images stored as files, referenced by path in entries (not embedded in JSON)

### Local-First Principle

All memory data stays on the designer's hardware. No cloud sync, no third-party platforms. The global archive and all project data live on the Mac mini (and eventually on client machines in deployment). This preserves the core data ownership promise.

### Cost Structure

- **During session:** Zero additional API cost. Tagging happens within existing agent turns.
- **After session:** Local script, near-zero cost.
- **Weekly:** One Claude API call for language mapping extraction. Estimated: ~$0.50-2.00/week depending on volume.
- **Future:** Weekly consolidation migrates to local 7B-13B model for zero API cost.

---

## 13. Updated Architecture Summary

```
Input Sources
├── VisionClaude (glasses + voice) — richest path, real-time verbal signal
├── Batch Import (images + discussion) — efficient for project startup
└── Agent Web Search — designer requests, agent sources and filters

↓

Claude Managed Agent
├── Processes all input
├── Tags every exchange in real-time (zero extra cost)
├── Reads/writes memory files directly (no API layer needed)
└── Maintains conversation context

↓

Memory Storage (local filesystem + SQLite)
├── Session Memory (RAM → JSON on disk)
│   ├── Conversation buffer
│   ├── Version tree (branching, with curation status)
│   ├── Feedback chains
│   ├── Exploration sets
│   └── Captured frames
│
├── Project Memory (JSON files per project)
│   ├── Reference pool (10-20 curated from archive)
│   ├── Active references (3-5 currently in play)
│   ├── Locked decisions
│   ├── Rejected directions
│   └── Evolving brief
│
└── Global Archive (SQLite)
    ├── All references + decomposed strategies
    ├── Language mappings
    ├── Aesthetic patterns
    ├── Material instincts
    └── Cross-reference index

↓

Outputs
├── ComfyUI Generation (informed by active references + project context)
│   └── LoRA Training Data (curated versions as labeled dataset)
│
└── Designer Archive / Design Mind (browsable knowledge base)
    ├── References by strategy type
    ├── Visual version trees
    ├── Graph visualization of connections
    └── Client presentation exports
```

### Consolidation Flow

```
During Session → Agent tags entries in real-time
                 (version, feedback-pair, decision, rejection, observation)

After Session  → Local script scans tagged entries
                 - Updates project memory counters
                 - Flags recurring observations
                 - Promotes confirmed decisions
                 - Merges duplicate strategy nodes

Weekly         → One Claude API call
                 - Reviews flagged observations across sessions
                 - Extracts confirmed language mappings
                 - Promotes patterns to global archive
                 - Builds cross-reference index
```

---

## 14. Key Principles

1. **The design conversation is the annotation process.** No separate labeling step. Every starred version, every rejection, every verbal reaction is training data for LoRA and intelligence for the memory system.

2. **Incremental tagging, not post-hoc review.** The agent writes structured entries at the moment of understanding, not by re-reading session logs after the fact.

3. **Think in graphs, store in structured entries.** Relationships as fields on entries, not in a graph database. Migrate when scale demands it.

4. **References are decomposed strategies, not images to copy.** A folding technique is a *move* that applies across forms. The reference pool is a library of applicable strategies.

5. **Two views, same data.** The designer sees a browsable design mind. The agent sees queryable structured entries. Both draw from the same storage.

6. **Local-first, always.** All data on the designer's hardware. The data ownership promise is the moat.

7. **The designer curates, the agent connects.** The system doesn't design. It carries intelligence forward and surfaces connections the designer hasn't explicitly made.
