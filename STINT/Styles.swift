import SwiftUI

// Custom styled container with better contrast
struct StyledBox<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
}

// Output text area with monospace font and scroll
struct OutputArea: View {
    let text: String
    let placeholder: String
    
    var body: some View {
        ScrollView {
            Text(text.isEmpty ? placeholder : text)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// Scrolling output area that auto-scrolls to bottom
struct ScrollingOutputArea: View {
    let text: String
    let placeholder: String
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? placeholder : text)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .id("outputEnd")
            }
            .onChange(of: text) { _ in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("outputEnd", anchor: .bottom)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

// Radio button style
struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// Status indicator
struct StatusRow: View {
    let isRunning: Bool
    let message: String
    let onStop: () -> Void
    
    var body: some View {
        HStack {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isRunning {
                Button("Stop") {
                    onStop()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
