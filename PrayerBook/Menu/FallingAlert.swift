import SwiftUI

extension View {
    /// An alert with a text field that looks like Apple's, but when you tap Cancel the keyboard
    /// goes down and the alert tips over and falls off the bottom of the screen.
    func fallingTextFieldAlert(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        text: Binding<String>,
        placeholder: LocalizedStringKey = "Name",
        message: LocalizedStringKey? = nil,
        confirm: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        modifier(FallingAlertPresenter(
            isPresented: isPresented,
            title: title,
            text: text,
            placeholder: placeholder,
            message: message,
            confirm: confirm,
            action: action
        ))
    }
}

/// Shows the alert over everything, with no slide-up: the alert brings its own animations.
private struct FallingAlertPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let message: LocalizedStringKey?
    let confirm: LocalizedStringKey
    let action: () -> Void

    @State private var showsCover = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showsCover) {
                FallingAlert(
                    title: title,
                    text: $text,
                    placeholder: placeholder,
                    message: message,
                    confirm: confirm,
                    action: action,
                    onFinish: { isPresented = false }
                )
                .presentationBackground(.clear)
            }
            .onChange(of: isPresented, initial: true) { _, isOn in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { showsCover = isOn }
            }
    }
}

private struct FallingAlert: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let message: LocalizedStringKey?
    let confirm: LocalizedStringKey
    let action: () -> Void
    let onFinish: () -> Void

    private enum Stage { case appearing, shown, falling, confirming }
    @State private var stage = Stage.appearing
    @State private var cancelPressed = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .opacity(stage == .shown ? 0.25 : 0)
                    .ignoresSafeArea()

                card
                    .scaleEffect(scale)
                    .opacity(stage == .appearing || stage == .confirming ? 0 : 1)
                    .rotationEffect(.degrees(stage == .falling ? 40 : 0), anchor: .center)
                    .offset(x: stage == .falling ? 60 : 0, y: stage == .falling ? proxy.size.height + 300 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(stage == .shown)
        .onAppear {
            fieldFocused = true
            withAnimation(.spring(duration: 0.3, bounce: 0.25)) { stage = .shown }
        }
    }

    private var scale: CGFloat {
        switch stage {
        case .appearing: 1.15
        case .confirming: 0.92
        case .shown, .falling: 1
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)

            TextField(placeholder, text: $text)
                .focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit(confirmTapped)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.08), in: .capsule)

            HStack(spacing: 10) {
                Button(action: cancelTapped) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(cancelPressed ? .red : nil)

                Button(action: confirmTapped) {
                    Text(confirm)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
        .padding(22)
        .frame(width: 300)
        // A frosted background rather than Liquid Glass: glass stretches when it tips over.
        .background(.regularMaterial, in: .rect(cornerRadius: 34))
        .compositingGroup()
    }

    private func cancelTapped() {
        // The keyboard goes down, Cancel blushes red, and the alert tips over and falls away.
        fieldFocused = false
        withAnimation(.easeOut(duration: 0.12)) { cancelPressed = true }
        withAnimation(.easeIn(duration: 0.55).delay(0.08)) {
            stage = .falling
        } completion: {
            onFinish()
        }
    }

    private func confirmTapped() {
        fieldFocused = false
        action()
        withAnimation(.easeOut(duration: 0.2)) {
            stage = .confirming
        } completion: {
            onFinish()
        }
    }
}
