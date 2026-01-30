//
//  WKColor.swift
//  WebBridgeKit
//
//  Created on 2026-01-16.
//

import UIKit

/// WebBridgeKit 颜色常量
public class WKColor: NSObject {

    public enum grey {
        public static let base = UIColor.systemGray
        public static let darken1 = UIColor.systemGray2
        public static let darken2 = UIColor.systemGray3
        public static let darken3 = UIColor.systemGray4
        public static let darken4 = UIColor.systemGray5
        public static let lighten1 = UIColor.systemGray5
        public static let lighten2 = UIColor.systemGray6
        public static let lighten3 = UIColor.systemGray6
        public static let lighten4 = UIColor.systemGray6
        public static let lighten5 = UIColor.systemGray6
    }

    public enum blue {
        public static let base = UIColor.systemBlue
        public static let darken1 = UIColor.systemBlue.withAlphaComponent(0.8)
        public static let darken5 = UIColor.systemBlue.withAlphaComponent(0.5)
    }

    public enum lightBlue {
        public static let darken3 = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
    }

    public static let white = UIColor.white
    public static let black = UIColor.black

    public enum background {
        public static let primary = UIColor.systemBackground
        public static let secondary = UIColor.secondarySystemBackground
    }
}
