//
//  DXBarcodeScannerView.swift
//  FilmStock
//
//  Scans packaging barcodes (EAN/UPC) and the Interleaved 2 of 5 DX code on a 35mm canister.
//

import SwiftUI
import VisionKit
import Vision

struct DXBarcodeScannerView: View {
    let onCode: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DXDataScannerRepresentable { code in
                    onCode(code)
                    dismiss()
                }
                .ignoresSafeArea()

                Text("dx.scan.instruction")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Data Scanner

private struct DXDataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let recognizedTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: [
                .ean13, .ean8, .upce,
                .i2of5, .i2of5Checksum,
                .code39, .code128
            ])
        ]
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedTypes,
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        guard !uiViewController.isScanning else { return }
        try? uiViewController.startScanning()
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        if uiViewController.isScanning {
            uiViewController.stopScanning()
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        private var didHandle = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            handle(items: addedItems, scanner: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(items: [item], scanner: dataScanner)
        }

        private func handle(items: [RecognizedItem], scanner: DataScannerViewController) {
            guard !didHandle else { return }
            for item in items {
                guard case .barcode(let barcode) = item else { continue }
                let raw = barcode.payloadStringValue ?? ""
                let digits = raw.filter(\.isNumber)
                guard digits.count >= 4 else { continue }
                didHandle = true
                scanner.stopScanning()
                DispatchQueue.main.async { [onCode] in
                    onCode(digits)
                }
                return
            }
        }
    }
}
