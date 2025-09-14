import Testing
import Foundation

@testable import LetsTalk

@Suite("TileImagesStorage")
struct TileImagesStorageTests {

    private func tinyPNGData() -> Data {
        // Base64 for a 1x1 transparent PNG
        let b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
        return Data(base64Encoded: b64)!
    }

    @Test("savePNG returns a filename and creates a file")
    func savePNGCreatesFile() throws {
        let data = tinyPNGData()
        let relative = TileImagesStorage.savePNG(data)
        #expect(relative != nil)

        if let relative {
            let url = TileImagesStorage.imagesDirectory.appendingPathComponent(relative)
            #expect(FileManager.default.fileExists(atPath: url.path))
            // Cleanup
            TileImagesStorage.delete(relativePath: relative)
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("delete handles missing files gracefully")
    func deleteMissingFileIsNoop() throws {
        // Random non-existent filename
        let bogus = UUID().uuidString + ".png"
        // Should not throw or crash
        TileImagesStorage.delete(relativePath: bogus)
        #expect(true) // Reaching here without error is success
    }
}
