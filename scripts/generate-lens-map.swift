import AppKit
import CoreImage

// Sample the radial coordinate mapping of the widget's actual Core Image filter.
// The torus cross-section scales with its width; store displacement/width so the
// browser can vary width without replacing the original optical profile.
let context=CIContext(options:[.workingFormat:CIFormat.RGBAf.rawValue,.workingColorSpace:NSNull(),.outputColorSpace:NSNull()])
let gradient=CIFilter(name:"CILinearGradient")!
gradient.setValue(CIVector(x:0,y:0),forKey:"inputPoint0")
gradient.setValue(CIVector(x:4096,y:0),forKey:"inputPoint1")
gradient.setValue(CIColor(red:0,green:0,blue:0),forKey:"inputColor0")
gradient.setValue(CIColor(red:1,green:0,blue:0),forKey:"inputColor1")
let input=gradient.outputImage!
let columns=512, rows=151
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:columns,pixelsHigh:rows,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[.alphaNonpremultiplied],bytesPerRow:columns*4,bitsPerPixel:32)!
let bytes=bitmap.bitmapData!
var lowest:Float=0,highest:Float=0
for row in 0..<rows {
 let filter=CIFilter(name:"CITorusLensDistortion")!
 filter.setValue(input,forKey:kCIInputImageKey)
 filter.setValue(CIVector(x:1024,y:1024.5),forKey:kCIInputCenterKey)
 filter.setValue(512,forKey:kCIInputRadiusKey)
 filter.setValue(256,forKey:kCIInputWidthKey)
 filter.setValue(1+Double(row)*0.01,forKey:kCIInputRefractionKey)
 var output=[Float](repeating:0,count:columns*4)
 output.withUnsafeMutableBytes { buffer in
  context.render(filter.outputImage!,toBitmap:buffer.baseAddress!,rowBytes:columns*16,bounds:CGRect(x:1280,y:1024,width:columns,height:1),format:.RGBAf,colorSpace:nil)
 }
 for col in 0..<columns {
  let originalX=Float(1280+col)+0.5
  let displacement=(output[col*4]*4096-originalX)/256
  lowest=min(lowest,displacement);highest=max(highest,displacement)
  let packed=UInt16(max(0,min(65535,Int(((displacement+2)/4*65535).rounded()))))
  let i=(row*columns+col)*4
  bytes[i]=UInt8(packed>>8);bytes[i+1]=UInt8(packed&255);bytes[i+2]=0;bytes[i+3]=255
 }
}
let url=URL(fileURLWithPath:CommandLine.arguments[1])
try Data(bytes:bytes,count:columns*rows*4).write(to:url)
print("Lens displacement range: \(lowest)...\(highest); wrote \(url.lastPathComponent)")
func sample(radius:Double,width:Double,q:Double,n:Double)->Double {
 let f=CIFilter(name:"CITorusLensDistortion")!
 f.setValue(input,forKey:kCIInputImageKey);f.setValue(CIVector(x:1024,y:1024),forKey:kCIInputCenterKey)
 f.setValue(radius,forKey:kCIInputRadiusKey);f.setValue(width,forKey:kCIInputWidthKey);f.setValue(n,forKey:kCIInputRefractionKey)
 let x=1024+radius+q*width
 var pixel=[Float](repeating:0,count:4)
 pixel.withUnsafeMutableBytes { context.render(f.outputImage!,toBitmap:$0.baseAddress!,rowBytes:16,bounds:CGRect(x:x-0.5,y:1023.5,width:1,height:1),format:.RGBAf,colorSpace:nil) }
 return (Double(pixel[0])*4096-x)/width
}
var maximumError=0.0
for n in [1.0,1.62,2.4] { for q in stride(from:-0.95,through:0.95,by:0.1) {
 let reference=sample(radius:512,width:256,q:q,n:n)
 for width in [128.0,245.76,400.0] {
  maximumError=max(maximumError,abs(reference-sample(radius:512,width:width,q:q,n:n)))
 }
}}
print("Normalized width-profile maximum error: \(maximumError)")
