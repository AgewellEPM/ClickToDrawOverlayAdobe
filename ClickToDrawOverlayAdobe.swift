import Cocoa
import CoreGraphics
import UniformTypeIdentifiers
import QuartzCore
import ScreenCaptureKit

// Extension for NSBezierPath to CGPath conversion
extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}

// Google/Apple Hybrid: Custom button with smooth hover animations
class PremiumToolButton: NSButton {
    var buttonIndex: Int = 0
    var isHovered: Bool = false
    var isActiveTool: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTracking()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }
    
    private func setupTracking() {
        let trackingArea = NSTrackingArea(rect: bounds, 
                                        options: [.activeInKeyWindow, .mouseEnteredAndExited], 
                                        owner: self, 
                                        userInfo: nil)
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isActiveTool {
            isHovered = true
            animateHoverIn()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isActiveTool {
            isHovered = false
            animateHoverOut()
        }
    }
    
    private func animateHoverIn() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        
        // Material Design hover elevation
        layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 0.98).cgColor
        layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 0.6).cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowRadius = 4
        layer?.shadowOffset = NSSize(width: 0, height: 2)
        
        // Subtle scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.02
        scaleAnimation.duration = 0.2
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        layer?.add(scaleAnimation, forKey: "hoverScale")
        
        CATransaction.commit()
    }
    
    private func animateHoverOut() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        // Return to resting state
        layer?.backgroundColor = NSColor(calibratedRed: 0.19, green: 0.19, blue: 0.19, alpha: 0.95).cgColor
        layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
        layer?.shadowOpacity = 0.12
        layer?.shadowRadius = 3
        layer?.shadowOffset = NSSize(width: 0, height: 1)
        
        // Scale back to normal
        layer?.removeAnimation(forKey: "hoverScale")
        layer?.transform = CATransform3DIdentity
        
        CATransaction.commit()
    }
}

enum DrawingTool: Int, CaseIterable {
    case rectangle = 0, ellipse, line, text, arrow, pen, cut
}

enum DrawingAction {
    case shape(CAShapeLayer)
    case cutImage(CutImage)
    case text(CATextLayer)
}

class CutImage {
    var image: NSImage
    var position: NSPoint
    var size: NSSize
    var layer: CALayer
    var isSelected: Bool = false
    
    init(image: NSImage, position: NSPoint, size: NSSize) {
        self.image = image
        self.position = position
        self.size = size
        self.layer = CALayer()
        self.layer.contents = image
        self.layer.frame = NSRect(origin: position, size: size)
        self.layer.contentsGravity = .resizeAspect
    }
    
    func updatePosition(_ newPosition: NSPoint) {
        position = newPosition
        layer.frame = NSRect(origin: position, size: size)
    }
    
    func setSelected(_ selected: Bool) {
        isSelected = selected
        layer.borderWidth = selected ? 2.0 : 0.0
        layer.borderColor = selected ? NSColor.systemBlue.cgColor : nil
    }
}

