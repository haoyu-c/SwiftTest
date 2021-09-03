//
//  CGFloatDoubleConversion.swift
//  CGFloatDoubleConversion
//
//  Created by chenhaoyu.1999 on 2021/8/28.
//

import Foundation
import SwiftUI

struct ProgressIndicator: Shape {
    
    let elapsedTime: TimeInterval
    let totalTime: TimeInterval
    
    func path(in rect: CGRect) -> Path {
        Path { p in
            // double as cgfloat
            p.addRect(CGRect(x: 0, y: 0, width: elapsedTime / totalTime, height: rect.height))
        }
    }
}

func sum(cgFloat: CGFloat, double: Double) -> CGFloat {
    // sum 是 double
    let sum = cgFloat + double
    // 将 double 转换成 cgfloat
    return sum
}
// double is always prefered over cgfloat
// cgfloat -> double is prefered over double -> cgfloat
func sum(_: Double, _: Double) -> Double { 0 }
func sum(_: CGFloat, _: CGFloat) -> CGFloat { 0 }
let x: CGFloat = 0
let y: Double = 0
let cgfloat = sum(x, y)
// 这里会选择前一个 sum, 虽然 Double -> CGFloat 的转换都有, 但是前一个的转换更靠后, 可以带来更小的精度损失
