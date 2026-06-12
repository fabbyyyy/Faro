//
//  PDFExportService.swift
//  Faro
//
//  Exportación de vistas SwiftUI a PDF con ImageRenderer + CoreGraphics.
//  Sin dependencias externas; el archivo queda en el directorio temporal
//  y se comparte con ShareLink.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PDFExportService: PDFExportServiceProtocol {

    /// Renderiza la vista como una página PDF de ancho carta.
    @MainActor
    func exportPDF<Content: View>(view: Content, fileName: String) -> URL? {
        let renderer = ImageRenderer(content: view.frame(width: 612)) // ancho carta en puntos
        renderer.proposedSize = ProposedViewSize(width: 612, height: nil)
        renderer.scale = 2

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("pdf")

        var succeeded = false
        renderer.render { size, renderInContext in
            var mediaBox = CGRect(origin: .zero,
                                  size: CGSize(width: 612, height: max(size.height, 792)))
            guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }
            context.beginPDFPage(nil)
            // Origen de PDF abajo-izquierda: alinear contenido arriba.
            context.translateBy(x: 0, y: mediaBox.height - size.height)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
            succeeded = true
        }
        return succeeded ? url : nil
    }

    /// Renderiza la ficha pública como imagen para compartir.
    @MainActor
    func exportImage<Content: View>(view: Content) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: 420))
        renderer.proposedSize = ProposedViewSize(width: 420, height: nil)
        renderer.scale = 3
        return renderer.uiImage
    }
}