class ClickToDrawOverlay: NSObject, NSApplicationDelegate {
    var toolPanel: NSPanel?
    var overlayWindow: NSWindow?
    var currentTool: DrawingTool? = .rectangle
    var currentColor: NSColor = .black
    var fillColor: NSColor = .white
    var currentLineWidth: CGFloat = 3.0
    var isActive: Bool = false
    var isDrawing: Bool = false
    var startPoint: NSPoint = NSZeroPoint
    var currentShapeLayers: [CALayer] = []
    var drawingView: NSView?
    var isCutMode: Bool = false
    var cutImages: [CutImage] = []
    var selectedCutImage: CutImage?
    var drawingLayers: [CAShapeLayer] = []
    var currentPath: NSBezierPath?
    var undoStack: [DrawingAction] = []
    var redoStack: [DrawingAction] = []
    var showGrid: Bool = false
    var gridSize: CGFloat = 20.0
    var snapToGrid: Bool = false
    var gridLayer: CAShapeLayer?
    var currentZoomLevel: CGFloat = 1.0
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupToolPanel()
    }
    
    private func setupToolPanel() {
        // Google/Apple Hybrid: Perfect proportions with premium polish - Extended to prevent cutoff
        let panelRect = NSRect(x: 50, y: 50, width: 80, height: 720)
        toolPanel = NSPanel(contentRect: panelRect,
                           styleMask: [.nonactivatingPanel, .utilityWindow],
                           backing: .buffered,
                           defer: false)
        toolPanel?.level = NSWindow.Level.screenSaver + 1  // Always above overlay
        toolPanel?.backgroundColor = NSColor.clear
        toolPanel?.title = ""
        toolPanel?.hasShadow = true
        toolPanel?.isMovableByWindowBackground = true
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 720))
        contentView.wantsLayer = true
        
        // Material Design + Apple polish: Elevated surface with perfect shadows
        contentView.layer?.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.07, alpha: 0.98).cgColor
        contentView.layer?.cornerRadius = 12
        contentView.layer?.borderWidth = 0.5
        contentView.layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 0.3).cgColor
        
        // Add premium shadow effects
        contentView.layer?.shadowColor = NSColor.black.cgColor
        contentView.layer?.shadowOpacity = 0.25
        contentView.layer?.shadowOffset = NSSize(width: 0, height: -2)
        contentView.layer?.shadowRadius = 8
        
        toolPanel?.contentView = contentView
        
        // Clean, modern tool icons
        let modernIcons = ["▢", "○", "╱", "A", "→", "✎", "✂"]
        let toolNames = ["Rectangle", "Circle", "Line", "Text", "Arrow", "Pen", "Cut"]
        
        // Calculate even distribution throughout toolbar height - adjusted for 720px panel
        let toolbarStartY: CGFloat = 650  // Start near top of 720px panel
        let toolbarEndY: CGFloat = 180    // End with plenty of space for bottom controls
        let availableHeight = toolbarStartY - toolbarEndY
        let spacing = availableHeight / CGFloat(DrawingTool.allCases.count - 1)
        
        // Google Material + Apple HIG: Perfectly polished tool buttons with even spacing
        for (index, _) in DrawingTool.allCases.enumerated() {
            let y = toolbarStartY - CGFloat(index) * spacing
            
            let button = PremiumToolButton(frame: NSRect(x: 10, y: y, width: 60, height: 56))
            button.buttonIndex = index
            button.isActiveTool = (index == currentTool?.rawValue)
            button.title = ""
            button.target = self
            button.action = #selector(toolSelected(_:))
            button.tag = index
            button.wantsLayer = true
            button.isBordered = false
            button.toolTip = "\(toolNames[index]) (Shortcut: \(index == 0 ? "R" : index == 1 ? "C" : index == 2 ? "L" : index == 3 ? "T" : index == 4 ? "↑" : index == 5 ? "P" : "X"))"
            
            // Material Design elevated surfaces with Apple refinement
            button.layer?.cornerRadius = 12
            button.layer?.masksToBounds = false
            
            if index == currentTool?.rawValue {
                // Google accent colors with Apple polish
                button.layer?.backgroundColor = NSColor(calibratedRed: 0.26, green: 0.47, blue: 0.88, alpha: 1.0).cgColor
                button.layer?.borderWidth = 1.5
                button.layer?.borderColor = NSColor(calibratedRed: 0.36, green: 0.57, blue: 0.98, alpha: 0.9).cgColor
                
                // Premium shadow for selected state
                button.layer?.shadowColor = NSColor(calibratedRed: 0.26, green: 0.47, blue: 0.88, alpha: 0.4).cgColor
                button.layer?.shadowOpacity = 0.4
                button.layer?.shadowOffset = NSSize(width: 0, height: 2)
                button.layer?.shadowRadius = 6
                
                // Subtle glow animation for active tool
                let glowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                glowAnimation.fromValue = 0.4
                glowAnimation.toValue = 0.2
                glowAnimation.duration = 2.0
                glowAnimation.autoreverses = true
                glowAnimation.repeatCount = Float.infinity
                button.layer?.add(glowAnimation, forKey: "activeGlow")
            } else {
                // Material Design resting state
                button.layer?.backgroundColor = NSColor(calibratedRed: 0.19, green: 0.19, blue: 0.19, alpha: 0.95).cgColor
                button.layer?.borderWidth = 0.5
                button.layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
                
                // Subtle depth shadow
                button.layer?.shadowColor = NSColor.black.cgColor
                button.layer?.shadowOpacity = 0.12
                button.layer?.shadowOffset = NSSize(width: 0, height: 1)
                button.layer?.shadowRadius = 3
            }
            
            // PremiumToolButton handles hover animations automatically
            
            // Perfectly centered icons with premium typography
            let iconLabel = NSTextField(frame: NSRect(x: 0, y: 18, width: 60, height: 24))
            iconLabel.stringValue = modernIcons[index]
            iconLabel.isEditable = false
            iconLabel.isBezeled = false
            iconLabel.drawsBackground = false
            iconLabel.alignment = .center
            iconLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
            iconLabel.textColor = index == currentTool?.rawValue ? 
                NSColor.white : 
                NSColor(calibratedRed: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
            iconLabel.isSelectable = false
            iconLabel.allowsEditingTextAttributes = false
            button.addSubview(iconLabel)
            
            // Tool name label underneath
            let nameLabel = NSTextField(frame: NSRect(x: 0, y: 8, width: 64, height: 16))
            nameLabel.stringValue = toolNames[index]
            nameLabel.isEditable = false
            nameLabel.isBezeled = false
            nameLabel.drawsBackground = false
            nameLabel.alignment = .center
            nameLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
            nameLabel.textColor = index == currentTool?.rawValue ? 
                NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.95) : 
                NSColor(calibratedRed: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)
            nameLabel.isSelectable = false
            button.addSubview(nameLabel)
            
            contentView.addSubview(button)
        }
        
        // SIMPLIFIED BOTTOM LAYOUT - Exactly as requested
        // 1. Full-width start button at the very bottom
        let startButton = NSButton(frame: NSRect(x: 5, y: 5, width: 70, height: 30))
        startButton.title = "START"
        startButton.target = self
        startButton.action = #selector(toggleDrawingMode)
        startButton.wantsLayer = true
        startButton.isBordered = false
        startButton.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.5, blue: 0.9, alpha: 1.0).cgColor
        startButton.layer?.borderWidth = 1
        startButton.layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        startButton.layer?.cornerRadius = 4
        startButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        startButton.contentTintColor = NSColor.white
        startButton.toolTip = "Toggle Drawing Mode"
        contentView.addSubview(startButton)
        
        // 2. Two boxes above the start button - Grid and Artboard
        // Grid control box
        let gridButton = NSButton(frame: NSRect(x: 5, y: 40, width: 35, height: 30))
        gridButton.title = ""
        gridButton.target = self
        gridButton.action = #selector(toggleGrid)
        gridButton.wantsLayer = true
        gridButton.isBordered = false
        gridButton.toolTip = "Toggle Grid (G)"
        
        if showGrid {
            gridButton.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.5, blue: 0.9, alpha: 1.0).cgColor
            gridButton.layer?.borderWidth = 1
            gridButton.layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        } else {
            gridButton.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 0.8).cgColor
            gridButton.layer?.borderWidth = 0.5
            gridButton.layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
        }
        gridButton.layer?.cornerRadius = 3
        
        let gridIcon = NSTextField(frame: NSRect(x: 0, y: 7, width: 35, height: 16))
        gridIcon.stringValue = "⊞"
        gridIcon.isBezeled = false
        gridIcon.isEditable = false
        gridIcon.drawsBackground = false
        gridIcon.font = NSFont.systemFont(ofSize: 16)
        gridIcon.alignment = .center
        gridIcon.textColor = showGrid ? NSColor.white : NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        gridIcon.isSelectable = false
        gridButton.addSubview(gridIcon)
        contentView.addSubview(gridButton)
        
        // Artboard control box
        let artboardButton = NSButton(frame: NSRect(x: 40, y: 40, width: 35, height: 30))
        artboardButton.title = ""
        artboardButton.target = self
        artboardButton.action = #selector(toggleArtboard)
        artboardButton.wantsLayer = true
        artboardButton.isBordered = false
        artboardButton.toolTip = "Toggle Artboard"
        
        artboardButton.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 0.8).cgColor
        artboardButton.layer?.borderWidth = 0.5
        artboardButton.layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
        artboardButton.layer?.cornerRadius = 3
        
        let artboardIcon = NSTextField(frame: NSRect(x: 0, y: 7, width: 35, height: 16))
        artboardIcon.stringValue = "▢"
        artboardIcon.isBezeled = false
        artboardIcon.isEditable = false
        artboardIcon.drawsBackground = false
        artboardIcon.font = NSFont.systemFont(ofSize: 16)
        artboardIcon.alignment = .center
        artboardIcon.textColor = NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        artboardIcon.isSelectable = false
        artboardButton.addSubview(artboardIcon)
        contentView.addSubview(artboardButton)
        
        // ADOBE-STYLE COLOR BLOCKS - Above the grid/artboard buttons
        let colorYPos = 75
        
        // Line Color Block (foreground)
        let lineColorButton = NSButton(frame: NSRect(x: 5, y: colorYPos, width: 35, height: 35))
        lineColorButton.wantsLayer = true
        lineColorButton.isBordered = false
        lineColorButton.layer?.backgroundColor = currentColor.cgColor
        lineColorButton.layer?.borderWidth = 2
        lineColorButton.layer?.borderColor = NSColor.white.cgColor
        lineColorButton.layer?.cornerRadius = 4
        lineColorButton.target = self
        lineColorButton.action = #selector(selectLineColor)
        lineColorButton.toolTip = "Line Color (Click for Color Picker)"
        contentView.addSubview(lineColorButton)
        
        // Fill/Shading Color Block (background)
        let fillColorButton = NSButton(frame: NSRect(x: 40, y: colorYPos, width: 35, height: 35))
        fillColorButton.wantsLayer = true
        fillColorButton.isBordered = false
        fillColorButton.title = "" // Explicitly set empty title
        fillColorButton.layer?.backgroundColor = fillColor.cgColor
        fillColorButton.layer?.borderWidth = 1
        fillColorButton.layer?.borderColor = NSColor.gray.cgColor
        fillColorButton.layer?.cornerRadius = 4
        fillColorButton.target = self
        fillColorButton.action = #selector(selectFillColor)
        fillColorButton.toolTip = "Fill/Shading Color (Click for Color Picker)"
        contentView.addSubview(fillColorButton)
        
        // ZOOM CONTROLS - Above the color blocks
        let zoomYPos = 120
        
        // Zoom In button
        let zoomInButton = NSButton(frame: NSRect(x: 5, y: zoomYPos, width: 35, height: 25))
        zoomInButton.title = "+"
        zoomInButton.target = self
        zoomInButton.action = #selector(zoomIn)
        zoomInButton.wantsLayer = true
        zoomInButton.isBordered = false
        zoomInButton.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 0.8).cgColor
        zoomInButton.layer?.borderWidth = 0.5
        zoomInButton.layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
        zoomInButton.layer?.cornerRadius = 3
        zoomInButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        zoomInButton.contentTintColor = NSColor.white
        zoomInButton.toolTip = "Zoom In (+)"
        contentView.addSubview(zoomInButton)
        
        // Zoom Out button
        let zoomOutButton = NSButton(frame: NSRect(x: 40, y: zoomYPos, width: 35, height: 25))
        zoomOutButton.title = "−"
        zoomOutButton.target = self
        zoomOutButton.action = #selector(zoomOut)
        zoomOutButton.wantsLayer = true
        zoomOutButton.isBordered = false
        zoomOutButton.layer?.backgroundColor = NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.22, alpha: 0.8).cgColor
        zoomOutButton.layer?.borderWidth = 0.5
        zoomOutButton.layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
        zoomOutButton.layer?.cornerRadius = 3
        zoomOutButton.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        zoomOutButton.contentTintColor = NSColor.white
        zoomOutButton.toolTip = "Zoom Out (-)"
        contentView.addSubview(zoomOutButton)
        
        // Keep the control button but hide it (for compatibility)
        let controlButton = NSButton(frame: NSRect(x: 8, y: -100, width: 32, height: 20))
        controlButton.title = ""
        controlButton.target = self
        controlButton.action = #selector(toggleDrawingMode)
        controlButton.wantsLayer = true
        controlButton.isBordered = false
        controlButton.toolTip = isActive ? "Stop Drawing" : "Start Drawing"
        
        // Clean button styling
        if isActive {
            controlButton.layer?.backgroundColor = NSColor(calibratedRed: 0.8, green: 0.3, blue: 0.3, alpha: 1.0).cgColor
            controlButton.layer?.borderWidth = 1
            controlButton.layer?.borderColor = NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.4, alpha: 1.0).cgColor
        } else {
            controlButton.layer?.backgroundColor = NSColor(calibratedRed: 0.2, green: 0.6, blue: 0.3, alpha: 1.0).cgColor
            controlButton.layer?.borderWidth = 1
            controlButton.layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.4, alpha: 1.0).cgColor
        }
        controlButton.layer?.cornerRadius = 3
        
        // Clean control icon
        let controlIcon = NSTextField(frame: NSRect(x: 0, y: 2, width: 32, height: 16))
        controlIcon.stringValue = isActive ? "■" : "▶"
        controlIcon.isEditable = false
        controlIcon.isBezeled = false
        controlIcon.drawsBackground = false
        controlIcon.alignment = .center
        controlIcon.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        controlIcon.textColor = NSColor.white
        controlIcon.isSelectable = false
        controlButton.addSubview(controlIcon)
        
        // Control label
        let controlLabel = NSTextField(frame: NSRect(x: 0, y: 2, width: 64, height: 14))
        controlLabel.stringValue = isActive ? "STOP" : "START"
        controlLabel.isEditable = false
        controlLabel.isBezeled = false
        controlLabel.drawsBackground = false
        controlLabel.alignment = .center
        controlLabel.font = NSFont.systemFont(ofSize: 9, weight: .semibold)
        controlLabel.textColor = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
        controlLabel.isSelectable = false
        controlButton.addSubview(controlLabel)
        controlButton.layer?.cornerRadius = 6
        contentView.addSubview(controlButton)
        
        // Google Material Design inspired startup animation
        addSmoothStartupAnimation()
        
        toolPanel?.makeKeyAndOrderFront(nil)
    }
    
    private func addSmoothStartupAnimation() {
        guard let contentView = toolPanel?.contentView else { return }
        
        // Start with the panel scaled down and transparent
        contentView.layer?.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
        contentView.layer?.opacity = 0.0
        
        // Animate to full size with smooth easing
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.6)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.25, 0.8, 0.25, 1.0))
        
        // Scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.8
        scaleAnimation.toValue = 1.0
        scaleAnimation.duration = 0.6
        scaleAnimation.fillMode = .forwards
        scaleAnimation.isRemovedOnCompletion = false
        
        // Opacity animation
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.0
        opacityAnimation.toValue = 1.0
        opacityAnimation.duration = 0.6
        opacityAnimation.fillMode = .forwards
        opacityAnimation.isRemovedOnCompletion = false
        
        // Add subtle spring bounce effect
        let springScale = CASpringAnimation(keyPath: "transform.scale")
        springScale.fromValue = 0.8
        springScale.toValue = 1.0
        springScale.duration = 0.8
        springScale.mass = 1.0
        springScale.stiffness = 200.0
        springScale.damping = 20.0
        springScale.fillMode = .forwards
        springScale.isRemovedOnCompletion = false
        
        contentView.layer?.add(springScale, forKey: "startupScale")
        contentView.layer?.add(opacityAnimation, forKey: "startupOpacity")
        
        // Reset transforms after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            contentView.layer?.transform = CATransform3DIdentity
            contentView.layer?.opacity = 1.0
            contentView.layer?.removeAnimation(forKey: "startupScale")
            contentView.layer?.removeAnimation(forKey: "startupOpacity")
        }
        
        CATransaction.commit()
    }
    
    
    @objc private func toolSelected(_ sender: PremiumToolButton) {
        if let tool = DrawingTool(rawValue: sender.tag) {
            // Check if clicking on the already selected tool - if so, deselect it
            if currentTool == tool {
                // Deselect the current tool
                currentTool = nil
                isCutMode = false
                currentPath = NSBezierPath()
                
                // Visual feedback for deselection
                let notification = NSUserNotification()
                notification.title = "✨ Tool Deselected"
                notification.informativeText = "Click on a tool to select it again"
                notification.soundName = nil
                NSUserNotificationCenter.default.deliver(notification)
                
                // Reset button appearance
                animateToolDeselection(sender)
                return
            }
            
            // Smooth button press animation
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.15)
            
            let scaleDown = CABasicAnimation(keyPath: "transform.scale")
            scaleDown.fromValue = 1.0
            scaleDown.toValue = 0.95
            scaleDown.duration = 0.08
            scaleDown.autoreverses = true
            sender.layer?.add(scaleDown, forKey: "buttonPress")
            
            CATransaction.commit()
            
            // Clear any partial drawing when switching tools
            currentPath = NSBezierPath()
            
            // Switch to new tool with smooth transition
            let previousTool = currentTool
            currentTool = tool
            isCutMode = (tool == .cut)
            
            // Animate tool change with smooth transitions
            if let previousTool = previousTool {
                animateToolChange(from: previousTool, to: tool)
            }
            
            // Haptic feedback (subtle click sound)
            NSSound.beep()
            
            // Enhanced visual feedback with modern notification
            let toolNames = ["Rectangle", "Circle", "Line", "Text", "Arrow", "Pen", "Cut"]
            let notification = NSUserNotification()
            notification.title = "✨ Tool Active"
            notification.informativeText = "\(toolNames[tool.rawValue]) tool ready"
            notification.soundName = nil // Silent notification
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
    
    private func animateToolChange(from previousTool: DrawingTool, to newTool: DrawingTool) {
        guard let contentView = toolPanel?.contentView else { return }
        
        // Find and animate buttons smoothly
        for subview in contentView.subviews {
            if let button = subview as? PremiumToolButton {
                // Update the isActiveTool state
                button.isActiveTool = (button.tag == newTool.rawValue)
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.25)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                
                if button.tag == newTool.rawValue {
                    // Animate to selected state
                    button.layer?.backgroundColor = NSColor(calibratedRed: 0.26, green: 0.47, blue: 0.88, alpha: 1.0).cgColor
                    button.layer?.borderColor = NSColor(calibratedRed: 0.36, green: 0.57, blue: 0.98, alpha: 0.9).cgColor
                    button.layer?.borderWidth = 1.5
                    button.layer?.shadowOpacity = 0.4
                    button.layer?.shadowRadius = 6
                    
                    // Update icon color
                    if let iconLabel = button.subviews.first as? NSTextField {
                        iconLabel.textColor = NSColor.white
                    }
                } else if button.tag == previousTool.rawValue {
                    // Animate from selected state
                    button.layer?.backgroundColor = NSColor(calibratedRed: 0.19, green: 0.19, blue: 0.19, alpha: 0.95).cgColor
                    button.layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
                    button.layer?.borderWidth = 0.5
                    button.layer?.shadowOpacity = 0.12
                    button.layer?.shadowRadius = 3
                    
                    // Update icon color
                    if let iconLabel = button.subviews.first as? NSTextField {
                        iconLabel.textColor = NSColor(calibratedRed: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
                    }
                }
                
                CATransaction.commit()
            }
        }
    }
    
    private func animateToolDeselection(_ button: PremiumToolButton) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        
        // Animate button back to unselected state
        button.layer?.backgroundColor = NSColor(calibratedRed: 0.19, green: 0.19, blue: 0.19, alpha: 0.95).cgColor
        button.layer?.borderColor = NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 0.4).cgColor
        button.layer?.borderWidth = 0.5
        button.layer?.shadowOpacity = 0.12
        button.layer?.shadowRadius = 3
        
        // Update icon color back to normal
        if let iconLabel = button.subviews.first as? NSTextField {
            iconLabel.textColor = NSColor(calibratedRed: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
        }
        
        // Add a subtle "deselect" animation - quick pulse
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 0.9
        pulseAnimation.duration = 0.1
        pulseAnimation.autoreverses = true
        button.layer?.add(pulseAnimation, forKey: "deselectionPulse")
        
        CATransaction.commit()
    }
    
    @objc private func showColorPicker(_ sender: NSButton) {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(colorPanelChanged(_:)))
        colorPanel.color = currentColor
        colorPanel.makeKeyAndOrderFront(nil)
    }
    
    @objc private func colorPanelChanged(_ sender: NSColorPanel) {
        currentColor = sender.color
        setupToolPanel() // Refresh to show new color
    }
    
    @objc private func colorSelected(_ sender: NSButton) {
        // Background color - just switch to white for now
        currentColor = NSColor.white
        setupToolPanel()
    }
    
    @objc private func resetColors() {
        currentColor = NSColor.black
        setupToolPanel()
    }
    
    @objc private func lineWidthChanged(_ sender: NSSlider) {
        currentLineWidth = CGFloat(sender.doubleValue)
    }
    
    @objc func toggleGrid() {
        showGrid.toggle()
        if showGrid {
            createGridOverlay()
        } else {
            removeGridOverlay()
        }
        setupToolPanel() // Refresh to show toggle state
    }
    
    @objc func toggleSnap() {
        snapToGrid.toggle()
        setupToolPanel() // Refresh to show toggle state
    }
    
    @objc func toggleArtboard() {
        // Toggle artboard functionality - placeholder for now
        print("Artboard toggled")
        // Future implementation: create artboard overlay, guides, etc.
    }
    
    @objc func selectLineColor() {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(lineColorChanged(_:)))
        colorPanel.color = currentColor
        colorPanel.title = "Select Line Color"
        colorPanel.makeKeyAndOrderFront(nil)
    }
    
    @objc func selectFillColor() {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(fillColorChanged(_:)))
        colorPanel.color = fillColor
        colorPanel.title = "Select Fill Color"
        colorPanel.makeKeyAndOrderFront(nil)
    }
    
    @objc func lineColorChanged(_ sender: NSColorPanel) {
        currentColor = sender.color
        setupToolPanel() // Refresh to show new color
    }
    
    @objc func fillColorChanged(_ sender: NSColorPanel) {
        fillColor = sender.color
        setupToolPanel() // Refresh to show new color
    }
    
    @objc func zoomIn() {
        currentZoomLevel = min(currentZoomLevel * 1.2, 4.0)
        print("Zoom in: \(currentZoomLevel)")
        // Future implementation: apply zoom to canvas
    }
    
    @objc func zoomOut() {
        currentZoomLevel = max(currentZoomLevel / 1.2, 0.25)
        print("Zoom out: \(currentZoomLevel)")
        // Future implementation: apply zoom to canvas
    }
    
    private func createGridOverlay() {
        guard let view = drawingView else { return }
        
        // Remove existing grid if any
        gridLayer?.removeFromSuperlayer()
        
        // Create new grid layer
        gridLayer = CAShapeLayer()
        gridLayer?.fillColor = NSColor.clear.cgColor
        gridLayer?.strokeColor = NSColor(white: 0.5, alpha: 0.3).cgColor
        gridLayer?.lineWidth = 0.5
        
        let path = NSBezierPath()
        let bounds = view.bounds
        
        // Draw vertical lines
        var x: CGFloat = 0
        while x <= bounds.width {
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: bounds.height))
            x += gridSize
        }
        
        // Draw horizontal lines
        var y: CGFloat = 0
        while y <= bounds.height {
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: bounds.width, y: y))
            y += gridSize
        }
        
        gridLayer?.path = path.cgPath
        
        // Add grid points at intersections
        let pointsLayer = CAShapeLayer()
        let pointPath = NSBezierPath()
        
        x = 0
        while x <= bounds.width {
            y = 0
            while y <= bounds.height {
                let rect = NSRect(x: x - 1, y: y - 1, width: 2, height: 2)
                pointPath.appendOval(in: rect)
                y += gridSize
            }
            x += gridSize
        }
        
        pointsLayer.path = pointPath.cgPath
        pointsLayer.fillColor = NSColor(white: 0.4, alpha: 0.5).cgColor
        pointsLayer.strokeColor = NSColor.clear.cgColor
        
        // Insert grid at the bottom of the layer hierarchy
        if let firstLayer = view.layer?.sublayers?.first {
            view.layer?.insertSublayer(gridLayer!, below: firstLayer)
            view.layer?.insertSublayer(pointsLayer, below: firstLayer)
        } else {
            view.layer?.addSublayer(gridLayer!)
            view.layer?.addSublayer(pointsLayer)
        }
        
        // Store points layer as part of grid
        gridLayer?.addSublayer(pointsLayer)
    }
    
    private func removeGridOverlay() {
        gridLayer?.removeFromSuperlayer()
        gridLayer = nil
    }
    
    func snapPointToGrid(_ point: NSPoint) -> NSPoint {
        guard snapToGrid else { return point }
        
        let snappedX = round(point.x / gridSize) * gridSize
        let snappedY = round(point.y / gridSize) * gridSize
        
        return NSPoint(x: snappedX, y: snappedY)
    }
    
    func updateGridFromSquare(_ rect: NSRect) {
        // Use the drawn square's dimensions as the new grid size
        let newGridSize = min(rect.width, rect.height)
        if newGridSize > 5 && newGridSize < 200 {
            gridSize = newGridSize
            if showGrid {
                createGridOverlay() // Recreate grid with new size
            }
        }
    }
    
    func addToUndoStack(_ action: DrawingAction) {
        undoStack.append(action)
        redoStack.removeAll()
    }
    
    func undo() {
        guard let action = undoStack.popLast() else { return }
        redoStack.append(action)
        
        switch action {
        case .shape(let layer):
            layer.removeFromSuperlayer()
            drawingLayers.removeAll { $0 === layer }
        case .cutImage(let cutImage):
            cutImage.layer.removeFromSuperlayer()
            cutImages.removeAll { $0 === cutImage }
        case .text(let layer):
            layer.removeFromSuperlayer()
        }
    }
    
    func redo() {
        guard let action = redoStack.popLast() else { return }
        undoStack.append(action)
        
        switch action {
        case .shape(let layer):
            drawingView?.layer?.addSublayer(layer)
            drawingLayers.append(layer)
        case .cutImage(let cutImage):
            drawingView?.layer?.addSublayer(cutImage.layer)
            cutImages.append(cutImage)
        case .text(let layer):
            drawingView?.layer?.addSublayer(layer)
        }
    }
    
    // CRITICAL: Allow users to escape/cancel current tool mode
    func cancelCurrentTool() {
        // Clear any temporary drawing state
        currentPath = NSBezierPath()
        
        // Clear any temporary drawing layer
        if let tempLayer = overlayWindow?.contentView?.layer?.sublayers?.last {
            tempLayer.removeFromSuperlayer()
        }
        
        // Reset to rectangle tool (safe default)
        currentTool = .rectangle
        setupToolPanel() // Refresh UI to show tool change
        
        // Show user feedback that tool was cancelled
        let notification = NSUserNotification()
        notification.title = "Tool Cancelled"
        notification.informativeText = "Press ESC anytime to cancel current tool"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc private func toggleDrawingMode() {
        isActive.toggle()
        if isActive {
            startDrawingMode()
        } else {
            stopDrawingMode()
        }
        // Just refresh the control button appearance, don't recreate the whole panel
        refreshControlButton()
    }
    
    private func refreshControlButton() {
        guard let contentView = toolPanel?.contentView else { return }
        
        // Find and update the control button without recreating the whole toolbar
        for subview in contentView.subviews {
            if subview.frame.origin.y == 120 { // This is the control button area
                // Update the control icon and label
                for subsubview in subview.subviews {
                    if let textField = subsubview as? NSTextField {
                        if textField.frame.height == 16 { // Control icon
                            textField.stringValue = isActive ? "■" : "▶"
                        } else if textField.frame.height == 14 { // Control label
                            textField.stringValue = isActive ? "STOP" : "START"
                        }
                    }
                }
                break
            }
        }
    }
    
    private func startDrawingMode() {
        let screenRect = NSScreen.main?.frame ?? NSRect.zero
        overlayWindow = NSWindow(contentRect: screenRect,
                               styleMask: .borderless,
                               backing: .buffered,
                               defer: false)
        overlayWindow?.level = NSWindow.Level.screenSaver
        overlayWindow?.backgroundColor = NSColor.clear
        overlayWindow?.isOpaque = false
        overlayWindow?.ignoresMouseEvents = false
        
        let dView = DrawingView(frame: screenRect)
        dView.wantsLayer = true
        dView.overlay = self
        drawingView = dView
        overlayWindow?.contentView = drawingView
        overlayWindow?.makeKeyAndOrderFront(nil)
        overlayWindow?.makeFirstResponder(drawingView)
        
        // If grid was enabled, create it on the new drawing view
        if showGrid {
            createGridOverlay()
        }
    }
    
    private func stopDrawingMode() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        drawingView = nil
    }
}

