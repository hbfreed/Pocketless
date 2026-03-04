# Pocketless

**You don't need a $200 puck. An open-source iOS app for recording, transcribing, and summarizing conversations. No hardware. No subscription. BYOK (Bring Your Own Keys).**

---

## Why This Exists

Hardware products like Plaud and Pocket sell $100-200 recording pucks with $20/month subscriptions to do something your phone can already do: record audio, transcribe it, and summarize it with an LLM. The "hardware" is a Bluetooth mic that syncs to a phone app where all the actual processing happens.

Pocketless is the app without the puck. Record with your phone's mic, transcribe on-device or via your own API keys, and summarize with whatever LLM you want. Free forever, MIT licensed.

---

## Core Flow

```
[Record] → [Transcribe] → [LLM Cleanup] → [Clean Transcript] → [Summarize] → [Export]
   │             │               │                                    │
   │        On-device        DSPy-optimized                    User's LLM
   │     (WhisperKit)        prompt via                     (via OpenRouter
   │         or              user's LLM                     or any OpenAI-
   │     Cloud STT API       endpoint                     compatible endpoint)
   │
   Phone mic or
   Bluetooth mic
```

### 1. Record
- Tap to start/stop recording (single button)
- Background audio capture via `AVAudioEngine`
- Visual feedback: waveform + elapsed time + file size
- Recordings persist in app sandbox
- Support for external Bluetooth microphones (AirPods, lapel mics, etc.)
- Background recording support (app can be backgrounded)

### 2. Transcribe
- Triggered automatically when recording stops
- Default: on-device via **WhisperKit** (large-v3-turbo model)
  - No API key needed, no network needed, fully private
  - CoreML acceleration on Apple Silicon (ANE)
  - ~3x realtime speed on modern iPhones
- Optional: cloud STT via user's own API key
  - Any OpenAI-compatible STT endpoint (OpenAI Whisper API, Deepgram, etc.)
  - Configurable base URL + API key

### 3. Cleanup (DSPy-optimized)
- Raw transcript is passed through an LLM cleanup prompt
- Removes filler words (um, uh, like, you know), false starts, repeated phrases
- Fixes punctuation and sentence boundaries
- Preserves all substantive content — cleaning, not editing
- Uses the same LLM endpoint configured for summaries (OpenRouter default)
- Can be disabled in settings (raw Whisper output is always kept)
- See **Transcript Cleanup Pipeline** section below for details

### 4. Clean Transcript
- Both raw and cleaned transcripts are saved
- User can tap to edit/correct the clean transcript
- Transcript is the source of truth — summary is always regenerable from it

### 5. Summarize
- User taps "Summarize" (or auto-summarize can be toggled on)
- Transcript is sent to user's configured LLM endpoint
- Default target: **OpenRouter** (`https://openrouter.ai/api/v1`)
  - Single API key, access to Claude / GPT-4o / Gemini / Llama / DeepSeek / etc.
  - User picks their preferred model from a list
- Also supports any OpenAI-compatible endpoint:
  - OpenAI direct (`https://api.openai.com/v1`)
  - Anthropic via OpenRouter
  - Local Ollama (`http://localhost:11434/v1`)
  - Any custom endpoint
- User selects a **summary preset** (see below)
- Summary is saved alongside the transcript

### 6. Export
- Share sheet: copy text, send to Notes/Files/email/etc.
- Export formats: plain text, markdown, JSON (structured)
- Future: integrations (Notion, Obsidian, etc. — PRs welcome)

---

## Summary Presets

Summary presets are just system prompts with different vibes. No heavy engineering — users who care about specific output formats will write their own prompt and do it better than we can guess, because they know their own context.

### Built-in Presets

| Preset | Vibe |
|--------|------|
| **Quick** | 3-5 bullet points, just the highlights |
| **Detailed** | Thorough structured notes — decisions, action items, key discussion points |
| **Casual** | Conversational recap, like telling a friend what happened |
| **Pedantic** | Exhaustive, nothing omitted, timestamped references back to transcript |
| **Custom** | Blank text box — write your own system prompt |

