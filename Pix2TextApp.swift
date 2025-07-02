import SwiftUI
import AppKit
import Combine
import WebKit

class AppState: ObservableObject {
    @Published var capturedImage: NSImage?
    @Published var latexResult: String = ""
    @Published var isProcessing: Bool = false
    @Published var confidence: Double = 0.0

    private var lastClipboardChangeCount = -1

    func checkClipboardForImageAndProcess() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastClipboardChangeCount else {
            return
        }
        lastClipboardChangeCount = pasteboard.changeCount

        guard let image = NSImage(pasteboard: pasteboard) else {
            return
        }
        
        self.capturedImage = image
        self.isProcessing = true
        self.latexResult = "Processing..."
        self.confidence = 0.0
        
        callPix2Text(with: image)
    }

    private func callPix2Text(with image: NSImage) {
        guard let tempURL = saveImageTemporarily(image) else {
            DispatchQueue.main.async {
                self.latexResult = "Error: Could not save image for processing."
                self.isProcessing = false
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()

            // Hardcoded path to your local python virtual environment.
            // TODO: Make this more robust for distribution.
            let pythonPath = "/Users/rishitv/Documents/Personal/Pix2Text-Mac/.venv/bin/python"
            
            guard FileManager.default.fileExists(atPath: pythonPath) else {
                DispatchQueue.main.async {
                    self.latexResult = "Error: Python venv not found at \(pythonPath). Please update the path in Pix2TextApp.swift"
                    self.isProcessing = false
                }
                return
            }
            
            guard let scriptPath = Bundle.main.path(forResource: "pix2text_bridge", ofType: "py") else {
                DispatchQueue.main.async {
                    self.latexResult = "Error: pix2text_bridge.py not found in app bundle."
                    self.isProcessing = false
                    try? FileManager.default.removeItem(at: tempURL)
                }
                return
            }
            
            task.executableURL = URL(fileURLWithPath: pythonPath)
            task.arguments = [scriptPath, "file", tempURL.path]

            let outPipe = Pipe()
            task.standardOutput = outPipe
            let errPipe = Pipe()
            task.standardError = errPipe

            do {
                try task.run()
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                
                let rawOutput = String(data: outData, encoding: .utf8) ?? ""

                if let jsonString = self.extractJsonString(from: rawOutput) {
                    self.parsePythonResponse(jsonString)
                } else {
                    let errOutput = String(data: errData, encoding: .utf8) ?? ""
                    DispatchQueue.main.async {
                        var errorMessage = "Error: Could not find valid JSON in script output."
                        if !rawOutput.isEmpty {
                            errorMessage += "\n\n--- Script Output ---\n\(rawOutput)"
                        }
                        if !errOutput.isEmpty {
                            errorMessage += "\n\n--- Script Error Log ---\n\(errOutput)"
                        }
                        self.latexResult = errorMessage
                        self.isProcessing = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.latexResult = "Error: Failed to run script. \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
            
            try? FileManager.default.removeItem(at: tempURL)
        }
    }

    private func saveImageTemporarily(_ image: NSImage) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "p2t-capture-\(UUID().uuidString).png"
        let tempURL = tempDir.appendingPathComponent(fileName)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        do {
            try pngData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    private func cleanLatexString(_ rawString: String) -> String {
        // Find content within $$...$$
        if let startRange = rawString.range(of: "$$"),
           let endRange = rawString.range(of: "$$", options: .backwards),
           startRange.lowerBound != endRange.lowerBound {
            let startIndex = rawString.index(startRange.lowerBound, offsetBy: 2)
            let endIndex = endRange.lowerBound
            if startIndex < endIndex {
                return String(rawString[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Fallback: Find content within $...$
        if let startRange = rawString.range(of: "$"),
           let endRange = rawString.range(of: "$", options: .backwards),
           startRange.lowerBound != endRange.lowerBound {
            let startIndex = rawString.index(startRange.lowerBound, offsetBy: 1)
            let endIndex = endRange.lowerBound
            if startIndex < endIndex {
                return String(rawString[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // If no delimiters are found, return the trimmed string
        return rawString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractJsonString(from string: String) -> String? {
        // Find the first opening curly brace
        guard let startRange = string.range(of: "{") else {
            return nil
        }
        
        // Find the last closing curly brace
        guard let endRange = string.range(of: "}", options: .backwards) else {
            return nil
        }
        
        let potentialJson = String(string[startRange.lowerBound...endRange.lowerBound])
        
        // A simple validation to see if it's likely our JSON
        if potentialJson.contains("\"success\"") || potentialJson.contains("\"error\"") {
            return potentialJson
        }
        
        return nil
    }

    private func parsePythonResponse(_ response: String) {
        guard let data = response.data(using: .utf8) else {
            DispatchQueue.main.async {
                self.latexResult = "Error: Could not decode script response."
                self.isProcessing = false
            }
            return
        }

        DispatchQueue.main.async {
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let error = json["error"] as? String {
                        var errorMessage = "Error: \(error)"
                        if let traceback = json["traceback"] as? String {
                            errorMessage += "\n\n--- Traceback ---\n\(traceback)"
                        }
                        self.latexResult = errorMessage
                        self.confidence = 0.0
                    } else if let latex = json["latex"] as? String {
                        self.latexResult = self.cleanLatexString(latex)
                        self.confidence = json["confidence"] as? Double ?? 0.0
                    } else {
                        self.latexResult = "Error: Invalid JSON response from script."
                        self.confidence = 0.0
                    }
                }
            } catch {
                self.latexResult = "Error: Failed to parse JSON. \(error.localizedDescription)"
                self.confidence = 0.0
            }
            self.isProcessing = false
        }
    }
}

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
    var appState = AppState()
    
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
        popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(appState))
        
        print("✅ Mathpix Replica UI ready!")
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                appState.checkClipboardForImageAndProcess()
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
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            TopBarView()
            Divider()
            ImageAndFormulaView()
            ResultsView()
            ConfidenceBar()
        }
        .background(MathpixTheme.background)
        .onAppear {
            appState.checkClipboardForImageAndProcess()
        }
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
    @EnvironmentObject var appState: AppState
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
                    if let image = appState.capturedImage {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .background(MathpixTheme.originalImageBackground)
                            .padding(.bottom, 20)
                    } else {
                        Text("Copy an image to get started.")
                            .foregroundColor(MathpixTheme.textSecondary)
                            .padding()
                    }
                }

                if appState.isProcessing {
                    ProgressView()
                } else if !appState.latexResult.isEmpty {
                    LatexView(latex: appState.latexResult)
                        .padding(.horizontal, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(MathpixTheme.contentBackground)
    }
}

struct LatexView: NSViewRepresentable {
    let latex: String

    func makeNSView(context: Context) -> WKWebView {
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        
        let config = WKWebViewConfiguration()
        config.preferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Make it transparent
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let html = katexHTML(with: latex)
        nsView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
    }

    private func katexHTML(with latexString: String) -> String {
        let escapedLatex = latexString.replacingOccurrences(of: "\\", with: "\\\\")
                                     .replacingOccurrences(of: "`", with: "\\`")
                                     .replacingOccurrences(of: "$", with: "\\$")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <link rel="stylesheet" href="katex.min.css">
            <script defer src="katex.min.js"></script>
            <style>
                body {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background-color: transparent !important;
                    color: \(cssColor(from: MathpixTheme.textPrimary));
                    font-size: 22px;
                }
                .katex-display {
                    margin: 0;
                }
            </style>
        </head>
        <body>
            <div id="latex-content"></div>
            <script>
                document.addEventListener("DOMContentLoaded", function() {
                    katex.render(`\(escapedLatex)`, document.getElementById('latex-content'), {
                        throwOnError: false,
                        displayMode: true
                    });
                });
            </script>
        </body>
        </html>
        """
    }

    private func cssColor(from color: Color) -> String {
        let nsColor = NSColor(color)
        if let rgbColor = nsColor.usingColorSpace(.sRGB) {
            let red = Int(round(rgbColor.redComponent * 255))
            let green = Int(round(rgbColor.greenComponent * 255))
            let blue = Int(round(rgbColor.blueComponent * 255))
            return "rgb(\(red), \(green), \(blue))"
        }
        return "#212121"
    }
}

// MARK: - RESULTS LIST
struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @State private var copiedResultId: Int?
    
    private var results: [LatexResult] {
        guard !appState.latexResult.isEmpty else { return [] }
        return [
            .init(id: 0, text: appState.latexResult),
            .init(id: 1, text: "$\\begin{equation}\n\(appState.latexResult)\n\\end{equation}$"),
            .init(id: 2, text: "$$ \(appState.latexResult) $$"),
            .init(id: 3, text: "\\begin{equation} \(appState.latexResult) \\end{equation}")
        ]
    }
    
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
                if appState.isProcessing {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    Text("No result to show.")
                        .foregroundColor(MathpixTheme.textSecondary)
                    Spacer()
                } else {
                    ForEach(results) { result in
                        ResultRow(result: result, copiedResultId: $copiedResultId)
                        if result.id != results.last?.id {
                            Divider()
                        }
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
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Text("Confidence")
                    .font(.system(size: 13))
                    .foregroundColor(MathpixTheme.textSecondary)
                ProgressView(value: appState.confidence)
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
