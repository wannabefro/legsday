import SpriteKit
import UIKit
import LegdaySim

/// The render/sync layer (KTD-4): feed the sim real dt, mirror its snapshot.
/// No gameplay lives here.
final class RunScene: SKScene {
    private var sim: RunSim!
    private var atlas = SpriteAtlas()
    private var lastUpdate: TimeInterval = 0
    private let draft: Draft?
    private let collection: [String: Int]
    private let seed: UInt64
    /// Called once when the run ends with its result (U20 routes to the
    /// obituary).
    let onRunEnded: (RunResult) -> Void
    private var didReportDeath = false

    /// A run built from a draft, or the sub-13 whole-collection path. Per-run
    /// seed makes a failed run replayable.
    init(draft: Draft?, collection: [String: Int], seed: UInt64,
         onRunEnded: @escaping (RunResult) -> Void) {
        self.draft = draft
        self.collection = collection
        self.seed = seed
        self.onRunEnded = onRunEnded
        super.init(size: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private let world = SKNode()      // foes, motes, hero
    private var floorNode: FloorNode!
    private var skyNode: SkyNode!
    private let featureNode = FeatureNode()
    private let gorgeWalls = GorgeWallNode()
    private let effects = SKNode()    // transient bolts/flashes
    private var heroNode: SKSpriteNode!
    private var fog: FogNode!
    private var hud: HudNode!
    private var cardLayer: CardVisual!
    private var chargeTrack: ChargeTrack!
    private var foePool: NodePool!
    private var motePool: NodePool!
    private var corpses: CorpseLayer!
    private let feelNode = SKNode()   // cloak + lantern, behind the hero
    private let cloakNode = SKShapeNode()
    private let lanternLine = SKShapeNode()
    private var lanternBob: SKSpriteNode!
    private let weaponNode = SKNode() // the chain weapon's rope (U16)
    private let ropeLine = SKShapeNode()
    private var ropeHead = SKSpriteNode()
    private lazy var reaper = ReaperNode(texture: atlas.reaper) // the duel's Reaper (U23)

    private let stageBanner = SKLabelNode(fontNamed: "Georgia-Bold")
    private var owningTouch: UITouch? // first touch owns the run (R1/U8)
    private var touchInput = TouchInputAccumulator()

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0x0F / 255.0, green: 0x0C / 255.0, blue: 0x0A / 255.0, alpha: 1)
        view.ignoresSiblingOrder = true
        scaleMode = .resizeFill
        anchorPoint = .zero

        sim = RunSim(tunables: try! Tunables.bundled(),
                     viewport: Vec2(size.width, size.height),
                     seed: seed,
                     catalog: try! CardCatalog.bundled(), // a run plays from cards.json (U10)
                     collection: collection,
                     draft: draft)

        physicsWorld.gravity = CGVector(dx: 0, dy: -9)   // corpse tumble only

        feelNode.zPosition = 9
        weaponNode.zPosition = 10
        world.zPosition = 10
        effects.zPosition = 12
        addChild(feelNode)
        addChild(world)
        addChild(effects)

        cloakNode.strokeColor = SKColor(red: 0.5, green: 0.42, blue: 0.32, alpha: 0.9)
        cloakNode.lineWidth = 2.5
        cloakNode.alpha = 0.55
        lanternLine.strokeColor = SpriteAtlas.rgb(0x241C12)
        lanternLine.lineWidth = 1
        lanternBob = SKSpriteNode(texture: atlas.lantern)
        lanternBob.size = CGSize(width: 7.8, height: 7.8)
        feelNode.addChild(cloakNode)
        feelNode.addChild(lanternLine)
        feelNode.addChild(lanternBob)

        // Chain weapon: a rust verlet rope; hidden until the chain is acquired.
        ropeLine.strokeColor = SKColor(red: 0.55, green: 0.38, blue: 0.26, alpha: 0.95)
        ropeLine.lineWidth = 3
        ropeHead = SKSpriteNode(texture: atlas.foe)
        ropeHead.color = SpriteAtlas.rgb(0xB23A2E)
        ropeHead.colorBlendFactor = 1
        weaponNode.addChild(ropeLine)
        weaponNode.addChild(ropeHead)
        weaponNode.isHidden = true
        addChild(weaponNode)

        reaper.zPosition = 13 // above world (10) and corpses (11), below card
        reaper.hide()
        addChild(reaper)

        floorNode = FloorNode(sceneSize: size)
        floorNode.zPosition = 1
        addChild(floorNode)
        gorgeWalls.zPosition = 2
        addChild(gorgeWalls)
        featureNode.zPosition = 3
        addChild(featureNode)
        skyNode = SkyNode(sceneSize: size)
        skyNode.zPosition = 14
        addChild(skyNode)

        heroNode = SKSpriteNode(texture: atlas.hero)
        world.addChild(heroNode)

        // Corpse debris tumbles in a dedicated layer between feel and world.
        let corpseNode = SKNode()
        corpseNode.zPosition = 11
        addChild(corpseNode)
        corpses = CorpseLayer(parent: corpseNode, texture: atlas.foe)

        foePool = NodePool(parent: world) { [atlas] in SKSpriteNode(texture: atlas.foe) }
        motePool = NodePool(parent: world) { [atlas] in SKSpriteNode(texture: atlas.mote) }

        fog = FogNode(width: size.width)
        fog.zPosition = 20
        addChild(fog)

        chargeTrack = ChargeTrack(sceneSize: size,
                                  safeBottom: view.safeAreaInsets.bottom,
                                  cornerTexture: atlas.cardCharge)
        chargeTrack.zPosition = 35
        addChild(chargeTrack)

        cardLayer = CardVisual()
        cardLayer.zPosition = 40
        addChild(cardLayer)

        hud = HudNode(sceneSize: size, safeTop: view.safeAreaInsets.top)
        hud.zPosition = 50
        addChild(hud)

        stageBanner.fontSize = 22
        stageBanner.fontColor = SpriteAtlas.rgb(0xC99A2E)
        stageBanner.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        stageBanner.alpha = 0
        stageBanner.zPosition = 55
        addChild(stageBanner)
    }

