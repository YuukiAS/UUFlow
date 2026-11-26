import Foundation
import SnugCore

enum AppIdentity {
    static let name = "UUFlow"
    static let repository = URL(string: "https://github.com/YuukiAS/UUFlow")!

    static var version: Version? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return nil }
        return Version(text)
    }

    static var versionText: String { version?.description ?? "开发版" }
}
