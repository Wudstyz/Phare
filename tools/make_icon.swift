import AppKit

// Génère l'icône de Phare (PNG 1024x1024). Usage : swift make_icon.swift sortie.png
let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func c(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Ombre portée
NSGraphicsContext.saveGraphicsState()
let sh = NSShadow()
sh.shadowColor = NSColor.black.withAlphaComponent(0.35)
sh.shadowBlurRadius = 24
sh.shadowOffset = NSSize(width: 0, height: -10)
sh.set()
c(0x0B1F33).setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
squircle.addClip()

// Ciel nocturne
NSGradient(colors: [c(0x0B1F33), c(0x1D4E73)], atLocations: [0, 1], colorSpace: .sRGB)!.draw(in: body, angle: 90)

// Lueur autour de la lampe
let lamp = NSPoint(x: 512, y: 625)
NSGradient(colors: [c(0xF5B83D, 0.55), c(0xF5B83D, 0)], atLocations: [0, 1], colorSpace: .sRGB)!
    .draw(fromCenter: lamp, radius: 0, toCenter: lamp, radius: 330, options: [])

// Étoiles
c(0xFFFFFF, 0.8).setFill()
for (x, y, r) in [(230.0, 800.0, 5.0), (330, 860, 4), (720, 840, 5), (800, 770, 4), (170, 700, 3), (860, 690, 3), (610, 880, 3)] {
    NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}

// Faisceaux
let left = NSBezierPath()
left.move(to: NSPoint(x: 512, y: 625)); left.line(to: NSPoint(x: 60, y: 790)); left.line(to: NSPoint(x: 60, y: 470)); left.close()
let right = NSBezierPath()
right.move(to: NSPoint(x: 512, y: 625)); right.line(to: NSPoint(x: 964, y: 790)); right.line(to: NSPoint(x: 964, y: 470)); right.close()
for (p, ang) in [(left, CGFloat(180)), (right, CGFloat(0))] {
    NSGraphicsContext.saveGraphicsState()
    p.addClip()
    NSGradient(colors: [c(0xFFF3C4, 0.75), c(0xFFF3C4, 0)], atLocations: [0, 1], colorSpace: .sRGB)!.draw(in: p.bounds, angle: ang)
    NSGraphicsContext.restoreGraphicsState()
}

// Mer
let sea = NSBezierPath()
sea.move(to: NSPoint(x: 100, y: 100))
sea.line(to: NSPoint(x: 100, y: 215))
var x: CGFloat = 100
while x <= 924 {
    sea.line(to: NSPoint(x: x, y: 215 + 14 * sin(x / 38)))
    x += 6
}
sea.line(to: NSPoint(x: 924, y: 100)); sea.close()
NSGraphicsContext.saveGraphicsState()
sea.addClip()
NSGradient(colors: [c(0x0F6F73), c(0x1BA39C)], atLocations: [0, 1], colorSpace: .sRGB)!.draw(in: sea.bounds, angle: 90)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
squircle.addClip()

// Rocher
c(0x16283A).setFill()
let rock = NSBezierPath()
rock.move(to: NSPoint(x: 330, y: 200))
rock.curve(to: NSPoint(x: 512, y: 285), controlPoint1: NSPoint(x: 360, y: 250), controlPoint2: NSPoint(x: 430, y: 285))
rock.curve(to: NSPoint(x: 700, y: 200), controlPoint1: NSPoint(x: 600, y: 285), controlPoint2: NSPoint(x: 670, y: 250))
rock.close()
rock.fill()

// Tour (trapèze) avec bandes
let tower = NSBezierPath()
tower.move(to: NSPoint(x: 392, y: 255)); tower.line(to: NSPoint(x: 632, y: 255))
tower.line(to: NSPoint(x: 587, y: 560)); tower.line(to: NSPoint(x: 437, y: 560)); tower.close()
NSGraphicsContext.saveGraphicsState()
tower.addClip()
c(0xFFFFFF).setFill(); tower.fill()
c(0xD9423A).setFill()
for y0 in [CGFloat(330), CGFloat(450)] {
    NSRect(x: 380, y: y0, width: 270, height: 60).fill()
}
// ombre à droite
c(0x0B1F33, 0.12).setFill()
NSRect(x: 512, y: 255, width: 140, height: 310).fill()
NSGraphicsContext.restoreGraphicsState()

// Porte
c(0x16283A).setFill()
NSBezierPath(roundedRect: NSRect(x: 489, y: 255, width: 46, height: 70), xRadius: 23, yRadius: 23).fill()

// Galerie
c(0x16283A).setFill()
NSBezierPath(roundedRect: NSRect(x: 412, y: 556, width: 200, height: 28), xRadius: 8, yRadius: 8).fill()

// Lanterne
c(0xF5B83D).setFill()
NSBezierPath(roundedRect: NSRect(x: 457, y: 584, width: 110, height: 82), xRadius: 10, yRadius: 10).fill()
c(0xFFF3C4).setFill()
NSBezierPath(roundedRect: NSRect(x: 477, y: 600, width: 70, height: 50), xRadius: 8, yRadius: 8).fill()

// Toit
c(0xD9423A).setFill()
let roof = NSBezierPath()
roof.move(to: NSPoint(x: 438, y: 664)); roof.line(to: NSPoint(x: 586, y: 664)); roof.line(to: NSPoint(x: 512, y: 735)); roof.close()
roof.fill()
c(0x16283A).setFill()
NSBezierPath(ovalIn: NSRect(x: 504, y: 732, width: 16, height: 16)).fill()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
