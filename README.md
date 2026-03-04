<p align="center">
  <img src="assets/logo.png" alt="Pocketless" width="300">
</p>

<h1 align="center">Pocketless</h1>

<p align="center">
  <b>You don't need a $200 puck.</b><br>
  Open-source iOS app for recording, transcribing, and summarizing conversations.<br>
  No hardware. No subscription. BYOK (Bring Your Own Keys).
</p>

---

## What It Does

1. **Record** — Tap to record with your phone mic or any Bluetooth microphone
2. **Transcribe** — On-device via [WhisperKit](https://github.com/argmaxinc/WhisperKit), no network needed
3. **Clean Up** — LLM pass removes filler words, fixes punctuation (optional)
4. **Summarize** — Send to any OpenAI-compatible API (OpenRouter, OpenAI, Ollama, etc.)
5. **Export** — Share as plain text, markdown, or JSON

## Why

The [Plaud NotePin](https://www.plaud.ai/products/plaud-notepin) is a $169 recording puck with a $79–100/year subscription for AI transcription and summaries. The "hardware" is a mic that syncs to a phone app where all the actual processing happens. Your phone can already do all of this.

## Setup

- Clone and open in Xcode 15+
- Build and run (iOS 17+)
- Recording and on-device transcription work immediately — no API key needed
- For cleanup and summaries, add your API key in Settings (default: [OpenRouter](https://openrouter.ai/keys))

## App Store

If there's interest, I'll get this on the App Store. Open an issue or star the repo to let me know.

## License

MIT — do whatever you want with it.
