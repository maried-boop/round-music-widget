import XCTest
import AppKit
import CoreImage
@testable import RoundMusicWidget

final class LensTests: XCTestCase {
    func testOriginalAppearanceAndSubtleMotion() throws {
        let source=fixture()
        let input=try XCTUnwrap(CIImage(data:source.tiffRepresentation!))
        let size=source.size
        let referenceURL=try XCTUnwrap(Bundle.module.url(forResource:"original-lens",withExtension:"png"))
        let reference=try pixels(XCTUnwrap(NSImage(contentsOf:referenceURL)))
        let baseline=try pixels(XCTUnwrap(PassthroughImageView.renderEdgeStretch(input,size:size)))
        XCTAssertEqual(baseline,reference,"The resting lens must match the original implementation pixel for pixel")
        let moved=try pixels(XCTUnwrap(PassthroughImageView.renderEdgeStretch(input,size:size,phase:.pi/2)))
        XCTAssertNotEqual(baseline,moved,"The existing edge stretch must move slightly")
        let difference=zip(baseline,moved).map { abs(Int($0)-Int($1)) }
        let mean=Double(difference.reduce(0,+))/Double(difference.count)
        XCTAssertLessThan(mean,3.5,"Motion should remain a tiny variation on the original effect")
        for y in 98..<158 { for x in 98..<158 {
            let i=(y*256+x)*4
            XCTAssertEqual(Array(baseline[i..<i+4]),Array(moved[i..<i+4]),"The original undistorted centre must stay intact")
        }}
        let loop=try pixels(XCTUnwrap(PassthroughImageView.renderEdgeStretch(input,size:size,phase:2 * .pi)))
        XCTAssertEqual(baseline,loop)
    }

    private func pixels(_ image:NSImage) throws -> [UInt8] {
        let cg=try XCTUnwrap(image.cgImage(forProposedRect:nil,context:nil,hints:nil))
        var result=[UInt8](repeating:0,count:256*256*4)
        try result.withUnsafeMutableBytes { data in
            let context=try XCTUnwrap(CGContext(data:data.baseAddress,width:256,height:256,
                bitsPerComponent:8,bytesPerRow:1024,space:CGColorSpace(name:CGColorSpace.sRGB)!,
                bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg,in:CGRect(x:0,y:0,width:256,height:256))
        }
        return result
    }
}

func fixture() -> NSImage {
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:256,pixelsHigh:256,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[.alphaNonpremultiplied],bytesPerRow:1024,bitsPerPixel:32)!
 let bytes=bitmap.bitmapData!
 for y in 0..<256 { for x in 0..<256 {
  let i=(y*256+x)*4
  let v=UInt8(x%24<3 || y%24<3 ? 30 : 180)
  bytes[i]=v; bytes[i+1]=v; bytes[i+2]=v; bytes[i+3]=255
 }}
 return NSImage(cgImage:bitmap.cgImage!,size:NSSize(width:256,height:256))
}
