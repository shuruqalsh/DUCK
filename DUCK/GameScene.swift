import SpriteKit
import AVFoundation

let arrowFloatAction = SKAction.repeatForever(
    SKAction.sequence([
        SKAction.moveBy(x: 0, y: 10, duration: 0.4),
        SKAction.moveBy(x: 0, y: -10, duration: 0.4)
    ])
)


class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var lastTouchLocation: CGPoint? // تخزين موقع اللمس الأخير
    var audioPlayer: AVAudioPlayer?
    var duck1: SKSpriteNode!
    var duck2: SKSpriteNode!
    var startButton: SKSpriteNode!
    var restartButton: SKSpriteNode!
    var muteButton: SKSpriteNode!
    
    var heartsDuck1: [SKSpriteNode] = []
    var heartsDuck2: [SKSpriteNode] = []
    
    var currentTurn = 1 // 1 for duck1, 2 for duck2
    var isHolding = false
    var launchPower: CGFloat = 0.0
    var maxPower: CGFloat = 800.0
    var backgroundMusic: SKAudioNode!
    var isMuted = false
    var touchStartTime: TimeInterval?
    var trajectoryLine: SKShapeNode!
    var powerBar: SKSpriteNode!
    
    var duck1Arrow: SKSpriteNode!
    var duck2Arrow: SKSpriteNode!

    // 🌟 Direction Meter
    var angleMeter: SKShapeNode!
    var fillAngle: CGFloat = 0.0
    let maxFillAngle: CGFloat = CGFloat.pi // 180 درجة (طول العداد)
    var fillTimer: Timer?
    
    var bubbleOutMessage: SKSpriteNode?

    
    var funnyMessageDuck1: SKSpriteNode!
    var funnyMessageDuck2: SKSpriteNode!


    
    struct PhysicsCategory {
        static let playerDuck: UInt32 = 1
        static let enemyDuck: UInt32 = 2
        static let bubble: UInt32 = 4
        static let wall: UInt32 = 8 // إضافة فئة الجدار
    }
    
    var turnArrow: SKSpriteNode! // سهم يشير للبطة الحالية
    
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        
        for family in UIFont.familyNames {
            for name in UIFont.fontNames(forFamilyName: family) {
                print(name)
            }
        }
        bubbleOutMessage = childNode(withName: "bubbleOutMessage") as? SKSpriteNode
        bubbleOutMessage?.isHidden = true

        
        
        funnyMessageDuck1 = childNode(withName: "funnyMessageDuck1") as? SKSpriteNode
        funnyMessageDuck2 = childNode(withName: "funnyMessageDuck2") as? SKSpriteNode

        funnyMessageDuck1.isHidden = true
        funnyMessageDuck2.isHidden = true



        duck1Arrow = childNode(withName: "duck1Arrow") as? SKSpriteNode
        duck2Arrow = childNode(withName: "duck2Arrow") as? SKSpriteNode
        // 🔻 اخفاء الأسهم مباشرة بعد تعريفها
        duck2Arrow?.isHidden = true
  
        duck1Arrow?.run(arrowFloatAction, withKey: "arrowFloat")
        duck2Arrow?.run(arrowFloatAction, withKey: "arrowFloat")


        duck1 = childNode(withName: "duck1") as? SKSpriteNode
        duck2 = childNode(withName: "duck2") as? SKSpriteNode
        startButton = childNode(withName: "startButton") as? SKSpriteNode
        restartButton = childNode(withName: "restartButton") as? SKSpriteNode
        muteButton = childNode(withName: "muteButton") as? SKSpriteNode
        
        heartsDuck1 = [
            childNode(withName: "duck1Heart1") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck1Heart2") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck1Heart3") as? SKSpriteNode ?? SKSpriteNode()
        ]
        
        heartsDuck2 = [
            childNode(withName: "duck2Heart1") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck2Heart2") as? SKSpriteNode ?? SKSpriteNode(),
            childNode(withName: "duck2Heart3") as? SKSpriteNode ?? SKSpriteNode()
        ]
        
        if let musicURL = Bundle.main.url(forResource: "game_music", withExtension: "mp3") {
            backgroundMusic = SKAudioNode(url: musicURL)
            backgroundMusic.autoplayLooped = true
            addChild(backgroundMusic)
        }
        setupPhysics()  // إعداد الفيزياء
        setupDucksPhysics()  // إعداد الفيزياء للبطات
        
        // ربط السهم
        
    
    }
    
    func showFunnyImageMessage(over duck: SKSpriteNode) {
        // اختار الصورة الصحيحة حسب البطة
        let messageNode = (duck == duck1) ? funnyMessageDuck1 : funnyMessageDuck2

        // حماية لو ما انربطت صح
        guard let message = messageNode else { return }

        // 🗺️ تحديد موقع الصورة حسب البطة
        if message == funnyMessageDuck1 {
            // موقع مخصص لرسالة Duck1 (تظهر فوقها، يمين شوي)
            message.position = CGPoint(
                x: duck.position.x - 50,
                y: duck.position.y + duck.size.height + 10
            )
        } else {
            // موقع مخصص لرسالة Duck2 (تظهر فوقها، يسار شوي)
            message.position = CGPoint(
                x: duck.position.x + 300,
                y: duck.position.y + duck.size.height - 20
            )
        }

        // 🔁 عكس الصورة إذا كانت فوق Duck2
        message.xScale = (duck == duck1) ? 1 : -1

        // ✨ إظهار الصورة
        message.isHidden = false
        message.alpha = 1.0

        // 💫 حركة bounce لطيفة
        message.setScale(0.9)
        let bounce = SKAction.sequence([
            SKAction.scale(to: 0.9, duration: 0.1),
            SKAction.scale(to: 0.8, duration: 0.1)
        ])
        message.run(bounce)

        // ⏳ مؤثر الإخفاء التدريجي
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let hide = SKAction.run {
            message.isHidden = true
            message.alpha = 1.0
        }
        message.run(SKAction.sequence([wait, fadeOut, hide]))
    }




    func setupPhysics() {  // إعداد حدود المشهد
        physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        physicsBody?.categoryBitMask = 0
        physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        physicsBody?.categoryBitMask = 0
        // إضافة جدار إلى المشهد
        let wall = SKNode()
        wall.physicsBody = SKPhysicsBody(edgeLoopFrom: self.frame)
        wall.physicsBody?.categoryBitMask = PhysicsCategory.wall
        wall.physicsBody?.isDynamic = false  // جدار ثابت لا يتحرك
        addChild(wall)
    }
    
    func setupDucksPhysics() {
        // تعيين الجسم الفيزيائي للبط الأول
        duck1.physicsBody = SKPhysicsBody(rectangleOf: duck1.size)
            duck1.physicsBody?.categoryBitMask = PhysicsCategory.playerDuck
            duck1.physicsBody?.collisionBitMask = PhysicsCategory.bubble | PhysicsCategory.wall
            duck1.physicsBody?.contactTestBitMask = PhysicsCategory.bubble
            duck1.physicsBody?.isDynamic = true
        // ⭐️ تثبيت البطة
           duck1.physicsBody?.mass = 9999
           duck1.physicsBody?.affectedByGravity = false
           duck1.physicsBody?.allowsRotation = false
        duck1.physicsBody?.isDynamic = false

        
        // تعيين الجسم الفيزيائي للبط الثاني
        duck2.physicsBody = SKPhysicsBody(rectangleOf: duck2.size)
          duck2.physicsBody?.categoryBitMask = PhysicsCategory.enemyDuck
          duck2.physicsBody?.collisionBitMask = PhysicsCategory.bubble | PhysicsCategory.wall
          duck2.physicsBody?.contactTestBitMask = PhysicsCategory.bubble
          duck2.physicsBody?.isDynamic = true
        // ⭐️ تثبيت البطة
           duck2.physicsBody?.mass = 9999
           duck2.physicsBody?.affectedByGravity = false
           duck2.physicsBody?.allowsRotation = false
        duck2.physicsBody?.isDynamic = false

    }

 

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            lastTouchLocation = touch.location(in: self)
            let location = lastTouchLocation!
            
            if startButton.contains(location) {
                startButton.isHidden = true
                // إظهار السهم فوق البطة الأولى عند بداية اللعبة
                turnArrow?.isHidden = false
                run(SKAction.playSoundFileNamed("button_click.mp3", waitForCompletion: false))
                return
            }
            if restartButton.contains(location) {
                restartGame()
                run(SKAction.playSoundFileNamed("button_click.mp3", waitForCompletion: false))
                return
            }
            if muteButton.contains(location) {
                toggleMute()
                run(SKAction.playSoundFileNamed("button_click.mp3", waitForCompletion: false))
                return
            }
            if (currentTurn == 1 && duck1.contains(location)) || (currentTurn == 2 && duck2.contains(location)) {
                isHolding = true
                             fillAngle = 0.0
                             addAngleMeter()
                             startFillingMeter()
                run(SKAction.playSoundFileNamed("hold.mp3", waitForCompletion: false))
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isHolding, let touch = touches.first {
            lastTouchLocation = touch.location(in: self)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isHolding {
            stopFillingMeter()
            launchPower = maxPower * 0.4
            shootBubble()
            angleMeter.removeFromParent()
            isHolding = false
            
            // إيقاف أنيميشن البطة الحالية
            if currentTurn == 1 {
                duck1.removeAllActions()
            } else {
                duck2.removeAllActions()
            }
            
            switchTurn()
        }
    }
    
    func addAngleMeter() {
        angleMeter = SKShapeNode()

        // نفس المسار من فوق الرأس
        let radius: CGFloat = 60
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + fillAngle

        let path = UIBezierPath(arcCenter: .zero,
                                radius: radius,
                                startAngle: startAngle,
                                endAngle: endAngle,
                                clockwise: true)

        angleMeter.path = path.cgPath
        angleMeter.strokeColor = UIColor(hex: "#FFF139")
        angleMeter.lineWidth = 15
        angleMeter.lineCap = .round

        // تحديد موقع العداد فوق البطة
        let basePosition = currentTurn == 1 ? duck1.position : duck2.position
        angleMeter.position = CGPoint(x: basePosition.x, y: basePosition.y + 120)

        // 🪞✨ هنا الانعكاس المهم للبطة الثانية
        angleMeter.xScale = currentTurn == 1 ? 1 : -1

        addChild(angleMeter)
    }



    func startFillingMeter() {
        fillTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            self.fillAngle += 0.05
            if self.fillAngle >= self.maxFillAngle {
                self.fillAngle = self.maxFillAngle
            }
            let path = UIBezierPath(arcCenter: .zero, radius: 60, startAngle: 0, endAngle: self.fillAngle, clockwise: true)
            self.angleMeter.path = path.cgPath
        }
    }

    func stopFillingMeter() {
        fillTimer?.invalidate()
        fillTimer = nil
    }
    

    func showBubbleOutMessage() {
        let targetDuck = (currentTurn == 1) ? duck2 : duck1
        guard let targetDuck = (currentTurn == 1 ? duck2 : duck1),
              let bubbleOut = bubbleOutMessage else { return }
        bubbleOut.position = CGPoint(
            x: targetDuck.position.x,
            y: targetDuck.position.y + targetDuck.size.height + 20
        )


        bubbleOut.position = CGPoint(x: targetDuck.position.x, y: targetDuck.position.y + targetDuck.size.height + 20)
        bubbleOut.isHidden = false
        bubbleOut.alpha = 1.0

        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let hide = SKAction.run {
            bubbleOut.isHidden = true
            bubbleOut.alpha = 1.0
        }

        bubbleOut.run(SKAction.sequence([wait, fadeOut, hide]))
    }

    func shootBubble() {
        let startPosition = currentTurn == 1 ? duck1.position : duck2.position
        let currentDuck = currentTurn == 1 ? duck1! : duck2!  // استخدام force unwrap لأننا متأكدون من وجود البطة
        let offset: CGFloat = 40
        let bubbleStartPosition = CGPoint(x: startPosition.x, y: startPosition.y + currentDuck.size.height / 2 + offset)
        
        let bubble = SKSpriteNode(imageNamed: "bubble")
        bubble.size = CGSize(width: 50, height: 50)
        bubble.position = bubbleStartPosition

        bubble.physicsBody = SKPhysicsBody(circleOfRadius: bubble.size.width / 2)
        bubble.physicsBody?.categoryBitMask = PhysicsCategory.bubble

        // ⭐️ تمنع التصادم مع البطة اللي أطلق الفقاعة
        if currentTurn == 1 {
            bubble.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.enemyDuck
            bubble.physicsBody?.contactTestBitMask = PhysicsCategory.enemyDuck | PhysicsCategory.wall
        } else {
            bubble.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.playerDuck
            bubble.physicsBody?.contactTestBitMask = PhysicsCategory.playerDuck | PhysicsCategory.wall
        }

        bubble.physicsBody?.isDynamic = true
        bubble.physicsBody?.affectedByGravity = true
        bubble.physicsBody?.linearDamping = 0.1
        bubble.physicsBody?.angularDamping = 0.1
        bubble.physicsBody?.restitution = 0.1
        bubble.name = "bubble"

        addChild(bubble)

        // ⭐️ نحفظ من أطلق الفقاعة لتجاهل الضرر لاحقًا
        bubble.userData = NSMutableDictionary()
        bubble.userData?.setValue(currentTurn, forKey: "owner")

        // 🟣 زاوية ثابتة للقذف (مثلاً 60° أو 120° حسب البطة)
        let fixedAngleDegrees: CGFloat = currentTurn == 2 ? 60 : 120
        let fixedAngle = fixedAngleDegrees * .pi / 180

        // 🟣 قوة الرمية تعتمد على مدى امتلاء العداد فقط
        let normalizedPower = fillAngle / maxFillAngle
        let power = normalizedPower * maxPower * 0.4

        let velocityX = power * cos(fixedAngle)
        let velocityY = power * sin(fixedAngle)

        bubble.physicsBody?.applyImpulse(CGVector(dx: velocityX, dy: velocityY))
        if power > 170 {
            // فقط لو الخصم هو اللي يضحك، مو نفس البطة
            if let observerDuck = (currentTurn == 1 ? duck2 : duck1) {
                showFunnyImageMessage(over: observerDuck)
            }


        }


    }



    func didBegin(_ contact: SKPhysicsContact) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        
        if bodyA.categoryBitMask == PhysicsCategory.bubble && bodyB.categoryBitMask == PhysicsCategory.enemyDuck {
            handleBubbleHitDuck(bubble: bodyA.node as? SKSpriteNode, duck: bodyB.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
        } else if bodyB.categoryBitMask == PhysicsCategory.bubble && bodyA.categoryBitMask == PhysicsCategory.enemyDuck {
            handleBubbleHitDuck(bubble: bodyB.node as? SKSpriteNode, duck: bodyA.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
        } else if bodyA.categoryBitMask == PhysicsCategory.bubble && bodyB.categoryBitMask == PhysicsCategory.playerDuck {
            handleBubbleHitDuck(bubble: bodyA.node as? SKSpriteNode, duck: bodyB.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
        } else if bodyB.categoryBitMask == PhysicsCategory.bubble && bodyA.categoryBitMask == PhysicsCategory.playerDuck {
            handleBubbleHitDuck(bubble: bodyB.node as? SKSpriteNode, duck: bodyA.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالبطة
        } else if bodyA.categoryBitMask == PhysicsCategory.bubble && bodyB.categoryBitMask == PhysicsCategory.wall {
            handleBubbleHitWall(bubble: bodyA.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالجدار
        } else if bodyB.categoryBitMask == PhysicsCategory.bubble && bodyA.categoryBitMask == PhysicsCategory.wall {
            handleBubbleHitWall(bubble: bodyB.node as? SKSpriteNode)
            // إضافة الأصوات عند الاصطدام بالجدار
        }
    }

    func playBubblePopAndCollisionSound() {
        // الصوت الأول: bubble_pop.mp3
        let soundAction1 = SKAction.playSoundFileNamed("bubble_pop.mp3", waitForCompletion: false)
        
        // الصوت الثاني: collision_sound_2.mp3
        let soundAction2 = SKAction.playSoundFileNamed("collision_sound_2.mp3", waitForCompletion: false)
        
        
        // إضافة الصوتين كإجراءات متتالية مع التأخير
        let groupAction = SKAction.group([soundAction1, soundAction2])
        run(groupAction)
    }

    func handleBubbleHitDuck(bubble: SKSpriteNode?, duck: SKSpriteNode?) {
        guard let bubble = bubble, let duck = duck else { return }

        if let owner = bubble.userData?.value(forKey: "owner") as? Int {
            if (owner == 1 && duck == duck1) || (owner == 2 && duck == duck2) {
                return
            }
        }

        playBubblePopAndCollisionSound()
        bubble.removeFromParent()

        // إيقاف جميع الأنيميشنات والتأثيرات الحالية
        duck.removeAllActions()
        
        // إعادة تعيين لون البطة قبل بدء التأثير الجديد
        duck.color = .white
        duck.colorBlendFactor = 0.0
        
        // تأثير الوميض الأحمر فقط (بدون تكبير)
        let flashRed = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.7, duration: 0.1),
            SKAction.wait(forDuration: 0.1),
            SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.1)
        ])
        
        // تشغيل تأثير الضربة
        duck.run(flashRed) { [weak duck] in
            // بعد انتهاء تأثير الضربة، نتحقق إذا كانت البطة لا تزال في دورها
            if let duck = duck {
                if (duck == self.duck1 && self.currentTurn == 1) ||
                   (duck == self.duck2 && self.currentTurn == 2) {
                    self.startDuckAnimation(duck: duck)
                }
            }
        }

        if duck == duck1 {
            removeHeart(from: &heartsDuck1)
        } else {
            removeHeart(from: &heartsDuck2)
        }
    }

    func handleBubbleHitWall(bubble: SKSpriteNode?) {
        bubble?.removeFromParent()
        run(SKAction.playSoundFileNamed("bubble_pop.mp3", waitForCompletion: false)) // نفس الصوت عند الاصطدام بالجدار
    }

    func switchTurn() {
        // إعادة تعيين البطة الحالية
        if currentTurn == 1 {
            resetDuck(duck1)
        } else {
            resetDuck(duck2)
        }
        if currentTurn == 1 {
            duck1Arrow.isHidden = false
            duck2Arrow.isHidden = true

            duck1Arrow.removeAllActions()
            let floatUp = SKAction.moveBy(x: 0, y: 10, duration: 0.4)
            let floatDown = SKAction.moveBy(x: 0, y: -10, duration: 0.4)
            let floatSequence = SKAction.sequence([floatUp, floatDown])
            let floatForever = SKAction.repeatForever(floatSequence)
            duck1Arrow.run(floatForever)

        } else {
            duck1Arrow.isHidden = true
            duck2Arrow.isHidden = false

            duck2Arrow.removeAllActions()
            let floatUp = SKAction.moveBy(x: 0, y: 10, duration: 0.4)
            let floatDown = SKAction.moveBy(x: 0, y: -10, duration: 0.4)
            let floatSequence = SKAction.sequence([floatUp, floatDown])
            let floatForever = SKAction.repeatForever(floatSequence)
            duck2Arrow.run(floatForever)
        }
        // تغيير الدور
        currentTurn = (currentTurn == 1) ? 2 : 1
        duck1Arrow.isHidden = currentTurn != 1
        duck2Arrow.isHidden = currentTurn != 2

        
        // تحديث موقع السهم
        if let arrow = turnArrow {
            // تحديد الموقع الجديد
            arrow.position = currentTurn == 1 ?
                CGPoint(x: duck1.position.x, y: duck1.position.y + 100) :
                CGPoint(x: duck2.position.x, y: duck2.position.y + 100)
        }
        
        // بدء أنيميشن البطة الجديدة
        if currentTurn == 1 {
            startDuckAnimation(duck: duck1)
        } else {
            startDuckAnimation(duck: duck2)
        }
    }

    
    func restartGame() {
        if let scene = SKScene(fileNamed: "GameScene") {
            scene.scaleMode = .aspectFill
            
            // إعادة تعيين موقع السهم للبطة الأولى
            if let arrow = turnArrow {
                arrow.position = CGPoint(x: duck1.position.x, y: duck1.position.y + 100)
            }
            
            view?.presentScene(scene, transition: SKTransition.fade(withDuration: 0.5))
        }
    }

    func endGame() {
        let gameOverLabel = SKLabelNode()

        gameOverLabel.text = "انتهت المعركة!"
        gameOverLabel.fontName = "TabshoorDemo" // <-- اسم الخط

        gameOverLabel.fontSize = 50
        gameOverLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        addChild(gameOverLabel)

        restartButton.isHidden = false
        restartButton.zPosition = 1  // تأكد من أنه في المقدمة

        playVictorySound()
    }


    func playVictorySound() {
        // تشغيل الصوت عند الفوز (يمكنك تعديل مسار الصوت هنا)
        run(SKAction.playSoundFileNamed("win_sound.mp3", waitForCompletion: false))
    }
    func removeHeart(from hearts: inout [SKSpriteNode]) {
        if let lastHeart = hearts.popLast() {
            print("Heart removed")
            lastHeart.removeFromParent()
        }
        if hearts.isEmpty {
            print("Game Over")
            endGame()
        }
    }
    func startDuckAnimation(duck: SKSpriteNode) {
        // إيقاف الأنيميشن الحالي
        duck.removeAllActions()
        
        // إعادة تعيين الحجم واللون
        duck.color = .white
        duck.colorBlendFactor = 0.0
        
        if (duck == duck1 && currentTurn == 1) || (duck == duck2 && currentTurn == 2) {
            var animationTextures: [SKTexture]
            
            if duck == duck1 {
                animationTextures = [
                    SKTexture(imageNamed: "duck1Turn1"),
                    SKTexture(imageNamed: "duck1Turn2"),
                ]
            } else {
                animationTextures = [
                    SKTexture(imageNamed: "duck2Turn1"),
                    SKTexture(imageNamed: "duck2Turn2"),
                ]
            }

            let animationAction = SKAction.animate(with: animationTextures, timePerFrame: 0.2)
            let repeatAction = SKAction.repeatForever(animationAction)
            
            duck.run(repeatAction, withKey: "duckAnimation")
        }
    }

    // إضافة دالة لإعادة تعيين البطة عند تبديل الدور
    func resetDuck(_ duck: SKSpriteNode) {
        duck.removeAllActions()
        duck.color = .white
        duck.colorBlendFactor = 0.0
    }

    func toggleMute() {
        if isMuted {
            backgroundMusic.run(SKAction.stop())
            isMuted = false
        } else {
            backgroundMusic.run(SKAction.play())
            isMuted = true
        }
    }
    func playShortenedSoundWithAVPlayer() {
        if let path = Bundle.main.path(forResource: "collision_sound_2.mp3", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                
                // تحديد فترة تشغيل الصوت (مثلاً، 1 ثانية)
                audioPlayer?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // توقيف الصوت بعد 1 ثانية
                    self.audioPlayer?.stop()
                }
            } catch {
                print("Error loading audio file")
            }
        }
    }

    func resetDuckAppearance() {
        // إعادة تعيين مظهر البطة الأولى
        duck1.removeAllActions()
        duck1.color = .white
        duck1.colorBlendFactor = 0.0
        
        // إعادة تعيين مظهر البطة الثانية
        duck2.removeAllActions()
        duck2.color = .white
        duck2.colorBlendFactor = 0.0
    }
}
