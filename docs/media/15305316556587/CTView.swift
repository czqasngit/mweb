//
//  CTView.swift
//  CoreTextTests
//
//  Created by legendry on 2018/7/2.
//  Copyright © 2018 legendry. All rights reserved.
//

import UIKit
import CoreText

class CTView: UIView {


    override func draw(_ rect: CGRect) {
        
        let string = """
            This collection of documents is the API reference for the Core Text framework. Core Text provides#a modern, low-level programming interface for laying out text and handling fonts. The Core Text layout engine is designed for high performance, ease of use, and close integration with Core Foundation. The text layout API provides high-quality typesetting, including character-to-glyph conversion, with ligatures, kerning, and so on. The complementary Core Text font technology provides automatic font substitution (cascading), font descriptors and collections, easy access to font metrics and glyph data, and many other features.

        Multicore Considerations: All individual functions in Core Text are thread safe. Font objects (CTFont, CTFontDescriptor, and associated objects) can be used simultaneously by multiple operations, work queues, or threads. However, the layout objects (CTTypesetter, CTFramesetter, CTRun, CTLine, CTFrame, and associated objects) should be used in a single operation, work queue, or thread.
        """
        let attrString = NSMutableAttributedString(string: string)
        
        attrString.addAttributes([NSAttributedStringKey.font : UIFont.systemFont(ofSize: 30)], range: NSRange(location: 10, length: 20))
        attrString.addAttributes([NSAttributedStringKey.backgroundColor : UIColor.purple], range: NSRange(location: 15, length: 30))
        
        //设置行间距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 20
        attrString.addAttributes([NSAttributedStringKey.paragraphStyle : paragraphStyle], range: NSRange(location: 0, length: string.count))
        
        var ctRunDelegate = CTRunDelegateCallbacks(version: kCTRunDelegateVersion1, dealloc: { _ in
            print("CTRunDelegateCallbacks Dealloc")
        }, getAscent: { _ in 100
        }, getDescent: { _ in 0}, getWidth: { _ in 110})
        //创建一个CTRunDelegate对象,第一个值描述了占位的具体大小信息
        //第二个值是传递到回调函数里面refCon的值
        if let ctRunDelegateRef = CTRunDelegateCreate(&ctRunDelegate, nil) {
            attrString.addAttributes([NSAttributedStringKey.init(kCTRunDelegateAttributeName as String) : ctRunDelegateRef], range: NSRange(location: string.index(of: "#")!.encodedOffset, length: 1))
        }
        
        
        let frameSetter = CTFramesetterCreateWithAttributedString(attrString)
        //限定你要从创建CTFrameSetter中的NSArributedString中渲染的字符范围,如果这个值被设定为(location:0,length:0),就会渲染整个字符
        let stringRange = CFRange()
        var transform = CGAffineTransform.identity
        //限定渲染的画布范围,矩阵变化用默认值
        let path = CGPath(rect: self.bounds, transform: &transform)
        let ctFrame = CTFramesetterCreateFrame(frameSetter, stringRange, path, nil)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        print(context.textMatrix,context)
        //设置最初变化之前的矩阵为默认的矩阵
        context.textMatrix = CGAffineTransform.identity
        //向下移动画布的高度的位移
        context.translateBy(x: 0, y: self.frame.size.height)
        //将矩阵翻转
        context.scaleBy(x: 1.0, y: -1.0)
        //最后渲染出来的就是从左到右从上到下的
        CTFrameDraw(ctFrame, context)

        //获取版本的数组
        let lines = CTFrameGetLines(ctFrame)
        let lineOriginsPoint = UnsafeMutablePointer<CGPoint>.allocate(capacity: CFArrayGetCount(lines))
        //得到每一行的起始点
        CTFrameGetLineOrigins(ctFrame, CFRange(location: 0, length: 0), lineOriginsPoint)
        //将指向CGPoint数组的指针转换成一个Buffer指针,相当于Buffer指向了数组,并且可以遍历,Buffer实现了Collection Protocol
        let buffer = UnsafeBufferPointer<CGPoint>.init(start: lineOriginsPoint, count: CFArrayGetCount(lines))
        for i in 0..<CFArrayGetCount(lines) {
            if let ctLinePoint = CFArrayGetValueAtIndex(lines, i) {
                //这里要注意的是:从CFDictionary获取的Value是Unmanged非托管对象
                let ctLineUnmanged = Unmanaged<CTLine>.fromOpaque(ctLinePoint)
                //获取非托管对象中的值,这里使用的是unretained 不对对象的引用计数器增加
                let ctLine = ctLineUnmanged.takeUnretainedValue()
                let lineOrigin = buffer[i]
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)
                let runs = CTLineGetGlyphRuns(ctLine)
                let count = CFArrayGetCount(runs)
                for j in 0..<count{
                    if let ctRunPoint = CFArrayGetValueAtIndex(runs, j) {
                        let ctRunUnmanged = Unmanaged<CTRun>.fromOpaque(ctRunPoint)
                        let ctRun = ctRunUnmanged.takeUnretainedValue()
                        let attribute = CTRunGetAttributes(ctRun)
                        let key = Unmanaged.passRetained(kCTRunDelegateAttributeName).toOpaque()
                        var run_ascent: CGFloat = 0
                        var run_descent: CGFloat = 0
                        var run_leading: CGFloat = 0
                        let range = CTRunGetStringRange(ctRun)
                        CTRunGetTypographicBounds(ctRun, CFRange(location: 0, length: CTRunGetGlyphCount(ctRun)), &run_ascent, &run_descent, &run_leading)
                        let height = run_ascent + run_descent
                        //注意: CFDictionaryGetValue中的参数Key 是一个非托管对象Unmanged<CFString>的指针
                        if let _ = CFDictionaryGetValue(attribute, key) {
                            let image = UIImage(named: "presence_offline")!
                            if let p = CTRunGetAdvancesPtr(ctRun) {
                                let xOffset = CTLineGetOffsetForStringIndex(ctLine, range.location, nil)
                                //lineOrigin.y 是baseline的y坐标,如果要下对齐,还需要向下偏移descent
                                let rect = CGRect(x: lineOrigin.x + xOffset, y: lineOrigin.y - descent/*向下偏移*/ , width: p.pointee.width, height: height)
                                context.draw(image.cgImage!, in: rect)
                            }
                        }
                    }
                }
            }
        }
        
    }

}
