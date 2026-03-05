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

## Transcription Quality

Getting good transcriptions on a phone is harder than it looks. Here's what went into it.

**Model selection:** Pocketless uses [Whisper large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo) via [WhisperKit](https://github.com/argmaxinc/WhisperKit) for on-device STT. Large-v3-turbo hits a sweet spot for mobile — it matches large-v3 accuracy ([~8% WER on common benchmarks](https://github.com/openai/whisper)) while running 3-4x faster, which matters when you're transcribing on an iPhone without a network connection. Smaller models (tiny, base, small) degrade noticeably on real-world conversational audio — overlapping speech, background noise, domain-specific vocabulary.

**Post-processing pipeline:**
- **Hallucination filtering** — Whisper is known to hallucinate segments beyond the actual audio duration (e.g. phantom "Thank you." at the end). We compare each segment's timestamp against the real audio length and drop anything that overshoots.
- **Special token stripping** — Whisper's output includes control tokens (`<|startoftranscript|>`, `<|en|>`, etc.) that need to be stripped before display.
- **Sentence-level segmentation** — When word-level timestamps are available, we group words into sentence-level segments at punctuation boundaries. This gives you timestamped, readable chunks instead of one giant text blob or word-by-word fragments.

**LLM cleanup pass (optional):** Raw Whisper output still has filler words, false starts, bad punctuation, and missing speaker labels. An LLM cleanup pass fixes these while strictly preserving meaning — no paraphrasing, no invented content, no moving words between speakers. The cleanup prompt was designed around faithfulness: it's better to leave an error in than to "fix" it by hallucinating. Chunking uses overlapping windows at sentence boundaries so long recordings don't lose context at chunk edges.

**Summarization models:** The fast preset uses Gemini 3.1 Flash Lite (cheap, fast, good enough for bullet points). The better preset uses Claude Sonnet 4.6 (more thorough, structured output with topics, insights, and narrative). Both run through OpenRouter by default — or point at any OpenAI-compatible endpoint.

## Setup

- Clone and open in Xcode 15+
- Build and run (iOS 17+)
- Recording and on-device transcription work immediately — no API key needed
- For cleanup and summaries, add your API key in Settings (default: [OpenRouter](https://openrouter.ai/keys))

## App Store

If there's interest, I'll get this on the App Store, though there are lots of apps just like it. Open an issue or star the repo to let me know.

## Built With

The app was built with [Claude Code](https://claude.ai/claude-code). The transcription quality work — model selection, hallucination filtering, cleanup prompt design, and the overall pipeline architecture — was a hands-on collaboration. I really wanted the transcriptions to be good and not a slapdash "throw everything at an LLM"; the model choices are not an accident, I did comparisons of a few models. That's definitely the most interesting part of this project, it's a surpisingly hard problem. I'd like to refine everything to be a little more quantitative, but I did a few non-vibes based evaluations.

## License

MIT — do whatever you want with it.
