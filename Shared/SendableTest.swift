//
//  SendableTest.swift
//  SendableTest
//
//  Created by chenhaoyu.1999 on 2021/8/29.
//

import Foundation

struct SendableStruct: Sendable {
    var number: Int
    init() {
        self.number = 0
    }
}

struct UnsendableStruct {
    // Stored property 'number' of 'Sendable'-conforming struct 'UnsendableStruct' has non-sendable type 'NSNumber'
    var string: NSMutableString
    init() {
        self.string = NSMutableString()
    }
}

struct UncheckedSendableStruct: @unchecked Sendable {
    var string: NSMutableString
}

final class SendableClass: Sendable {
    init() {self.number = 0}
    let number: Int
}

actor SendableActor {
    let sendableActor = SendableActor()
    var instanceNumber = 0
    var group: ThrowingTaskGroup<Int, Error>?
    // 这里 async 必要, 因为调用了 await
    func test1() async {
        var number = 1
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // 这是一个 Sendable 闭包 (addTask) , Swift 检测到可能同时对捕获的变量 number 进行修改, 报错
                // Mutation of captured var 'number' in concurrently-executing code
//                number += 1
            }
            // 解决方案, 这里不是 Sendable, 可以对 number 修改
            for await _ in group {
                number += 1
            }
            // ???
            instanceNumber = 10
        }
        await withThrowingTaskGroup(of: Int.self, body: { group in
            self.group = group
        })
    }
    // ???
    func test2(unsendable: NSMutableString) async {
        unsendable.append("")
        await sendableActor.test2(unsendable: unsendable)
    }
    
    func test3(sendable: SendableStruct) async {
        await sendableActor.test3(sendable: SendableStruct())
    }
    
    enum UnsendableError: Error, Sendable {
        case error(NSMutableString)
    }
    
    func test4() {
        let sendableNumber = 1
        var sendableVar = 1
        let unSendableClass = NSMutableString()
        // 只能 byValue 但不能是 byReference
        let closure1 = { @Sendable in
            print(sendableNumber)
        }
        let closure2 =  { @Sendable in
            // Reference to captured var 'sendableVar' in concurrently-executing code
//            print(sendableVar)
        }
        // 手动捕获
        let closure3 =  { @Sendable [sendableVar] in
            print(sendableVar)
        }
        // ???
        let closure4 =  { @Sendable in
            unSendableClass.append("")
            print(unSendableClass)
        }
        let closure5 = {  @Sendable in
            // should have a warning ???
            throw UnsendableError.error(.init())
        }
    }
}
