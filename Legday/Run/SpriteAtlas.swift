import SpriteKit
import UIKit

/// The drawn art, resized at startup into the point boxes the render layer
/// assumes. Motes and sparks stay procedural.
struct SpriteAtlas {
    let hero: SKTexture
    let heroSubmerged: SKTexture
    let lantern: SKTexture
    let foe: SKTexture        // 18pt base; scaled per-foe
    let elite: SKTexture      // 30pt
    let mote: SKTexture
    let spark: SKTexture      // hit/flash/bolt
    let cardCharge: SKTexture // the rising fate corner
    let reaper: SKTexture

    init() {
        hero = Self.art("pilgrim-body", height: 26)
        heroSubmerged = Self.art("pilgrim-body", height: 26, tint: Self.rgb(0x8A6FB3))
        lantern = Self.art("pilgrim-lantern", height: 7)
        foe = Self.art("foe-base", height: 18, tint: Self.rgb(0xC06430))
        elite = Self.art("foe-elite", height: 30, tint: Self.rgb(0x7A2E1E))
        cardCharge = Self.art("card-back", height: 66)
        reaper = Self.art("reaper", height: 84)
        mote = Self.circle(radius: 5, color: Self.rgb(0x8A6FB3))
        spark = Self.circle(radius: 3, color: Self.rgb(0xE9DCBC))
    }

    static func rgb(_ hex: Int) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    /// Loads a drawing and fits it to `height`, keeping its aspect. A missing
    /// file falls back to a silhouette.
    private static func art(_ name: String, height: CGFloat, tint: UIColor? = nil) -> SKTexture {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let src = UIImage(contentsOfFile: url.path), src.size.height > 0 else {
            return roundedRect(size: CGSize(width: height * 0.7, height: height),
                               radius: 3, color: tint ?? rgb(0xE9DCBC))
        }
        let size = CGSize(width: (height * src.size.width / src.size.height).rounded(), height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            src.draw(in: rect)
            // The cross-hatching gives a tint its texture, so the fill is partial.
            if let tint {
                tint.setFill()
                ctx.cgContext.setBlendMode(.sourceAtop)
                ctx.cgContext.setAlpha(0.62)
                ctx.cgContext.fill(rect)
            }
        }
        return SKTexture(image: img)
    }

    /// A drawing at its own size, optionally taking a colour at partial alpha so
    /// the cross-hatching survives.
    static func baked(_ name: String, tint: UIColor?) -> SKTexture? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let src = UIImage(contentsOfFile: url.path), src.size.height > 0 else { return nil }
        let side = 128.0
        let size = CGSize(width: (side * src.size.width / src.size.height).rounded(), height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            src.draw(in: rect)
            if let tint {
                tint.setFill()
                ctx.cgContext.setBlendMode(.sourceAtop)
                ctx.cgContext.setAlpha(0.80)
                ctx.cgContext.fill(rect)
            }
        }
        return SKTexture(image: img)
    }

    /// A flat quad. A light needs a surface, and the channel floor had none.
    static func fill(_ color: UIColor) -> SKTexture {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        return SKTexture(image: img)
    }

    static func circle(radius: CGFloat, color: UIColor) -> SKTexture {
        let d = radius * 2
        let img = UIGraphicsImageRenderer(size: CGSize(width: d, height: d)).image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
        }
        return SKTexture(image: img)
    }

    private static func roundedRect(size: CGSize, radius: CGFloat, color: UIColor) -> SKTexture {
        let img = UIGraphicsImageRenderer(size: size).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: radius).fill()
        }
        return SKTexture(image: img)
    }
}