class DrawingView: NSView {
    weak var overlay: ClickToDrawOverlay?
    var selectionStart: NSPoint = NSZeroPoint
    var selectionRect: NSRect = NSRect.zero
    var selectionLayer: CAShapeLayer?
    var isDraggingImage: Bool = false
    var dragOffset: NSPoint = NSZeroPoint
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.wantsLayer = true
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        guard let overlay = overlay else { return }
        guard let currentTool = overlay.currentTool else { return } // No tool selected, ignore
        
        // Check if click is near the toolbar area - if so, don't handle as drawing
        // This allows users to click back to toolbar buttons even when a tool is active
        if let toolPanel = overlay.toolPanel,
           let toolPanelFrame = toolPanel.contentView?.frame,
           let overlayWindow = self.window {
            
            // Convert toolbar panel position to overlay window coordinates
            let toolPanelScreenRect = NSRect(x: toolPanel.frame.origin.x,
                                           y: toolPanel.frame.origin.y,
                                           width: toolPanelFrame.width,
                                           height: toolPanelFrame.height)
            let overlayScreenRect = overlayWindow.frame
            
            // Check if click is within an expanded toolbar interaction area
            let expandedToolbarArea = NSRect(
                x: toolPanelScreenRect.origin.x - overlayScreenRect.origin.x - 10,
                y: (overlayScreenRect.origin.y + overlayScreenRect.height) - (toolPanelScreenRect.origin.y + toolPanelScreenRect.height) - 10,
                width: toolPanelFrame.width + 20,
                height: toolPanelFrame.height + 20
            )
            
            // If click is in toolbar area, don't handle as drawing - let toolbar handle it
            if expandedToolbarArea.contains(location) {
                return
            }
        }
        
