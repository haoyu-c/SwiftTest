//
//  ActorTest.swift
//  ActorTest
//
//  Created by chenhaoyu.1999 on 2021/8/29.
//

import Foundation
// each actor instance contains its own serial executor
actor BankAccount {
    let accountNumber: String = ""
    var balance = 0
    // 必须标记 async 因为使用了 await
    func transfer(from other: BankAccount, amount: Int) async {
        balance += amount
        // 不能改变在其他 Actor 隔离域内的属性
        /*
         实际上这个可以支持,但是会在 get 和 set 之间有隐式的 suspension point 导致 data race
         在 get 后, 其他账户也来检查 other.blance 是否有足够的钱, 以为有, 但实际上两次减去后是负数, 导致错误发生
         下面大概意思是两个属性如果要同时修改也会带来问题
         Moreover, setting properties asynchronously may make it easier to break invariants unintentionally if, e.g., two properties need to be updated at once to maintain an invariant
         eg: await other.balance = other.balance - amount
         */
//        await other.balance = other.balance - amount
        await asyncFunc {
            self.balance += 1
        }
        // 可以读取
        let otherBalance = await other.balance
        // 由于不可变, 可以不用 await, 但是如果定义在 module 之外, 需要使用 await, 为了 sourceCompability
        let otherAccountNumber = other.accountNumber
        // 向其他的 actor 发送消息
        await other.deposit(amount: amount)
    }
    
    func asyncFunc(_ c:@escaping () -> Void) async {
        
    }
    
    func deposit(amount: Int) {
        balance -= amount
    }
    
    func addBalance() {
        // Actor-isolated property 'balance' can not be mutated from a Sendable closure
        // escaping 的闭包必须是 Sendable
        Task.detached { @Sendable in
//            await self.balance += 1
        }
    }
}

// 防止 Reentrancy 的问题: 把状态的变更放到一个方法中, 或者对与这种方法做出处理, 比如 ImageDownloader
