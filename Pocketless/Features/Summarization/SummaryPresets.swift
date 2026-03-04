import Foundation

enum SummaryPreset: String, CaseIterable, Identifiable, Codable {
    case quick
    case detailed
    case casual
    case pedantic
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .detailed: return "Detailed"
        case .casual: return "Casual"
        case .pedantic: return "Pedantic"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .quick: return "3-5 bullet points, just the highlights"
        case .detailed: return "Thorough structured notes with decisions and action items"
        case .casual: return "Conversational recap, like telling a friend"
        case .pedantic: return "Exhaustive, nothing omitted, with timestamps"
        case .custom: return "Write your own system prompt"
        }
    }

    var icon: String {
        switch self {
        case .quick: return "bolt"
        case .detailed: return "doc.text"
        case .casual: return "bubble.left"
        case .pedantic: return "magnifyingglass"
        case .custom: return "pencil"
        }
    }

    /// Placeholder prompt text — final copy handled by Henry
    var systemPrompt: String {
        switch self {
        case .quick:
            return "Summarize this transcript into 3-5 concise bullet points covering only the key highlights."
        case .detailed:
            return "Create thorough structured notes from this transcript. Include: key discussion points, decisions made, action items with owners if mentioned, and any open questions."
        case .casual:
            return "Give a casual, conversational recap of this transcript. Write it like you're telling a friend what happened. Keep it natural and easy to read."
        case .pedantic:
            return "Create an exhaustive summary of this transcript. Nothing should be omitted. Include timestamps referencing the transcript. Organize by topic and subtopic."
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