        // Apply grid snapping if enabled
        let snappedLocation = overlay.snapPointToGrid(location)
        
        // Add subtle ripple feedback at mouse down location
        addRippleEffect(at: snappedLocation)
        
        if overlay.isCutMode {
            // Start screen area selection for cutting
            selectionStart = snappedLocation
            selectionRect = NSRect(origin: snappedLocation, size: NSSize.zero)
            createSelectionLayer()
        } else if currentTool == .pen {
            // Start pen drawing
            overlay.currentPath = NSBezierPath()
            overlay.currentPath?.move(to: snappedLocation)
            overlay.currentPath?.lineWidth = overlay.currentLineWidth
        } else if currentTool == .text {
            // Handle text tool
            createTextAt(snappedLocation)
        } else {
            // Check if clicking on existing cut image first
            if let cutImage = findCutImageAt(location) {
                // Select and prepare for dragging
                overlay.selectedCutImage?.setSelected(false)
                overlay.selectedCutImage = cutImage
                cutImage.setSelected(true)
                isDraggingImage = true
                dragOffset = NSPoint(x: location.x - cutImage.position.x, 
                                   y: location.y - cutImage.position.y)
            } else {
                // Start drawing shapes
                selectionStart = snappedLocation
                overlay.selectedCutImage?.setSelected(false)
                overlay.selectedCutImage = nil
                overlay.isDrawing = true
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        guard let overlay = overlay else { return }
        guard let currentTool = overlay.currentTool else { return }
        
        // Apply grid snapping if enabled
        let snappedLocation = overlay.snapPointToGrid(location)
        
        if overlay.isCutMode && selectionLayer != nil {
            // Update selection rectangle (use snapped coordinates)
            let minX = min(selectionStart.x, snappedLocation.x)
            let minY = min(selectionStart.y, snappedLocation.y)
            let maxX = max(selectionStart.x, snappedLocation.x)
            let maxY = max(selectionStart.y, snappedLocation.y)
            
            selectionRect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            updateSelectionLayer()
        } else if currentTool == .pen && overlay.currentPath != nil {
            // Continue pen drawing
            overlay.currentPath?.line(to: snappedLocation)
            updatePenDrawing()
        } else if overlay.isDrawing {
            // Update shape preview
            updateShapePreview(from: selectionStart, to: snappedLocation)
        } else if isDraggingImage, let selectedImage = overlay.selectedCutImage {
            // Drag selected cut image (apply snapping if enabled)
            let dragPosition = NSPoint(x: location.x - dragOffset.x, 
                                      y: location.y - dragOffset.y)
            let snappedPosition = overlay.snapPointToGrid(dragPosition)
            selectedImage.updatePosition(snappedPosition)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let overlay = overlay else { return }
        guard let currentTool = overlay.currentTool else { return }
        
        // Apply grid snapping if enabled
        let snappedLocation = overlay.snapPointToGrid(location)
        
        if overlay.isCutMode && selectionLayer != nil {
            // Capture screen area and create cut image
            captureScreenArea()
            removeSelectionLayer()
        } else if currentTool == .pen && overlay.currentPath != nil {
            // Finish pen drawing
            finishPenDrawing()
        } else if overlay.isDrawing {
            // Finish shape drawing
            finishShapeDrawing(from: selectionStart, to: snappedLocation)
            
            // If we just drew a rectangle, update grid spacing based on it
            if currentTool == .rectangle {
                let rect = NSRect(x: min(selectionStart.x, snappedLocation.x), 
                                y: min(selectionStart.y, snappedLocation.y),
                                width: abs(snappedLocation.x - selectionStart.x), 
                                height: abs(snappedLocation.y - selectionStart.y))
                overlay.updateGridFromSquare(rect)
            }
            
            overlay.isDrawing = false
        }
        
        isDraggingImage = false
        dragOffset = NSZeroPoint
    }
    
    private func createSelectionLayer() {
        selectionLayer = CAShapeLayer()
        selectionLayer?.fillColor = NSColor.clear.cgColor
        selectionLayer?.strokeColor = NSColor.systemBlue.cgColor
        selectionLayer?.lineWidth = 2.0
        selectionLayer?.lineDashPattern = [5, 5]
        self.layer?.addSublayer(selectionLayer!)
    }
    
    private func updateSelectionLayer() {
        let path = CGPath(rect: selectionRect, transform: nil)
        selectionLayer?.path = path
    }
    
    private func removeSelectionLayer() {
        selectionLayer?.removeFromSuperlayer()
        selectionLayer = nil
    }
    
    private func captureScreenArea() {
        guard selectionRect.width > 10 && selectionRect.height > 10 else { return }
        
        // Convert view coordinates to screen coordinates
        let windowLocation = convert(selectionRect.origin, to: nil)
        let screenLocation = window?.convertToScreen(NSRect(origin: windowLocation, size: selectionRect.size))
        
        guard let screenRect = screenLocation,
              let screen = NSScreen.main else { return }
        
        // Adjust for screen coordinate system (origin at bottom-left)
        let adjustedRect = NSRect(x: screenRect.origin.x,
                                y: screen.frame.height - screenRect.origin.y - screenRect.height,
                                width: screenRect.width,
                                height: screenRect.height)
        
        // Capture the screen area
        if let image = captureScreen(rect: adjustedRect) {
            addCutImage(image: image, at: selectionRect.origin, size: selectionRect.size)
        }
    }
    
    private func captureScreen(rect: NSRect) -> NSImage? {
        // Use simple screenshot method for now - can be enhanced with ScreenCaptureKit later
        guard let screen = NSScreen.main else { return nil }
        
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
        
        // Create a bitmap representation of the screen area
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(rect.width),
            pixelsHigh: Int(rect.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let bitmap = bitmapRep else { return nil }
        
        // Create NSImage and draw screen content
        let image = NSImage(size: rect.size)
        image.addRepresentation(bitmap)
        
        // For now, create a placeholder colored rectangle
        // This can be replaced with actual screen capture using ScreenCaptureKit
        image.lockFocus()
        NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8).set()
        NSRect(origin: .zero, size: rect.size).fill()
        
        // Add a border to show it's a captured area
        NSColor.systemBlue.set()
        let borderRect = NSRect(origin: .zero, size: rect.size)
        borderRect.frame(withWidth: 2.0)
        NSColor.black.set()
        
        let text = "Cut Image"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        text.draw(at: NSPoint(x: 10, y: rect.height/2), withAttributes: attrs)
        
        image.unlockFocus()
        
        return image
    }
    
    private func addCutImage(image: NSImage, at position: NSPoint, size: NSSize) {
        guard let overlay = overlay else { return }
        
        let cutImage = CutImage(image: image, position: position, size: size)
        overlay.cutImages.append(cutImage)
        
        // Add to layer hierarchy
        self.layer?.addSublayer(cutImage.layer)
        
        // Select the new cut image
        overlay.selectedCutImage?.setSelected(false)
        overlay.selectedCutImage = cutImage
        cutImage.setSelected(true)
    }
    
    private func findCutImageAt(_ point: NSPoint) -> CutImage? {
        guard let overlay = overlay else { return nil }
        
        // Check from top to bottom (reverse order since last added is on top)
        for cutImage in overlay.cutImages.reversed() {
            let imageRect = NSRect(origin: cutImage.position, size: cutImage.size)
            if imageRect.contains(point) {
                return cutImage
            }
        }
        return nil
    }
    
    override func keyDown(with event: NSEvent) {
        guard let overlay = overlay else { return }
        
        // Handle keyboard shortcuts
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "z":
                if event.modifierFlags.contains(.shift) {
                    overlay.redo() // Cmd+Shift+Z for redo
                } else {
                    overlay.undo() // Cmd+Z for undo
                }
                return
            case "s":
                saveDrawing() // Cmd+S for save
                return
            default:
                break
            }
        } else {
            // Non-command shortcuts
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "g":
                // Toggle grid
                overlay.toggleGrid()
                return
            case "s":
                // Toggle snap to grid
                overlay.toggleSnap()
                return
            default:
                break
            }
        }
        
