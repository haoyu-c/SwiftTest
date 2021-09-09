//
//  TaskGroupTest.swift
//  TaskGroupTest
//
//  Created by chenhaoyu.1999 on 2021/8/29.
//
enum MyError: Error {
    case myError
}

struct TestGroupTest {
    func functionMayThrow(index: Int) throws -> Int {
        
        if index == 1 {
            print("throws error")
            throw MyError.myError
        }
        return index
    }
    // TODO: 测试没有 wait 的时候是否回
    func test() async throws {
        
        try await withThrowingTaskGroup(of: Int.self) { group in
            for i in (1...10) {
                group.addTask {
                    print("execute task", i)
                    return try functionMayThrow(index: i)
                }
            }
            var sum = 0
            // 测试 cooperative cancel
            for try await num in group {
                print(num)
                if num == 4 || num == 5 {
                    throw MyError.myError
                }
                sum += num
            }
            // 处理单个问题错误
//            while !group.isEmpty {
//                do {
//                    sum += try await group.next() ?? 0
//                } catch {
//                    print(error)
//                }
//            }
            
            print(sum)
        }
    }
    
    func test2() async {
        @Sendable func wait1Second() async -> Int {
            await Task.sleep(2)
            print("wait ended")
            return 0
        }
        // 虽然没有 await, 但是还是挡着等待执行完成
        async let value = wait1Second()
        print("func ended")
    }
}