### Custom Prompts
- Users can write their own system prompt in a simple text editor
- Save multiple custom prompts with names
- Import/export prompts as JSON for sharing

### Prompt Structure

Each preset follows a consistent wrapper:

```
{{ preset.system_prompt }}

Rules:
- Use only information present in the transcript. Do not infer or fabricate.
- If speaker labels are available, attribute statements to speakers.
- Flag anything that seems ambiguous or unclear in the transcript.
- Use the user's language (match the transcript language).

Transcript:
---
{{ transcript }}
---
```

---

## Transcript Cleanup Pipeline (DSPy-optimized)

The single most impactful piece of engineering in this project. Raw Whisper output is messy — filler words (um, uh, like), false starts, repeated phrases, run-on sentences without punctuation. Most competing apps just dump this raw output. We do better.

### Architecture

```
Raw Whisper Output → [LLM Cleanup Pass] → Clean Transcript
                          │
                    Optimized prompt
                    (tuned via DSPy)
```

A post-processing LLM pass sits between raw Whisper output and the saved transcript. The LLM receives the messy transcript and returns a cleaned version with filler words removed, punctuation corrected, false starts smoothed, and formatting improved — without changing the meaning or removing substantive content.

### Training Data

Podcast transcripts where both raw audio and professionally cleaned transcripts are publicly available:

| Source | Why it's good |
|--------|---------------|
| **Dwarkesh Patel** | High-quality cleaned transcripts, removes ums/uhhs, technically dense content |
| **Lex Fridman** | Long-form, multiple speaking styles, published transcripts |
| **Ezra Klein** | Conversational, policy-heavy, NYT-quality transcripts |
| **80,000 Hours** | Technical/academic speakers, thorough transcripts |

**Pipeline to generate training pairs:**
1. Download raw audio from podcast RSS feeds
2. Run WhisperKit / Whisper large-v3-turbo on raw audio → raw transcript
3. Download published cleaned transcript → ground truth
4. Align raw and clean transcripts at segment level (fuzzy matching on timestamps)
5. Each aligned pair = one training example

### DSPy Optimization

```python
class TranscriptCleanup(dspy.Signature):
    """Clean up a raw speech-to-text transcript. Remove filler words
    (um, uh, like, you know), false starts, and repeated phrases.
    Fix punctuation and sentence boundaries. Preserve all substantive
    content and speaker meaning exactly. Do not paraphrase or
    editorialize."""

    raw_transcript: str = dspy.InputField()
    cleaned_transcript: str = dspy.OutputField()
```

**Metric**: Character-level or word-level edit distance against ground truth clean transcripts. Could also use ROUGE-L or a composite metric that penalizes:
- Remaining filler words (precision)
- Removed substantive content (recall)
- Changed meaning (semantic similarity score)

**Optimization target**: The system prompt / few-shot examples that minimize edit distance between LLM-cleaned output and human-cleaned ground truth.

### Chunking Strategy

Long recordings need to be chunked for the cleanup pass (context window limits). Strategy:
- Chunk at natural boundaries (sentence endings, speaker changes, pauses)
- Overlap chunks by ~2 sentences for continuity
- Merge cleaned chunks, dedup overlap regions

### Offline / Cost Considerations

The cleanup pass requires an LLM call, which means either:
- **Cloud (default)**: Uses the same OpenRouter/LLM endpoint as summaries. Small cost per transcript.
- **Local**: If user has Ollama or similar running, point at localhost. Free but slower.
- **Skip**: User can disable cleanup and keep raw Whisper output (always an option).

The cleanup prompt is optimized once (by us, during development) and shipped as a static asset. Users don't need DSPy — they just get the optimized prompt.

---