        // CRITICAL: ESC key to cancel current tool mode and return to normal
        if event.keyCode == 53 { // ESC key
            overlay.cancelCurrentTool()
            return
        }
        
        // Q key to deselect current tool (emergency exit)
        if event.charactersIgnoringModifiers?.lowercased() == "q" {
            if let appDelegate = NSApplication.shared.delegate as? ClickToDrawOverlay {
                appDelegate.currentTool = nil
            }
            overlay.cancelCurrentTool()
            return
        }
        
        // Delete selected cut image with Delete or Backspace
        if (event.keyCode == 51 || event.keyCode == 117), // Delete or Backspace
           let selectedImage = overlay.selectedCutImage {
            
            selectedImage.layer.removeFromSuperlayer()
            overlay.cutImages.removeAll { $0 === selectedImage }
            overlay.selectedCutImage = nil
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // MARK: - Drawing Methods
    
    private func updatePenDrawing() {
        guard let overlay = overlay, let path = overlay.currentPath else { return }
        
        // Remove previous preview layer
        selectionLayer?.removeFromSuperlayer()
        
        // Create preview layer
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = overlay.currentColor.cgColor
        shapeLayer.fillColor = NSColor.clear.cgColor
        shapeLayer.lineWidth = overlay.currentLineWidth
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        
        self.layer?.addSublayer(shapeLayer)
        selectionLayer = shapeLayer
    }
    
    private func finishPenDrawing() {
        guard let overlay = overlay, let path = overlay.currentPath else { return }
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = overlay.currentColor.cgColor
        shapeLayer.fillColor = NSColor.clear.cgColor
        shapeLayer.lineWidth = overlay.currentLineWidth
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        
        self.layer?.addSublayer(shapeLayer)
        overlay.drawingLayers.append(shapeLayer)
        overlay.addToUndoStack(.shape(shapeLayer))
        
        // Clean up
        selectionLayer?.removeFromSuperlayer()
        selectionLayer = nil
        overlay.currentPath = nil
    }
    
    private func updateShapePreview(from start: NSPoint, to end: NSPoint) {
        guard let overlay = overlay else { return }
        guard let currentTool = overlay.currentTool else { return }
        
        // Remove previous preview
        selectionLayer?.removeFromSuperlayer()
        
        let path = createShapePath(from: start, to: end, tool: currentTool)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path?.cgPath
        shapeLayer.strokeColor = overlay.currentColor.cgColor
        shapeLayer.lineWidth = overlay.currentLineWidth
        
        if currentTool == .rectangle || currentTool == .ellipse {
            shapeLayer.fillColor = NSColor.clear.cgColor
        } else {
            shapeLayer.fillColor = NSColor.clear.cgColor
        }
        
        if currentTool == .line || currentTool == .arrow {
            shapeLayer.lineCap = .round
        }
        
        self.layer?.addSublayer(shapeLayer)
        selectionLayer = shapeLayer
    }
    
    private func finishShapeDrawing(from start: NSPoint, to end: NSPoint) {
        guard let overlay = overlay else { return }
        guard let currentTool = overlay.currentTool else { return }
        
        let path = createShapePath(from: start, to: end, tool: currentTool)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path?.cgPath
        shapeLayer.strokeColor = overlay.currentColor.cgColor
        shapeLayer.lineWidth = overlay.currentLineWidth
        shapeLayer.fillColor = NSColor.clear.cgColor
        
        if currentTool == .line || currentTool == .arrow {
            shapeLayer.lineCap = .round
        }
        
        self.layer?.addSublayer(shapeLayer)
        overlay.drawingLayers.append(shapeLayer)
        overlay.addToUndoStack(.shape(shapeLayer))
        
        // Clean up preview
        selectionLayer?.removeFromSuperlayer()
        selectionLayer = nil
    }
    
    private func createShapePath(from start: NSPoint, to end: NSPoint, tool: DrawingTool) -> NSBezierPath? {
        let path = NSBezierPath()
        
        switch tool {
        case .rectangle:
            let rect = NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
                            width: abs(end.x - start.x), height: abs(end.y - start.y))
            path.appendRect(rect)
            
        case .ellipse:
            let rect = NSRect(x: min(start.x, end.x), y: min(start.y, end.y),
                            width: abs(end.x - start.x), height: abs(end.y - start.y))
            path.appendOval(in: rect)
            
        case .line:
            path.move(to: start)
            path.line(to: end)
            
        case .arrow:
            path.move(to: start)
            path.line(to: end)
            
            // Add arrowhead
            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength: CGFloat = 15
            let arrowAngle: CGFloat = 0.5
            
            let arrowEnd1 = NSPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            )
            let arrowEnd2 = NSPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            )
            
