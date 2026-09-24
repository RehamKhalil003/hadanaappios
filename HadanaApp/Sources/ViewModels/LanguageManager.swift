import SwiftUI
import UIKit

class LanguageManager: ObservableObject {
    @Published var isArabic: Bool {
        didSet {
            UserDefaults.standard.set(isArabic, forKey: "isArabic")
            applyUIKitDirection()
        }
    }

    init() {
        if UserDefaults.standard.object(forKey: "isArabic") == nil {
            UserDefaults.standard.set(true, forKey: "isArabic")
            self.isArabic = true
        } else {
            self.isArabic = UserDefaults.standard.bool(forKey: "isArabic")
        }
        applyUIKitDirection()
    }

    var layoutDirection: LayoutDirection { isArabic ? .rightToLeft : .leftToRight }

    func toggle() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isArabic.toggle()
        }
    }

    func t(_ ar: String, _ en: String) -> String { isArabic ? ar : en }

    private func applyUIKitDirection() {
        let attr: UISemanticContentAttribute = isArabic ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = attr
        UINavigationBar.appearance().semanticContentAttribute = attr
        UITabBar.appearance().semanticContentAttribute = attr
    }
}
