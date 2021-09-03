//
//  DCDCarAtlasImageManager.swift
//
//  Created by chenhaoyu.1999 on 2021/8/26.
//

import UIKit
import SDWebImage
typealias Image = UIImage

enum DCDCarAtlasImageManagerError: Error {
    case noClarityInUrl, networkError, noFirstImage, emptyUrl
}

final class DCDCarAtlasImageManager: NSObject {
    
    @objc static let shared = DCDCarAtlasImageManager()
    
    typealias SeriesID = String
    typealias Key = String
    typealias Clarity = Int
    
    /// 用于读写  imageCache 的队列, 所有对 imageCache 的读写都需要使用该队列
    private let queue = DispatchQueue(label: "com.dcd.carAtlasImageManager",attributes: .concurrent)
    
    /// 图片缓存
    private var imageCache = [SeriesID: [Key: [Clarity: Image]]]()
    
    
    /// 获取单个图片
    /// - Parameters:
    ///   - seriesId: 车系 id
    ///   - url: 图片 url
    ///   - completion: 图片获取回调, 涉及到 dispatchgroup, 一定要调用
    /// - Throws: 获取清晰度或者网络图片错误
    private func getOrFetchImage(for seriesId: String, with url:String, size: CGSize, completion: @escaping (Image?, Key, Clarity) throws -> Void) throws {
        // 拿到去掉清晰度的 URL 作为 imageCache 的二级 key
        let imageKey = getKey(from: url)
        // 从 URL 拿到清晰度作为三级 key
        let clarity = try getClarityFrom(url: url)
        // 获取缓存
        var cache: [Clarity: Image]?
        queue.sync {
            cache = imageCache[seriesId]?[imageKey]
        }
        if let cache = cache {
            // 判断是否有相应或者更高品质的图片缓存
            let maxClarity = cache.keys.max() ?? 0
            if maxClarity >= clarity, let cachedImage = cache[maxClarity] {
                print("从缓存获取成功")
                try completion(cachedImage, imageKey, clarity)
                return
            }
        }
        // 获取网络图片
        SDWebImageDownloader.shared.downloadImage(with: URL(string: url)) { image, _, _, _ in
            do {
               try completion(image, imageKey, clarity)
            } catch {
                print(error)
            }
        }
    }
    
    /// 获取多张图片
    /// - Parameters:
    ///   - seriesId: 车系 id
    ///   - urls: 图片 url
    ///   - firstImageCompletion: 获取第一张图片就完成回调, 及时展示第一张图片
    ///   - completion: 获取所有图片完成回调
    @objc func getOrFetchImages(for seriesId: String, with urls:[String], size: CGSize, firstImageCompletion:  @escaping ((Image) -> Void), completion: @escaping (([String: Image]?) -> Void)) {
        guard !urls.isEmpty else { completion(nil); return }
        var imageMap = [String: Image]()
        // 先获取第一张图片
        try? getOrFetchImage(for: seriesId, with: urls[0], size: size, completion: { [unowned self] image, key, clarity in
            queue.async(flags: .barrier) { [unowned self] in
                imageCache[seriesId, default: [:]][key, default: [:]][clarity] = image
                imageMap[urls[0]] = image
            }
            let group = DispatchGroup()
            // 使用 DispatchGroup 管理剩余的图片下载任务
            for (index, url) in urls.enumerated() where index != 0 {
                group.enter()
                do {
                    try getOrFetchImage(for: seriesId, with: url, size: size) { [unowned self] image, key, clarity in
                        defer { group.leave() }
                        if let image = image {
                            queue.async(flags: .barrier) {
                                imageCache[seriesId, default: [:]][key, default: [:]][clarity] = image
                                imageMap[url] = image
                            }
                        }
                    }
                } catch {
                    print(error)
                    group.leave()
                }
            }
            // 调用全部下载完成后的回调
            group.notify(queue: .main) {
                completion(imageMap)
            }
        })
        
    }
    
    /// 从 url 中拿到图片清晰度
    /// - Parameter url: 图片 url, eg: https://p6-dcd.byteimg.com/img/tos-cn-i-0000/d34a6238984c4a319f6417fb18cbac26~tplv-resize:202:0.webp
    /// - Throws: 从图片中拿不到分辨率的错误
    /// - Returns: 图片分辨率, eg: 202
    private func getClarityFrom(url: String) throws -> Int {
        let regularExpression = try NSRegularExpression(pattern: #":\d{1,4}:"#, options: [])
        // eg: 匹配到 ":202:"
        guard let matchingResult = regularExpression.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.count)) else {
            throw DCDCarAtlasImageManagerError.noClarityInUrl
        }
        // 获取正则匹配结果的范围
        let range = matchingResult.range
        guard range.length > 2 else { throw DCDCarAtlasImageManagerError.noClarityInUrl }
        let startIndex = url.index(url.startIndex, offsetBy: range.location + 1)
        let endIndex = url.index(url.startIndex, offsetBy: range.location + range.length - 2)
        // 拿到清晰度
        guard let clarity = Int(url[startIndex...endIndex]) else {
            throw DCDCarAtlasImageManagerError.noClarityInUrl
        }
        return clarity
    }
    
    
    /// 从图片 url 获取与分辨率无关的 key
    /// - Parameter url: 图片 url
    /// - Returns:与图片分辨率无关的 key
    private func getKey(from url: String) -> Key {
        url.components(separatedBy: ":").first ?? ""
    }
    
    
    /// 清理某个车系的缓存
    /// - Parameter seriesId: 车系 id
    @objc func clearImageMemoryCache(for seriesId: SeriesID) {
        queue.async(flags: .barrier) { [unowned self] in
            imageCache[seriesId] = [:]
        }
    }
    
    
    /// 清理所有图片缓存
    @objc func clearImageMemoryCache() {
        queue.async(flags: .barrier) { [unowned self] in
            imageCache = [:]
        }
    }
}