            path.move(to: end)
            path.line(to: arrowEnd1)
            path.move(to: end)
            path.line(to: arrowEnd2)
            
        default:
            return nil
        }
        
        return path
    }
    
    private func createTextAt(_ location: NSPoint) {
        guard let overlay = overlay else { return }
        
        // Create a simple text input dialog
        let alert = NSAlert()
        alert.messageText = "Enter Text"
        alert.informativeText = "Type the text you want to add:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = "Text"
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            addTextLayer(text: textField.stringValue, at: location)
        }
    }
    
    private func addTextLayer(text: String, at location: NSPoint) {
        guard let overlay = overlay else { return }
        
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = NSFont.systemFont(ofSize: 18)
        textLayer.fontSize = 18
        textLayer.foregroundColor = overlay.currentColor.cgColor
        textLayer.alignmentMode = .left
        textLayer.isWrapped = false
        
        // Calculate text size
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18)
        ]
        let size = text.size(withAttributes: attrs)
        textLayer.frame = NSRect(origin: location, size: size)
        
        self.layer?.addSublayer(textLayer)
        overlay.addToUndoStack(.text(textLayer))
    }
    
    private func addRippleEffect(at location: NSPoint) {
        // Create a subtle ripple animation for user feedback
        let rippleLayer = CAShapeLayer()
        rippleLayer.frame = self.bounds
        
        // Create expanding circle
        let ripplePath = NSBezierPath(ovalIn: NSRect(x: location.x - 2, y: location.y - 2, width: 4, height: 4))
        rippleLayer.path = ripplePath.cgPath
        rippleLayer.fillColor = NSColor.clear.cgColor
        rippleLayer.strokeColor = NSColor(calibratedRed: 0.3, green: 0.6, blue: 1.0, alpha: 0.6).cgColor
        rippleLayer.lineWidth = 2.0
        
        self.layer?.addSublayer(rippleLayer)
        
        // Animate the ripple
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.4)
        CATransaction.setCompletionBlock {
            rippleLayer.removeFromSuperlayer()
        }
        
        // Scale animation
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 8.0
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        // Opacity animation
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.6
        opacityAnimation.toValue = 0.0
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        // Line width animation
        let lineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        lineWidthAnimation.fromValue = 2.0
        lineWidthAnimation.toValue = 0.5
        lineWidthAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        rippleLayer.add(scaleAnimation, forKey: "rippleScale")
        rippleLayer.add(opacityAnimation, forKey: "rippleOpacity")
        rippleLayer.add(lineWidthAnimation, forKey: "rippleLineWidth")
        
        CATransaction.commit()
    }
    
    private func saveDrawing() {
        guard let layer = self.layer else { return }
        
        // Create an image from the current drawing
        let bounds = layer.bounds
        let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: Int(bounds.width),
                                       pixelsHigh: Int(bounds.height),
                                       bitsPerSample: 8,
                                       samplesPerPixel: 4,
                                       hasAlpha: true,
                                       isPlanar: false,
                                       colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0,
                                       bitsPerPixel: 0)
        
        guard let bitmap = imageRep else { return }
        
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        
        // Render the layer
        layer.render(in: context!.cgContext)
        
        NSGraphicsContext.restoreGraphicsState()
        
        // Save to desktop
        if let data = bitmap.representation(using: .png, properties: [:]) {
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let filename = "Drawing_\(Date().timeIntervalSince1970).png"
            let url = desktop.appendingPathComponent(filename)
            
            try? data.write(to: url)
            
            // Show notification
            let notification = NSUserNotification()
            notification.title = "Drawing Saved"
            notification.informativeText = "Saved to \(filename)"
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}

let app = NSApplication.shared
let delegate = ClickToDrawOverlay()
app.delegate = delegate
app.run()