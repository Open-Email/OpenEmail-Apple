import Foundation

extension CGFloat {
    #if os(macOS)
    static let sidebarWidth: CGFloat = 150
    #endif

    enum Spacing {
        /// 64px
        static let xxxxLarge: CGFloat = 64

        /// 56px
        static let xxxLarge: CGFloat = 56

        /// 48px
        static let xxLarge: CGFloat = 48

        /// 32px
        static let xLarge: CGFloat = 32

        /// 24px
        static let large: CGFloat = 24

        /// 16px
        static let `default`: CGFloat = 16

        /// 12px
        static let small: CGFloat = 12

        /// 8px
        static let xSmall: CGFloat = 10

        /// 6px
        static let xxSmall: CGFloat = 6

        /// 4px
        static let xxxSmall: CGFloat = 4

        /// 2px
        static let xxxxSmall: CGFloat = 2
    }

    enum CornerRadii {
        /// 10px
        static let `default`: CGFloat = 10

        /// 5px
        static let small: CGFloat = 5
    }
}
