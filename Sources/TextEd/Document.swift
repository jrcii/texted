import AppKit
import CSimd

final class Document: NSDocument, NSTextViewDelegate {

    // Text read from disk waiting for a window (or a revert) to ingest it.
    // For ASCII files this is a zero-copy CFString wrapper around
    // `pendingBacking`'s bytes; NSTextStorage makes the only real copy when
    // it ingests, after which both are released. The document never keeps
    // its own copy of the text — the text view's storage is the model.
    private var pendingString: NSString?
    private var pendingBacking: NSData?
    private weak var textView: NSTextView?

    override class var autosavesInPlace: Bool { true }

    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }

    // MARK: - Window

    override func makeWindowControllers() {
        let contentRect = NSRect(x: 0, y: 0, width: 720, height: 540)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.tabbingMode = .preferred

        let scrollView = NSScrollView(frame: contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]

        // TextKit 2: layout happens per viewport, so multi-hundred-MB files
        // don't pay a whole-document layout cost up front.
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.frame = contentRect
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: contentRect.width, height: .greatestFiniteMagnitude)

        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 5, height: 8)
        textView.font = NSFont.userFixedPitchFont(ofSize: Document.storedFontSize)
        textView.delegate = self

        scrollView.documentView = textView
        window.contentView = scrollView
        window.makeFirstResponder(textView)

        self.textView = textView
        let controller = NSWindowController(window: window)
        addWindowController(controller)
        window.center()
        applyPendingString()
    }

    private func applyPendingString() {
        if let textView, let pendingString {
            textView.string = pendingString as String
            self.pendingString = nil
            self.pendingBacking = nil
        }
    }

    // MARK: - Reading / writing

    override func read(from data: Data, ofType typeName: String) throws {
        let nsdata = data as NSData
        let bytes = nsdata.bytes.assumingMemoryBound(to: UInt8.self)
        let scan = te_scan(nsdata.length > 0 ? bytes : nil, nsdata.length)

        if nsdata.length == 0 {
            pendingString = ""
            pendingBacking = nil
        } else if scan.ascii {
            // Zero-copy wrapper: NSTextStorage copies out of it on ingest
            // (into 1-byte-per-char internal storage), so no decode pass and
            // no intermediate copy. `pendingBacking` keeps the bytes alive.
            if let wrapped = CFStringCreateWithBytesNoCopy(
                kCFAllocatorDefault, bytes, nsdata.length,
                CFStringBuiltInEncodings.ASCII.rawValue, false, kCFAllocatorNull) {
                pendingString = wrapped as NSString
                pendingBacking = nsdata
            } else {
                pendingString = NSString(data: data, encoding: String.Encoding.ascii.rawValue)
                pendingBacking = nil
            }
        } else if scan.valid_utf8 {
            pendingString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            pendingBacking = nil
        } else {
            pendingString = NSString(data: data, encoding: String.Encoding.isoLatin1.rawValue)
            pendingBacking = nil
        }
        guard pendingString != nil else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadInapplicableStringEncodingError)
        }

        // Revert / external reload while the window is already open. Initial
        // opens may read on a background thread (canConcurrentlyReadDocuments);
        // then textView is still nil and makeWindowControllers ingests later.
        if textView != nil {
            if Thread.isMainThread {
                applyPendingString()
            } else {
                DispatchQueue.main.async { [weak self] in self?.applyPendingString() }
            }
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        textView?.breakUndoCoalescing()
        let string: String
        if let textView {
            string = textView.string
        } else if let pendingString {
            string = pendingString as String
        } else {
            string = ""
        }
        return Data(string.utf8)
    }

    // MARK: - Undo routed through the document

    func undoManager(for view: NSTextView) -> UndoManager? { undoManager }

    // MARK: - Font size (persisted, like the original's "fontSize" default)

    private static var storedFontSize: CGFloat {
        CGFloat(UserDefaults.standard.integer(forKey: "fontSize"))
    }

    @objc func makeTextBigger(_ sender: Any?) { adjustFontSize(by: 1) }
    @objc func makeTextSmaller(_ sender: Any?) { adjustFontSize(by: -1) }

    private func adjustFontSize(by delta: CGFloat) {
        guard let textView else { return }
        let current = textView.font ?? NSFont.userFixedPitchFont(ofSize: 0) ?? NSFont.systemFont(ofSize: 12)
        let newSize = max(4, min(128, current.pointSize + delta))
        textView.font = NSFont.userFixedPitchFont(ofSize: newSize)
        UserDefaults.standard.set(Int(newSize), forKey: "fontSize")
    }
}
