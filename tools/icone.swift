import AppKit
// Dessine l'icône : carré noir arrondi, personnage orange en pixels.
let rows = ["..XXXXXXXX..","..X.XXXX.X..","XXXXXXXXXXXX","XXXXXXXXXXXX","..XXXXXXXX..","..X.X..X.X..","..X.X..X.X.."]
func render(_ s: Int) -> Data {
  let img = NSImage(size: NSSize(width: s, height: s))
  img.lockFocus()
  let S = CGFloat(s), inset = S * 0.1
  let r = NSRect(x: inset, y: inset, width: S - 2*inset, height: S - 2*inset)
  NSColor(white: 0.04, alpha: 1).setFill()
  NSBezierPath(roundedRect: r, xRadius: r.width * 0.225, yRadius: r.width * 0.225).fill()
  let px = r.width * 0.6 / 12
  let ox = r.midX - px * 6, oy = r.midY + px * 3.5
  NSColor(red: 0.851, green: 0.467, blue: 0.341, alpha: 1).setFill()
  for (y, row) in rows.enumerated() { for (x, c) in row.enumerated() where c == "X" {
    NSRect(x: ox + CGFloat(x)*px, y: oy - CGFloat(y+1)*px, width: px+0.5, height: px+0.5).fill() } }
  img.unlockFocus()
  let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
  return rep.representation(using: .png, properties: [:])!
}
let dir = CommandLine.arguments[1]
for (n, s) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
  try! render(s).write(to: URL(fileURLWithPath: "\(dir)/icon_\(n).png"))
}
