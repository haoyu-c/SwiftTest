//
//  DCDAsyncCarAtlasImageManager.swift
//  DCDAsyncCarAtlasImageManager
//
//  Created by chenhaoyu.1999 on 2021/8/28.
//

import SwiftUI
import SDWebImage

//TODO: 添加取消任务的逻辑

actor DCDAsyncCarAtlasImageManager: NSObject {
    
    @objc static let shared = DCDAsyncCarAtlasImageManager()
    
    private typealias SeriesID = String
    private typealias Key = String
    private typealias Clarity = Int
    
    private var group: ThrowingTaskGroup<ImageInfo, Error>?
    
    /// 图片缓存
    // only allowing their stored instance properties to be accessed directly on self
    private var imageCache = [SeriesID: [Key: [Clarity: Image]]]()
    
    private typealias ImageInfo = (image: Image?,key: Key,clarity: Clarity, url: String)
    
    private func getOrFetchImage(for seriesId: String, with url:String, size: CGSize) async throws -> ImageInfo {
        // 拿到去掉清晰度的 URL 作为 imageCache 的二级 key
        let imageKey = getKey(from: url)
        // 从 URL 拿到清晰度作为三级 key
        let clarity = try getClarityFrom(url: url)
        // 获取缓存
        if let cache = imageCache[seriesId]?[imageKey] {
            // 判断是否有相应或者更高品质的图片缓存
            let maxClarity = cache.keys.max() ?? 0
            if maxClarity >= clarity, let cachedImage = cache[maxClarity] {
                print("从缓存获取成功")
                return (cachedImage, imageKey, clarity, url)
            }
        }
        // 获取网络图片
        let image = try await SDWebImageDownloader.shared.downloadImageAsync(with: URL(string: url))
        return (image, imageKey, clarity, url)
    }
    
    /// 获取多张图片
    /// - Parameters:
    ///   - seriesId: 车系 id
    ///   - urls: 图片 url
    ///   - firstImageCompletion: 获取第一张图片就完成回调, 及时展示第一张图片
    ///   - completion: 获取所有图片完成回调
    func getOrFetchImages(for seriesId: String, with urls:[String], size: CGSize, firstImageCompletion:  @escaping ((Image) -> Void)) async throws -> [String: Image] {
        guard !urls.isEmpty else { throw DCDCarAtlasImageManagerError.emptyUrl }
        group?.cancelAll()
        var imageMap = [String: Image]()
        let firstImageInfo = try await getOrFetchImage(for: seriesId, with: urls[0], size: size)
        guard let firstImage = firstImageInfo.image else {throw DCDCarAtlasImageManagerError.noFirstImage}
        firstImageCompletion(firstImage)
        imageCache[seriesId, default: [:]][firstImageInfo.key, default: [:]][firstImageInfo.clarity] = firstImage
        imageMap[urls[0]] = firstImage
        var imageCache = self.imageCache
        try await withThrowingTaskGroup(of: ImageInfo.self) { group in
            // 添加 unowned self 会导致这里报错, actor isolated 和 non actor isolated
            self.group = group
            self.imageCache = [:]
            for (index, url) in urls.enumerated() where index != 0 {
                let _ = group.addTaskUnlessCancelled{
                    try await self.getOrFetchImage(for: seriesId, with: url, size: size)
                }
            }
            for _ in 0..<urls.count-1 {
                switch try await group.nextResult() {
                    case .success(let imageInfo):
                    // 如果使用 self.imageCache Actor-isolated property 'imageCache' cannot be passed 'inout' to 'async' function call
                    imageCache[seriesId, default: [:]][imageInfo.key, default: [:]][imageInfo.clarity] = imageInfo.image
                    imageMap[imageInfo.url] = imageInfo.image
                    case .failure(let e):
                        print("无法获取图片", e)
                    case .none:
                        continue
                }
            }
        }
        self.imageCache = imageCache
        return imageMap
    }
    
    private func set(group: ThrowingTaskGroup<ImageInfo, Error>) async {
        self.group = group
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
    @objc func clearImageMemoryCache(for seriesId: String) async {
        imageCache[seriesId] = [:]
    }
    
    
    /// 清理所有图片缓存
    @objc func clearImageMemoryCache() async {
        imageCache = [:]
    }
}

extension SDWebImageDownloader {
    enum ImageDownloadError: Error {
        case taskCancelled
    }
    func downloadImageAsync(with url: URL?) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            if Task.isCancelled {
                continuation.resume(throwing: ImageDownloadError.taskCancelled)
            }
            SDWebImageDownloader.shared.downloadImage(with: url) { image, _, error, _ in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: image!)
                }
            }
        }
    }
}



