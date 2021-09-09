//
//  MainActorTest.swift
//  MainActorTest
//
//  Created by chenhaoyu.1999 on 2021/8/29.
//

import Foundation

@MainActor var globalNumber = 0

@MainActor func globalFunction() {
    print(Thread.current)
}

actor CustomActor {
    var actorNumber = 0
    func test() async {
        print(Thread.current)
        await globalFunction()
        await mutableGlobalNumber()
        DispatchQueue.global().async {
            Task.detached(priority: nil) {
                await self.mutableGlobalNumber()
            }
        }
    }
    @MainActor func mutableGlobalNumber() {
        globalNumber += 1
    }
}
