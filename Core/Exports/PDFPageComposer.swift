import UIKit

/// Minimal paginating layout helper used by `ProofPackPDFRenderer`. Not a
/// general-purpose PDF library - just enough to lay out text blocks, a
/// simple table, and images without distortion, with a stable
/// header/footer and page numbers on every page (spec 12.5).
final class PDFPageComposer {
    static let pageSize = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72pt/in
    private static let margin: CGFloat = 36
    private static let headerHeight: CGFloat = 40
    private static let footerHeight: CGFloat = 28

    private let renderer: UIGraphicsPDFRenderer
    private let title: String
    private let subtitle: String
    private var context: UIGraphicsPDFRendererContext?
    private var cursorY: CGFloat = 0
    private var pageNumber = 0

    var contentBounds: CGRect {
        CGRect(
            x: Self.margin, y: Self.margin + Self.headerHeight,
            width: Self.pageSize.width - Self.margin * 2,
            height: Self.pageSize.height - Self.margin * 2 - Self.headerHeight - Self.footerHeight
        )
    }

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        renderer = UIGraphicsPDFRenderer(bounds: Self.pageSize)
    }

    /// Runs `body`, which calls the `draw*` methods below as many times as
    /// needed; page breaks happen automatically.
    func render(_ body: (PDFPageComposer) -> Void) -> Data {
        renderer.pdfData { ctx in
            context = ctx
            startNewPage()
            body(self)
        }
    }

    func startNewPage() {
        context?.beginPage()
        pageNumber += 1
        drawHeader()
        drawFooter()
        cursorY = contentBounds.minY
    }

    private func ensureSpace(_ height: CGFloat) {
        if cursorY + height > contentBounds.maxY {
            startNewPage()
        }
    }

    func drawSectionTitle(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
        let size = (text as NSString).size(withAttributes: attributes)
        ensureSpace(size.height + 12)
        cursorY += 8
        (text as NSString).draw(at: CGPoint(x: contentBounds.minX, y: cursorY), withAttributes: attributes)
        cursorY += size.height + 4
    }

    func drawLabelValue(_ label: String, _ value: String) {
        let text = "\(label): \(value)"
        drawBody(text)
    }

    func drawBody(_ text: String, color: UIColor = .black) {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: color]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: contentBounds.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], attributes: attributes, context: nil
        )
        ensureSpace(bounding.height + 4)
        (text as NSString).draw(
            in: CGRect(x: contentBounds.minX, y: cursorY, width: contentBounds.width, height: bounding.height),
            withAttributes: attributes
        )
        cursorY += bounding.height + 4
    }

    /// Simple fixed-column table for the Tax Pack summary (spec 12.1).
    func drawTableRow(_ columns: [String], widths: [CGFloat], bold: Bool = false) {
        let font = bold ? UIFont.boldSystemFont(ofSize: 9) : UIFont.systemFont(ofSize: 9)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let rowHeight: CGFloat = 16
        ensureSpace(rowHeight)
        var x = contentBounds.minX
        for (index, column) in columns.enumerated() {
            let width = index < widths.count ? widths[index] : 60
            (column as NSString).draw(
                in: CGRect(x: x, y: cursorY, width: width - 4, height: rowHeight),
                withAttributes: attributes
            )
            x += width
        }
        cursorY += rowHeight
        if bold {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: contentBounds.minX, y: cursorY))
            path.addLine(to: CGPoint(x: contentBounds.maxX, y: cursorY))
            UIColor.lightGray.setStroke()
            path.stroke()
            cursorY += 4
        }
    }

    /// Scales to fit within the remaining content width without
    /// distortion (spec 12.5). If `image` is nil, draws a placeholder
    /// notice instead of silently omitting the evidence (spec 12.5: "PDF
    /// generation must handle missing images gracefully and identify
    /// unavailable evidence rather than silently omitting it").
    func drawImage(_ image: UIImage?, caption: String, maxHeight: CGFloat = 260) {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            drawBody("[Evidence unavailable: \(caption)]", color: .systemOrange)
            return
        }
        let maxWidth = contentBounds.width
        let scale = min(maxWidth / image.size.width, maxHeight / image.size.height, 1)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        ensureSpace(drawSize.height + 20)
        image.draw(in: CGRect(x: contentBounds.minX, y: cursorY, width: drawSize.width, height: drawSize.height))
        cursorY += drawSize.height + 4
        drawBody(caption, color: .darkGray)
    }

    func addSpacing(_ height: CGFloat = 8) {
        cursorY += height
    }

    private func drawHeader() {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
        (title as NSString).draw(at: CGPoint(x: Self.margin, y: Self.margin), withAttributes: attributes)
        let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray]
        (subtitle as NSString).draw(at: CGPoint(x: Self.margin, y: Self.margin + 20), withAttributes: subtitleAttributes)
    }

    private func drawFooter() {
        let text = "Page \(pageNumber)"
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(
            at: CGPoint(x: Self.pageSize.width - Self.margin - size.width, y: Self.pageSize.height - Self.margin),
            withAttributes: attributes
        )
    }
}
