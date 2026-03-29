import SwiftUI

struct MicButton: View {
    @ObservedObject var engine: VoiceEngine

    var body: some View {
        Button {
            engine.isRecording ? engine.stop() : engine.start()
        } label: {
            HStack {
                Image(systemName: engine.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 20, weight: .bold))

                Text(engine.isRecording ? "Stop Listening" : "Start Listening")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity) // full width
            .padding()
            .background(
                LinearGradient(
                    colors: engine.isRecording
                        ? [.red.opacity(0.9), .red.opacity(0.7)]
                        : [.blue.opacity(0.9), .blue.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(
                color: engine.isRecording ? .red.opacity(0.5) : .blue.opacity(0.4),
                radius: 20, x: 0, y: 8
            )
            .animation(.easeInOut(duration: 0.25), value: engine.isRecording)
        }
    }
}