    /// Where the lantern arm sits in the drawing, and the body's own pivot.
    private static let rigArm = Vec2(0.121, 0.557)
    private static let rigPivot = Vec2(0.50, 0.42)
    private static let bodySize = Vec2(24, 26)
    private static let hemDrop: Double = 11

    /// sim y-down / origin top-left → scene y-up / origin bottom-left.
    private func pt(_ p: Vec2) -> CGPoint { CGPoint(x: p.x, y: size.height - p.y) }

    override func update(_ currentTime: TimeInterval) {
        guard sim != nil else { return }
        if lastUpdate == 0 { lastUpdate = currentTime }
        let dt = currentTime - lastUpdate
        lastUpdate = currentTime

        sim.tick(dt: dt, input: touchInput.current)
        touchInput.advance()
        syncRender()
        if sim.state.dead, !didReportDeath {
            didReportDeath = true
            onRunEnded(sim.result())
        }
    }

    // MARK: - Touch (first touch owns the run)

    private func simPoint(_ scene: CGPoint) -> Vec2 { Vec2(scene.x, size.height - scene.y) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard owningTouch == nil, let t = touches.first else { return }
        owningTouch = t
        touchInput.down(simPoint(t.location(in: self)))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = owningTouch, touches.contains(t) else { return }
        touchInput.move(simPoint(t.location(in: self)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = owningTouch, touches.contains(t) else { return }
        touchInput.up(simPoint(t.location(in: self)))
        owningTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = owningTouch, touches.contains(t) else { return }
        touchInput.cancel(simPoint(t.location(in: self)))
        owningTouch = nil
    }

    private func syncRender() {
        let s = sim.state

        floorNode.update(state: s, sceneSize: size)
        gorgeWalls.update(state: s, sceneSize: size)
        skyNode.update(state: s, sceneSize: size)
        featureNode.update(state: s)

        // The rig, not an animation set: heading, bank, hood glance, recoil kick.
        heroNode.position = pt(s.hero.pos + s.hero.recoil)
        heroNode.zRotation = CGFloat(-(s.hero.heading + s.hero.lean + s.hero.aim))
        heroNode.texture = s.heroInFog ? atlas.heroSubmerged : atlas.hero
        heroNode.alpha = (s.hero.invuln > 0 && Int(s.time * 18) % 2 == 0) ? 0.3 : 1
        let gait = 1 + 0.035 * sin(s.hero.stride * 6.283)
        heroNode.yScale = CGFloat(gait)
        heroNode.xScale = CGFloat(2 - gait)

        foePool.sync(s.foes, id: { $0.id }) { [atlas] foe, node in
            node.position = self.pt(foe.pos + foe.knock)
            node.texture = foe.elite ? atlas.elite : atlas.foe
            let sway = 0.09 * sin(foe.wobble)
            node.zRotation = CGFloat(foe.rotation - .pi / 2 + sway)
            node.setScale(foe.elite ? 1 : CGFloat(foe.radius / 9))
        }
        motePool.sync(s.motes, id: { $0.id }) { mote, node in
            node.position = self.pt(mote.pos)
        }

        // Cloak (verlet) + lantern (pendulum), in scene space.
        // Pinned at the rear hem, not the hood, so it trails its own body.
        let hemAngle = s.hero.heading + s.hero.lean
        let hem = s.hero.pos + s.hero.recoil
            + Vec2(-Self.hemDrop * sin(hemAngle), -Self.hemDrop * cos(hemAngle))
        let shift = hem - s.cloak.points[0]
        let cloakPath = CGMutablePath()
        cloakPath.move(to: pt(hem))
        for p in s.cloak.points.dropFirst() { cloakPath.addLine(to: pt(p + shift)) }
        cloakNode.path = cloakPath
        // The lantern hangs off the arm, so its mount turns with the body.
        // Rod is a tenth of the body. It is a grip, not a rope.
        let lanternLen = Self.bodySize.y * 0.10
        let bodyAngle = s.hero.heading + s.hero.lean
        let armX = (Self.rigArm.x - Self.rigPivot.x) * Self.bodySize.x
        let armY = (Self.rigArm.y - Self.rigPivot.y) * Self.bodySize.y
        let mount = s.hero.pos + s.hero.recoil
            + Vec2(armX * cos(bodyAngle) - armY * sin(bodyAngle),
                   armX * sin(bodyAngle) + armY * cos(bodyAngle))
        let bobSim = Vec2(mount.x + lanternLen * sin(s.lantern.angle),
                          mount.y + lanternLen * cos(s.lantern.angle))
        let bob = pt(bobSim), pivot = pt(mount)
        lanternBob.position = bob
        lanternBob.zRotation = CGFloat(-bodyAngle)
        let ll = CGMutablePath(); ll.move(to: pivot); ll.addLine(to: bob)
        lanternLine.path = ll

        // Chain weapon (U16): draw the rope when acquired; the head reads the
        // whip speed so a fast crack visibly brightens.
        if let rope = s.rope {
            weaponNode.isHidden = false
            let path = CGMutablePath()
            path.move(to: pt(rope.points[0]))
            for p in rope.points.dropFirst() { path.addLine(to: pt(p)) }
            ropeLine.path = path
            ropeHead.position = pt(rope.head)
            let intensity = min(1, rope.headSpeed / 1200)
            ropeHead.setScale(0.7 + 0.5 * CGFloat(intensity))
            ropeHead.alpha = 0.55 + 0.45 * CGFloat(intensity)
        } else {
            weaponNode.isHidden = true
        }

        // The Reaper duel (U23): silhouette decay + telegraphs while it runs.
        if let duel = s.duel {
            let topY = size.height - CGFloat(sim.fogLineY())
            reaper.update(duel: duel, fogTopY: topY, sceneSize: size)
        } else {
            reaper.hide()
        }

        // Fog: flat line + spring displacements, in scene space.
        let topY = size.height - CGFloat(sim.fogLineY())
        fog.update(topY: topY, heights: s.fogSurface.heights)
        corpses.cull(belowY: topY)

        for event in s.frameEvents { spawn(event) }

        cardLayer.update(card: s.card, offer: sim.currentOffer(), sceneSize: size)
        chargeTrack.update(charge: s.charge, need: s.essNeed, cardUp: s.card != nil)
        hud.update(essence: s.essence, fathoms: s.fathoms, felled: s.kills, mods: s.mods,
                   deck: DeckReading(deckSize: s.deckSource.count,
                                     remaining: s.deck.count,
                                     deathSize: sim.catalog.death.count,
                                     pastGate: sim.pastDeathGate),
                   stage: s.stage.name)
    }

    /// Cosmetic-only transient effects (SKAction is fine here — never gameplay).
    private func spawn(_ event: FrameEvent) {
        switch event {
        case let .attack(from, to):
            let a = pt(from), b = pt(to)
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: a); path.addLine(to: b)
            line.path = path
            line.strokeColor = SKColor(white: 0.9, alpha: 0.8)
            line.lineWidth = 2
            effects.addChild(line)
            line.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        case let .heroShoved(at):
            flash(at: pt(at), color: SKColor(white: 0.9, alpha: 0.9), radius: 20)
        case let .foeDown(at, elite):
            let p = pt(at)
            flash(at: p, color: SpriteAtlas.rgb(0xC99A2E), radius: elite ? 12 : 7)
            // Pop up and outward; gravity tumbles it down toward the fog splash.
            let dx = (p.x - size.width / 2) / size.width // −0.5…0.5
            corpses.spawn(at: p, elite: elite, impulse: CGVector(dx: dx * 6, dy: 4))
        case let .moteCollected(at):
            flash(at: pt(at), color: SpriteAtlas.rgb(0x8A6FB3), radius: 6)
        case .moteLost:
            break
        case let .cairnBroken(at):
            let p = pt(at)
            flash(at: p, color: SpriteAtlas.rgb(0x8C7A57), radius: 18)
            corpses.spawn(at: p, elite: false, impulse: CGVector(dx: 0, dy: 3))
        case let .stageEntered(stage):
            stageBanner.text = stage.name
            stageBanner.setScale(1)
            stageBanner.run(.sequence([
                .group([.fadeIn(withDuration: 0.15), .scale(to: 1.1, duration: 0.15)]),
                .wait(forDuration: 1.7),
                .fadeOut(withDuration: 0.4),
            ]))
        }
    }

    private func flash(at p: CGPoint, color: SKColor, radius: CGFloat) {
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = p
        node.strokeColor = color
        node.lineWidth = 3
        node.fillColor = .clear
        effects.addChild(node)
        node.run(.group([
            .scale(to: 2.4, duration: 0.18),
            .fadeOut(withDuration: 0.18),
        ]))
        node.run(.sequence([.wait(forDuration: 0.18), .removeFromParent()]))
    }
}
