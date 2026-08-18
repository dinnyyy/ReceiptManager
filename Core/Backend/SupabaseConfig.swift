import Foundation

enum SupabaseConfig {
    /// Read from Info.plist, which is templated from Config/Secrets.xcconfig
    /// at build time (see project.yml) - never hard-coded here, per spec
    /// 24 "Configure environment-specific backend URLs/keys through build
    /// settings/configuration; no secrets committed."
    static var url: URL {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: string), !string.isEmpty else {
            fatalError("SupabaseURL missing from Info.plist - copy Config/Secrets.xcconfig.template to Config/Secrets.xcconfig and fill in your project's values.")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String, !key.isEmpty else {
            fatalError("SupabaseAnonKey missing from Info.plist - copy Config/Secrets.xcconfig.template to Config/Secrets.xcconfig and fill in your project's values.")
        }
        return key
    }
}