### Platform
- **iOS 17+** (Swift / SwiftUI)
- Xcode 15+

### Key Dependencies
| Component | Library | Notes |
|-----------|---------|-------|
| Audio capture | `AVAudioEngine` (system) | Background mode, external mic support |
| On-device STT | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | CoreML-optimized Whisper for Apple Silicon |
| LLM API | URLSession + OpenAI-compatible client | Single implementation covers all providers |
| Local storage | SwiftData | Recordings, transcripts, summaries, settings |
| API keys | Keychain | Secure storage for user credentials |

### Data Model

```
Recording
├── id: UUID
├── createdAt: Date
├── duration: TimeInterval
├── audioFileURL: URL (local)
├── rawTranscript: Transcript?      # Direct Whisper output
├── cleanTranscript: Transcript?    # After LLM cleanup pass
└── summaries: [Summary]

Transcript
├── id: UUID
├── createdAt: Date
├── source: enum (onDevice, cloud)
├── modelUsed: String
├── isCleanedUp: Bool
├── segments: [TranscriptSegment]
│   ├── startTime: TimeInterval
│   ├── endTime: TimeInterval
│   ├── text: String
│   └── speaker: String?
└── fullText: String (computed)

Summary
├── id: UUID
├── createdAt: Date
├── presetUsed: String              # "quick", "detailed", "casual", "pedantic", "custom"
├── customPrompt: String?           # Only if preset == "custom"
├── modelUsed: String
├── content: String
└── isAutoGenerated: Bool

STTConfig
├── provider: enum (onDevice, openaiCompatible)
├── baseURL: String?
├── apiKey: String? (Keychain ref)
└── modelName: String?

LLMConfig
├── baseURL: String (default: "https://openrouter.ai/api/v1")
├── apiKey: String (Keychain ref)
├── modelName: String (default: "anthropic/claude-sonnet-4-20250514")
└── maxTokens: Int (default: 4096)
```

### App Structure

```
Pocketless/
├── App/
│   ├── PocketlessApp.swift
│   └── ContentView.swift
├── Features/
│   ├── Recording/
│   │   ├── RecordingView.swift        # Main record button + waveform
│   │   ├── AudioRecorder.swift        # AVAudioEngine wrapper
│   │   └── WaveformView.swift         # Real-time audio visualization
│   ├── Library/
│   │   ├── LibraryView.swift          # List of all recordings
│   │   └── RecordingDetailView.swift  # Transcript + summaries for one recording
│   ├── Transcription/
│   │   ├── TranscriptionService.swift # Protocol + implementations
│   │   ├── WhisperKitService.swift    # On-device transcription
│   │   └── CloudSTTService.swift      # OpenAI-compatible API client
│   ├── Cleanup/
│   │   ├── TranscriptCleanup.swift    # LLM-based transcript cleanup
│   │   └── CleanupPrompt.swift        # DSPy-optimized prompt (shipped as static asset)
│   ├── Summarization/
│   │   ├── SummarizationService.swift # OpenAI-compatible LLM client
│   │   └── SummaryPresets.swift       # Quick / Detailed / Casual / Pedantic / Custom
│   └── Settings/
│       ├── SettingsView.swift
│       ├── STTConfigView.swift        # STT provider setup
│       └── LLMConfigView.swift        # LLM provider setup (OpenRouter default)
├── Models/
│   ├── Recording.swift
│   ├── Transcript.swift
│   └── Summary.swift
├── Services/
│   ├── KeychainService.swift
│   └── OpenAICompatibleClient.swift   # One client to rule them all
└── Resources/
    └── SummaryPresets.json
```

### Network Layer

The entire LLM and cloud STT integration is one generic client:

```swift
/// Single client that works with OpenRouter, OpenAI, Ollama, or any
/// OpenAI-compatible API. The only things that change are baseURL,
/// apiKey, and model name.
struct OpenAICompatibleClient {
    let baseURL: URL
    let apiKey: String

    func chatCompletion(
        model: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 4096
    ) async throws -> String

    func transcribe(
        model: String,
        audioData: Data,
        language: String? = nil
    ) async throws -> TranscriptionResponse
}
```

