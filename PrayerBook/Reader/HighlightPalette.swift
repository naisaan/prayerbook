import UIKit

/// The row of colors shown over a highlight, in a Liquid Glass capsule: the four highlighter
/// colors and the underline button, or, after tapping the underline button, the four
/// underline colors. The trash button at the end removes the highlight.
final class HighlightPalette: UIView {
    private enum Mode { case highlight, underline }

    private var style: HighlightStyle
    private var mode: Mode
    private let stack = UIStackView()
    /// Called with the chosen style, and whether the colors should close afterward.
    private let onChoose: (HighlightStyle, Bool) -> Void
    private let onRemove: () -> Void

    private static let itemSize: CGFloat = 48
    private static let dotSize: CGFloat = 28

    init(style: HighlightStyle, onChoose: @escaping (HighlightStyle, Bool) -> Void, onRemove: @escaping () -> Void) {
        self.style = style
        self.mode = Self.mode(for: style)
        self.onChoose = onChoose
        self.onRemove = onRemove
        super.init(frame: .zero)

        let glass = UIVisualEffectView(effect: UIGlassEffect())
        glass.cornerConfiguration = .capsule()
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: glass.contentView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor, constant: -4),
        ])

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        rebuild()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
            // The underline's text color is called White or Black depending on the mode.
            self.rebuild()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private static func mode(for style: HighlightStyle) -> Mode {
        if case .underline = style { return .underline }
        return .highlight
    }

    func appear() {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func disappear(animated: Bool) {
        guard animated else { return removeFromSuperview() }
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    private func choose(_ newStyle: HighlightStyle, closes: Bool) {
        style = newStyle
        mode = Self.mode(for: newStyle)
        rebuild()
        onChoose(newStyle, closes)
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var items: [UIView] = []
        switch mode {
        case .highlight:
            for color in HighlightColor.allCases {
                items.append(dot(color.swatch, isSelected: style == .highlight(color), label: color.name) { [weak self] in
                    self?.choose(.highlight(color), closes: true)
                })
            }
            items.append(symbol("underline", label: String(localized: "Underline")) { [weak self] in
                self?.choose(.underline(Highlights.shared.lastUnderlineColor), closes: false)
            })
        case .underline:
            items.append(symbol("highlighter", label: String(localized: "Highlight")) { [weak self] in
                self?.choose(.highlight(Highlights.shared.lastHighlightColor), closes: false)
            })
            let isDark = traitCollection.userInterfaceStyle == .dark
            for color in UnderlineColor.allCases {
                items.append(dot(color.color, isSelected: style == .underline(color), label: color.name(isDark: isDark)) { [weak self] in
                    self?.choose(.underline(color), closes: true)
                })
            }
        }
        items.append(symbol("trash", label: String(localized: "Remove Highlight"), action: onRemove))

        for (position, item) in items.enumerated() {
            if position > 0 { stack.addArrangedSubview(separator()) }
            stack.addArrangedSubview(item)
        }
    }

    /// A round swatch. The chosen one has a ring around it.
    private func dot(_ color: UIColor, isSelected: Bool, label: String, action: @escaping () -> Void) -> UIView {
        let button = item(label: label, action: action)
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button

        let swatch = UIView()
        swatch.backgroundColor = color
        swatch.layer.cornerRadius = Self.dotSize / 2
        swatch.isUserInteractionEnabled = false
        swatch.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(swatch)
        var constraints = [
            swatch.widthAnchor.constraint(equalToConstant: Self.dotSize),
            swatch.heightAnchor.constraint(equalToConstant: Self.dotSize),
            swatch.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            swatch.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ]

        if isSelected {
            let ringSize = Self.dotSize + 8
            let ring = UIView()
            ring.layer.cornerRadius = ringSize / 2
            ring.layer.borderWidth = 2
            ring.layer.borderColor = UIColor.label.resolvedColor(with: traitCollection).cgColor
            ring.isUserInteractionEnabled = false
            ring.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(ring)
            constraints += [
                ring.widthAnchor.constraint(equalToConstant: ringSize),
                ring.heightAnchor.constraint(equalToConstant: ringSize),
                ring.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                ring.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            ]
        }
        NSLayoutConstraint.activate(constraints)
        return button
    }

    private func symbol(_ name: String, label: String, action: @escaping () -> Void) -> UIView {
        let button = item(label: label, action: action)
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: name, withConfiguration: configuration), for: .normal)
        button.tintColor = .label
        return button
    }

    private func item(label: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction { _ in action() })
        button.accessibilityLabel = label
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: Self.itemSize),
            button.heightAnchor.constraint(equalToConstant: Self.itemSize),
        ])
        return button
    }

    /// The faint line between two buttons.
    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor.label.withAlphaComponent(0.12)
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.widthAnchor.constraint(equalToConstant: 1 / max(traitCollection.displayScale, 1)),
            line.heightAnchor.constraint(equalToConstant: 26),
        ])
        return line
    }
}
