import SpriteKit
import UIKit

/// Placeholder art generated once into reusable `SKTexture`s at startup
/// (KTD-4: pre-rendered shapes, not per-frame `SKShapeNode` geometry). U22/U24
/// replace these with the design-spec look. Colors are the graybox palette.
struct PlaceholderAtlas {
    let hero: SKTexture       // parchment pilgrim
    let heroSubmerged: SKTexture
    let foe: SKTexture        // r9 base; scaled per-foe
    let elite: SKTexture      // r15
    let mote: SKTexture
    let spark: SKTexture      // hit/flash/bolt
    let cardCharge: SKTexture // the rising fate corner

    init() {
        hero = Self.roundedRect(size: CGSize(width: 18, height: 26), radius: 3, color: Self.rgb(0xE6D8B8))
        heroSubmerged = Self.roundedRect(size: CGSize(width: 18, height: 26), radius: 3, color: Self.rgb(0x8A6FB3))
        foe = Self.circle(radius: 9, color: Self.rgb(0x5E4B3D))
        elite = Self.circle(radius: 15, color: Self.rgb(0x4A3A30))
        mote = Self.circle(radius: 5, color: Self.rgb(0x8A6FB3))
        spark = Self.circle(radius: 3, color: Self.rgb(0xE6D8B8))
        cardCharge = Self.roundedRect(size: CGSize(width: 46, height: 66), radius: 5, color: Self.rgb(0xCDBB92))
    }

    static func rgb(_ hex: Int) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func circle(radius: CGFloat, color: UIColor) -> SKTexture {
        let d = radius * 2
        let img = UIGraphicsImageRenderer(size: CGSize(width: d, height: d)).image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
        }
        return SKTexture(image: img)
    }

    private static func roundedRect(size: CGSize, radius: CGFloat, color: UIColor) -> SKTexture {
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: radius).fill()
        }
        return SKTexture(image: img)
    }
}