---

## Settings / Configuration

### First Launch
1. "Record your first conversation" — no setup required for basic recording + on-device transcription
2. To enable summaries: "Add your OpenRouter API key" with link to openrouter.ai/keys
3. Optional: configure cloud STT if desired

### Settings Screen
- **STT Provider**: On-device (default) / Custom endpoint
  - If custom: base URL, API key, model name
- **LLM Provider**: OpenRouter (default) / Custom endpoint
  - Base URL (pre-filled with OpenRouter)
  - API key
  - Model picker (fetched from OpenRouter's model list, or manual entry)
- **Transcript cleanup**: On (default) / Off (skip LLM cleanup, keep raw Whisper output)
- **Auto-summarize**: Off (default) / On (auto-summarize after every transcription)
- **Default summary preset**: Quick (default) / user's choice
- **Audio quality**: Standard (AAC 128kbps) / High (WAV lossless)
- **Storage**: show usage, clear old recordings

---

## Non-Goals (v1)

- ❌ Real-time transcription during recording (battery hog, adds complexity, not needed)
- ❌ Real-time summarization (summaries are inherently retrospective)
- ❌ Speaker diarization (WhisperKit doesn't support it well yet; add later)
- ❌ Cloud sync / account system (local-first, no backend)
- ❌ Any form of subscription or payment
- ❌ Custom hardware accessory

---

## Future Ideas (v2+)

- Speaker diarization (when on-device models improve)
- Watch app (tap to record from Apple Watch)
- Shortcuts / Siri integration ("Hey Siri, start recording with Pocketless")
- Widget for quick-record from home screen
- Obsidian / Notion / Apple Notes integration
- Transcript search across all recordings
- Folder / tag organization
- Multiple summary re-generation with different templates
- Community template library

---

## App Store Publishing

- **Apple Developer Program**: $99/year — required to publish on the App Store
- **Review process**: Submit via Xcode → Apple reviews in 1-3 days → live
- **Privacy nutrition labels**: Will need to declare microphone access + optional network usage (for API calls). No tracking, no data collection by us — strong privacy story.
- **App Review gotchas to watch for**:
  - Must include a clear microphone usage description
  - Recording apps may get extra scrutiny — emphasize user-initiated recording only
  - BYOK model means we don't need to worry about content moderation on our side (the LLM providers handle it)
  - Must have a functional app without API keys (on-device transcription makes this easy)

---

## Development Notes

### What to build (Claude Code scope)
- Audio recording infrastructure (AVAudioEngine, background recording, waveform visualization)
- WhisperKit integration for on-device transcription
- OpenAI-compatible API client (one client for both STT and LLM endpoints)
- SwiftData models and persistence layer
- Settings UI (STT config, LLM config, API key entry with Keychain storage)
- Library view (list recordings, tap into detail)
- Recording detail view (transcript display, edit, summarize button, summary display)
- Summary presets UI (picker + custom prompt editor)
- Export / share sheet
- The transcript cleanup pass should be **a simple stub** — call the LLM with a placeholder system prompt and return the cleaned text. Wire up the plumbing but use a basic prompt.

### What NOT to build (Henry handles this)
- **DSPy transcript cleanup pipeline** — the prompt optimization, training data collection, evaluation metrics, and final optimized prompt. This is the core ML contribution and will be developed separately.
- **Summary preset prompt copy** — ship with placeholder text. Final prompt wording will be written by hand.

---

## License

MIT. Do whatever you want with it.

---

## Contributing

PRs welcome. Especially for:
- **Security reviews and improvements** (API key handling, audio storage, network layer)
- New summary presets (the more domain-specific, the better)
- Accessibility improvements
- Localization
- Integration with note-taking apps
