import Foundation

enum SummaryPreset: String, CaseIterable, Identifiable, Codable {
    case fast
    case better
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .better: return "Better"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .fast: return "Quick bullet-point overview"
        case .better: return "Structured summary with topics, insights, and narrative"
        case .custom: return "Write your own system prompt"
        }
    }

    var icon: String {
        switch self {
        case .fast: return "bolt"
        case .better: return "doc.text"
        case .custom: return "pencil"
        }
    }

    /// OpenRouter model slug override, nil means use user's configured model
    var openRouterModel: String? {
        switch self {
        case .fast: return "google/gemini-3.1-flash-lite-preview"
        case .better: return "anthropic/claude-sonnet-4-6"
        case .custom: return nil
        }
    }

    var systemPrompt: String {
        switch self {
        case .fast:
            return """
            You are a recording summarizer. You will receive a transcript of a recording. Produce a brief summary.

            Structure:
            - **Title**: A short descriptive title based on the content.
            - **Participants**: List who was involved, using names or roles if apparent from context.
            - **Key Points** (bulleted list, 3-5 items): The most important points, each as a single concise sentence.

            Guidelines:
            - Be specific: use names, numbers, and concrete claims from the transcript.
            - Do not editorialize or add your own opinions.
            - Do NOT hallucinate or invent details not in the transcript.
            - STRICT LIMIT: 100-200 words total. Be concise.

            Output ONLY the summary. No meta-commentary.
            """
        case .better:
            return """
            You are a recording summarizer. You will receive a transcript of a recording. Produce a concise, informative summary.

            Structure:
            1. **Title & Participants**: Create a short descriptive title based on the content. List the participants with brief identifiers if apparent from context.
            2. **Key Topics** (bulleted list, 4-7 items): The main topics discussed, each with 1-2 sentences of context. Make sure to cover topics from ALL parts of the conversation — beginning, middle, AND end.
            3. **Key Insights** (bulleted list, 3-5 items): The most surprising, counterintuitive, or novel claims from the conversation. These should be noteworthy — not just restate well-known facts. Include the speaker's name (if known) and any specific numbers, names, or examples they used.
            4. **Summary** (2-3 short paragraphs): A narrative overview of the conversation arc. What was the throughline? How did the discussion flow from one topic to the next? What conclusions were reached?

            Guidelines:
            - Be specific: use names, numbers, and concrete claims from the transcript.
            - Attribute key claims to the speaker who made them.
            - Do not editorialize or add your own opinions.
            - Do NOT hallucinate or invent details not in the transcript.
            - STRICT LIMIT: 300-500 words total. Do not exceed 500 words. Be concise — every sentence should earn its place.

            Output ONLY the summary. No meta-commentary.
            """
        case .custom:
            return ""
        }
    }
}

struct SummaryPresetData: Codable {
    let id: String
    let name: String
    let description: String
    let systemPrompt: String
}
