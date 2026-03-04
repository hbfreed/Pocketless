import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            // Page 1
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.red)
                Text("Record Conversations")
                    .font(.title.bold())
                Text("Tap to record with your phone mic or any Bluetooth microphone. Works offline, no hardware needed.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
                Spacer()
                nextButton
            }
            .tag(0)

            // Page 2
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                Text("Transcribe On-Device")
                    .font(.title.bold())
                Text("Automatic transcription using WhisperKit — runs entirely on your device. No API key needed, fully private.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
                Spacer()
                nextButton
            }
            .tag(1)

            // Page 3
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "key.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
                Text("Bring Your Own Keys")
                    .font(.title.bold())
                Text("Add your OpenRouter or OpenAI API key to unlock AI cleanup and summaries. Your keys, your data.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
                Spacer()
                Button("Get Started") {
                    hasCompletedOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 60)
            }
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var nextButton: some View {
        Button("Next") {
            withAnimation {
                currentPage += 1
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.bottom, 60)
    }
}
