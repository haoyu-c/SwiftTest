//
//  ActorIsolationControl.swift
//  ActorIsolationControl
//
//  Created by chenhaoyu.1999 on 2021/8/29.
//

import Foundation

actor BankAccount1 {
    let accountNumber: Int
    var balance: Double

    init(accountNumber: Int, initialDeposit: Double) {
        self.accountNumber = accountNumber
        self.balance = initialDeposit
    }

    func deposit(amount: Double) {
        assert(amount >= 0)
        balance = balance + amount
    }
    
    func giveSomeGetSome(amount: Double, friend: BankAccount1) async {
        SwiftTest.deposit(amount: amount, to: self)         // okay to call synchronously, because self is isolated
        await SwiftTest.deposit(amount: amount, to: friend) // must call asynchronously, because friend is not isolated
    }
    
    nonisolated func safeAccountNumberDisplayString() -> String {
        let digits = String(accountNumber)   // okay, because accountNumber is also nonisolated
        return String(repeating: "X", count: digits.count - 4) + String(digits.suffix(4))
    }
    // ???
    nonisolated func f() -> UnsendableStruct? { nil }
    
}
// Future Direction
//extension BankAccount1: isolated Hashable {
//
//}
// 使用 isolated 创建函数来操作 BankAccount1
// 可以使用在 account 隔离域内的属性
func deposit(amount: Double, to account: isolated BankAccount1) {
  assert(amount >= 0)
  account.balance = account.balance + amount
}
// error: multiple isolated parameters in function
// ??? but is future direction
func f(a: isolated BankAccount, b: isolated BankAccount) {
    
}
