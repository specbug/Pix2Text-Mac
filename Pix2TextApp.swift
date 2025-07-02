import SwiftUI
import AppKit
import Combine

@main
struct Pix2TextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Mathpix Replica Version Loading...")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem.button {
            statusButton.image = NSImage(systemSymbolName: "m.square", accessibilityDescription: "Mathpix App")
            statusButton.action = #selector(togglePopover)
            statusButton.target = self
        }
        
        // Create popover with the new Mathpix replica interface
        popover = NSPopover()
        popover.contentSize = NSSize(width: 680, height: 540)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        print("✅ Mathpix Replica UI ready!")
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

// MARK: - THEME
struct MathpixTheme {
    static let background = Color(hex: "#F7F7F7")
    static let contentBackground = Color.white
    static let borderColor = Color(hex: "#EAEAEA")
    static let textPrimary = Color(hex: "#212121")
    static let textSecondary = Color(hex: "#6D6D6D")
    static let accentBlue = Color(hex: "#007AFF")
    static let buttonBlue = Color(hex: "#007AFF")
    static let copiedBlueBG = Color(hex: "#EBF5FF")
    static let originalImageBackground = Color(hex: "#FFFAE6")
}

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            TopBarView()
            Divider()
            ImageAndFormulaView()
            ResultsView()
            ConfidenceBar()
        }
        .background(MathpixTheme.background)
    }
}

// MARK: - TOP BAR
struct TopBarView: View {
    var body: some View {
        HStack(spacing: 16) {
            // Left Action Icons
            HStack(spacing: 12) {
                ToolButton(systemName: "viewfinder")
                ToolButton(systemName: "arrow.up.doc")
                ToolButton(systemName: "scribble")
                ToolButton(systemName: "keyboard")
                ToolButton(systemName: "list.bullet")
            }
            
            Spacer()
            
            // Pagination
            HStack(spacing: 8) {
                Button(action: {}) { Image(systemName: "chevron.left") }
                Text("2/2").font(.system(size: 14, weight: .medium))
                Button(action: {}) { Image(systemName: "chevron.right") }
            }
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(MathpixTheme.textSecondary)
            
            Spacer()
            
            // Right Action Icons
            HStack(spacing: 12) {
                ToolButton(systemName: "trash")
                ToolButton(systemName: "gearshape")
            }
        }
        .padding(12)
        .background(MathpixTheme.contentBackground)
        .frame(height: 50)
    }
}

struct ToolButton: View {
    let systemName: String
    var body: some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundColor(MathpixTheme.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - IMAGE & FORMULA DISPLAY
struct ImageAndFormulaView: View {
    @State private var isOriginalVisible = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar for this section
            HStack {
                Button(action: {
                    withAnimation { isOriginalVisible.toggle() }
                }) {
                    HStack(spacing: 6) {
                       Text(isOriginalVisible ? "Hide Original" : "Show Original")
                       Image(systemName: isOriginalVisible ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(MathpixTheme.textSecondary)
                .font(.system(size: 13))

                Spacer()
            }
            .padding(12)
            .background(MathpixTheme.background)

            // The actual formula display
            VStack {
                if isOriginalVisible {
                    Image("math-formula-42")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .background(MathpixTheme.originalImageBackground)
                        .padding(.bottom, 20)
                }

                Text("a_{\\mathrm{av}-x}=\\frac{v_{2 x}-v_{1 x}}{t_{2}-t_{1}}=\\frac{\\Delta v_{x}}{\\Delta t}")
                    .font(.system(size: 36, design: .serif))
                    .foregroundColor(MathpixTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(MathpixTheme.contentBackground)
    }
}

// MARK: - RESULTS LIST
struct ResultsView: View {
    @State private var copiedResultId: Int? = 0
    let results: [LatexResult] = [
        .init(id: 0, text: "a_{\\mathrm{av}-x}=\\frac{v_{2 x}-v_{1 x}}{t_{2}-t_{1}}=\\frac{\\Delta v_{x}}{\\Delta t}"),
        .init(id: 1, text: "$a_{\\mathrm{av}-x}=\\frac{v_{2 x}-v_{1 x}}{t_{2}-t_{1}}=\\frac{\\Delta v_{x}}{\\Delta t}$"),
        .init(id: 2, text: "$$ a_{\\mathrm{av}-x}=\\frac{v_{2 x}-v_{1 x}}{t_{2}-t_{1}}=\\frac{\\Delta v_{x}}{\\Delta t} $$"),
        .init(id: 3, text: "\\begin{equation} a_{\\mathrm{av}-x}=\\frac{v_{2 x}-v_{1 x}}{t_{2}-t_{1}}=\\frac{\\Delta v_{x}}{\\Delta t} \\end{equation}")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                ActionButton(icon: "doc", text: "Copy PNG")
                ActionButton(icon: "arrow.up.forward.app", text: "Open PNG")
                    .padding(.leading, 8)
                ToolButton(systemName: "slider.horizontal.3")
                    .padding(.leading, 8)
            }
            .padding(12)
            .background(MathpixTheme.background)
            .font(.system(size: 13))
            
            Divider()

            VStack(spacing: 0) {
                ForEach(results) { result in
                    ResultRow(result: result, copiedResultId: $copiedResultId)
                    if result.id != results.last?.id {
                        Divider()
                    }
                }
            }
        }
        .background(MathpixTheme.contentBackground)
    }
}

struct LatexResult: Identifiable, Equatable {
    let id: Int
    let text: String
}

struct ResultRow: View {
    let result: LatexResult
    @Binding var copiedResultId: Int?

    private var isCopied: Bool {
        copiedResultId == result.id
    }
    
    var body: some View {
        Button(action: {
            self.copiedResultId = result.id
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.text, forType: .string)
        }) {
            HStack {
                Text(result.text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(MathpixTheme.textPrimary)
                    .truncationMode(.tail)
                    .lineLimit(1)
                
                if isCopied {
                    Text("COPIED")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MathpixTheme.accentBlue.cornerRadius(4))
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {}) { Image(systemName: "doc.on.doc") }
                    Button(action: {}) { Image(systemName: "pencil") }
                    Button(action: {}) { Image(systemName: "magnifyingglass") }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(MathpixTheme.textSecondary)
                .font(.system(size: 16))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(isCopied ? MathpixTheme.copiedBlueBG : Color.clear)
        }.buttonStyle(PlainButtonStyle())
    }
}

struct ActionButton: View {
    let icon: String
    let text: String
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(text)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(MathpixTheme.textPrimary)
    }
}

// MARK: - CONFIDENCE BAR
struct ConfidenceBar: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("Confidence")
                    .font(.system(size: 13))
                    .foregroundColor(MathpixTheme.textSecondary)
                ProgressView(value: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(MathpixTheme.contentBackground)
        .frame(height: 35)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 