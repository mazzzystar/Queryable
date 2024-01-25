//
//    PhotoSearcher.swift
//    Places
//    Created by Ke Fang on 2022/12/14.

import Foundation
import OSLog
import UIKit
import Photos
import CoreML
import Accelerate

// search result code.
 enum SEARCH_RESULT_CODE: Int {
    case DEFAULT         = -4
    case MODEL_PREPARED  = -3
    case IS_SEARCHING    = -2
    case NEVER_INDEXED   = -1
    case NO_RESULT       = 0
    case HAS_RESULT      = 1
}

// build index code.
enum BUILD_INDEX_CODE: Int {
    case DEFAULT             = -3
    case LOADING_PHOTOS      = -2
    case PHOTOS_LOADED       = -1
    case LOADING_MODEL       = 0
    case MODEL_LOADED        = 1
    case IS_BUILDING_INDEX   = 2
    case BUILD_FINISHED      = 3
}


@MainActor
class PhotoSearcher: ObservableObject {
    let defaults = UserDefaults.standard
    let photoCollection = PhotoCollection(smartAlbum: .smartAlbumUserLibrary)
    var photoSearchModel = PhotoSearcherModel()
    let EMBEDDING_DATA_NAME = "embeddingData"
    let KEY_HAS_ACCESS_TO_PHOTOS = "KEY_HAS_ACCESS_TO_PHOTOS"
    
    // -3: default, -2: Is searching now, -1: Never indexed. 0: No result. 1: Has result.
    @Published var searchResultCode: SEARCH_RESULT_CODE = .DEFAULT
    @Published var buildIndexCode: BUILD_INDEX_CODE = .DEFAULT
    @Published var totalUnIndexedPhotosNum: Int = -1
    @Published var curIndexingNums: Int = -1
    @Published var curShowingPhoto: UIImage = UIImage(systemName: "photo")!
    
    @Published var isFindingSimilarPhotos = false
    @Published var similarPhotoAssets = [PhotoAsset]()
    @Published var searchResultPhotoAssets = [PhotoAsset]()
    @Published var searchString: String = ""
    
    private(set) var savedEmbedding = [String: MLMultiArray]()
    private(set) var buildingEmbedding = [String: MLMultiArray]()
    private var curIndexingPhoto: UIImage = UIImage(systemName: "photo")!
    private var imageRequestID: PHImageRequestID?
    private var allPhotosId = [String: Int]()
    private var unIndexedPhotos = [PhotoAsset]()
    private var imageEncoder: ImgEncoder?
    private var totalPhotosNum = -1
    private let MAX_EMBEDDING_DIST: Float = 10.0
    private let BUILD_INDEX_FRAGMENT_LENGTH = 100
    private let SAVE_EMBEDDING_EVERY = 5000
    private let EMBEDDING_SIM_COMPARE_FRAGMENT_LENGTH = 1000
    private var emb_sim_dict = [String: Float32]()
    
    @Published var TOPK_SIM: Int {
        didSet {
            UserDefaults.standard.set(TOPK_SIM, forKey: "TOPK_SIM")
        }
    }

    init() {
        let defaultTOPK_SIM = UserDefaults.standard.object(forKey: "TOPK_SIM") as? Int ?? 120
        self.TOPK_SIM = defaultTOPK_SIM
    }
    
    func changeState(from statusCode1: BUILD_INDEX_CODE, to statusCode2: BUILD_INDEX_CODE) {
        if self.buildIndexCode == statusCode1 {
            self.buildIndexCode = statusCode2
        }
    }
    
    
    func prepareModelForSearch()  async {
        print("Clear cache..")
        clearCache()
        print("Cache cleared.")
        
        self.searchResultCode = .DEFAULT
        print("Loading text encoder..")
        self.photoSearchModel.load_text_encoder()
        print("Text encoder loaded.")
        if self.loadEmbeddingsData(fileName: self.EMBEDDING_DATA_NAME) {
            print("Photos embedding loaded. total \(self.savedEmbedding.count)")
        } else {
            self.searchResultCode = .NEVER_INDEXED
            print("Load photos embedding failure.")
        }
        
        // set network authorization
        await self.photoCollection.cache.requestOptions.isNetworkAccessAllowed = false
        
        // Get the current authorization state.
        let status = PHPhotoLibrary.authorizationStatus()
        if (status == .authorized) {
            // Access has been granted.
            defaults.set(true, forKey: self.KEY_HAS_ACCESS_TO_PHOTOS)
            print("KEY_HAS_ACCESS_TO_PHOTOS has been updated to true.")
        }
        
        if !self.savedEmbedding.isEmpty {
            self.searchResultCode = .MODEL_PREPARED
        }
    }
    
    func fetchPhotos() async {
        self.buildIndexCode = .LOADING_PHOTOS
        
        // set network authorization
        await self.photoCollection.cache.requestOptions.isNetworkAccessAllowed = false
        
        let authorized = await PhotoLibrary.checkAuthorization()
        guard authorized else {
            logger.error("Photo library access was not authorized.")
            return
        }
        
        Task {
            do {
                try await self.photoCollection.load()
                
                print("Total \(photoCollection.photoAssets.count) photos loaded.")
                
                defaults.set(true, forKey: self.KEY_HAS_ACCESS_TO_PHOTOS)
                
                self.totalPhotosNum = photoCollection.photoAssets.count
                
                try await self.fetchUnIndexedPhotos()
                
            } catch let error {
                logger.error("Failed to load photo collection: \(error.localizedDescription)")
            }
            
            if self.totalPhotosNum > 0 {
                self.buildIndexCode = .PHOTOS_LOADED
            }
        }
    }
    
    func loadImageIncoder() async {
        self.buildIndexCode = .LOADING_MODEL
        guard let path = Bundle.main.path(forResource: "CoreMLModels", ofType: nil, inDirectory: nil) else {
            fatalError("Fatal error: failed to find the CoreML models.")
        }
        let resourceURL = URL(fileURLWithPath: path)
        
        Task {
            do {
                let startingTime = Date()
                let imgEncoder = try ImgEncoder(resourcesAt: resourceURL)
                // 8.542439937591553 seconds used for loading img encoder
                print("\(startingTime.timeIntervalSinceNow * -1) seconds used for loading img encoder")
                self.imageEncoder = imgEncoder
                self.buildIndexCode = .MODEL_LOADED
                self.buildIndexCode = .IS_BUILDING_INDEX
            } catch let error {
                logger.error("Failed to load model: \(error.localizedDescription)")
            }
        }
    }
    
    
    func fetchSingleAssetComputeEmbedding(asset: PhotoAsset) async throws {
        var _curIndexingPhoto: UIImage? = nil
        self.imageRequestID = await photoCollection.cache.requestImage(for: asset, targetSize: CGSize(width: 224, height: 224)) { result in
            if let result = result {
                _curIndexingPhoto = result.image
            }
        }
        
        do {
            self.curIndexingPhoto = _curIndexingPhoto ?? UIImage(systemName: "photo")!
            if let _curIndexingPhoto {
                let img_emb = try await self.imageEncoder?.encode(image: _curIndexingPhoto)
                self.buildingEmbedding[asset.id] = MLMultiArray(img_emb!)
            } else {
                self.buildingEmbedding[asset.id] = MLMultiArray(defaultEmbedding())
            }
            
        } catch {
            self.buildingEmbedding[asset.id] = MLMultiArray(defaultEmbedding())
        }
        
    }
    
    func defaultEmbedding() -> MLShapedArray<Float32> {
        let _emb = try? MLMultiArray(shape: [1, 512], dataType: MLMultiArrayDataType.float32)
        // Initialize the multiarray.
        for xCoordinate in 0..<1 {
            for yCoordinate in 0..<512 {
                let key = [xCoordinate, yCoordinate] as [NSNumber]
                _emb![key] = 10.0
            }
        }
        return MLShapedArray<Float32>(converting: _emb!)
    }
    
    func batchBuildIndex(assets: [PhotoAsset]) async throws {
        await photoCollection.cache.startCaching(for: assets, targetSize: CGSize(width: 224, height: 224))
        let  processors = ProcessInfo.processInfo.activeProcessorCount
        let PART_OF_LIST = Int(assets.count / Int(processors)) + 1
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for idx in stride(from: 0, to: assets.count, by: PART_OF_LIST) {
                let endPoint = min(idx+PART_OF_LIST, assets.count)
                let part_assets = Array(assets[idx..<endPoint])
                
                group.addTask {
                    for idx in 0..<part_assets.count {
                        let asset = part_assets[idx]
                        do {
                            try await self.fetchSingleAssetComputeEmbedding(asset: asset)
                        } catch {
                            print(error)
                        }
                        
                    }
                }
                
            }
            
            
            for try await _ in group {
                // progress += 1
            }
        }
        
        await photoCollection.cache.stopCaching(for: assets, targetSize: CGSize(width: 224, height: 224))
    }
    
    func fetchAsstesComputeEmbeddings(assets: [PhotoAsset]) async throws -> [Embedding] {
        let startingTime = Date()
        await photoCollection.cache.startCaching(for: assets, targetSize: CGSize(width: 224, height: 224))
        print("\(startingTime.timeIntervalSinceNow * -1) seconds to load \(self.BUILD_INDEX_FRAGMENT_LENGTH) image cache")
        
        
        var results = [Embedding]()
        
        for idx in 0..<assets.count {
            do {
                let asset = assets[idx]
                self.imageRequestID = await photoCollection.cache.requestImage(for: asset, targetSize: CGSize(width: 224, height: 224)) { result in
                    if let result = result {
                        self.curIndexingPhoto = result.image!
                    }
                }
                
                let _emb = try await self.imageEncoder?.encode(image: self.curIndexingPhoto)
                let embeddingObject = Embedding(id: asset.phAsset!.id, embedding: MLMultiArray(_emb!))
                results.append(embeddingObject)
        
            } catch {
                //handle error
                print(error)
            }
            
        }
        await photoCollection.cache.stopCaching(for: assets, targetSize: CGSize(width: 224, height: 224))
        return results
    }
    
    
    func fetchUnIndexedPhotos() async throws {
        self.unIndexedPhotos = [PhotoAsset]()
        let startingTime = Date()
        
        for idx in 0..<self.photoCollection.photoAssets.count {
            let _cur_asset = self.photoCollection.photoAssets[idx]
            
            self.allPhotosId[_cur_asset.id] = 1
            
            if let _ = self.savedEmbedding[_cur_asset.id] {
                
            }
            else {
                self.unIndexedPhotos.append(_cur_asset)
            }
        }
        
        print("\(startingTime.timeIntervalSinceNow * -1) seconds used for filter unindex photos")
        
        self.totalUnIndexedPhotosNum = self.unIndexedPhotos.count
    }
    
    private func judgeIfAssetUnidexed(asset: PhotoAsset) async {
        if let _ = self.savedEmbedding[asset.id] {

        }
        else {
            self.unIndexedPhotos.append(asset)
        }
    }
    
    func deleteEmbeddingByAsset(asset: PhotoAsset) async {
        if let _ = self.savedEmbedding[asset.id] {
            self.savedEmbedding.removeValue(forKey: asset.id)
            print("\(asset.id) deleted.")
        }
    }
    
    func updateEmbedding(new_indexed_results: [String: MLMultiArray]) {
        // update results
        print("Before update, embedding count=\(self.savedEmbedding.count)")
        for key in new_indexed_results.keys {
            self.savedEmbedding[key] = new_indexed_results[key]
        }
        
        var final_all_results = [Embedding]()
        
        for key in self.savedEmbedding.keys {
            let _embedding = Embedding(id: key, embedding: self.savedEmbedding[key]!)
            final_all_results.append(_embedding)
        }
        
        print("After update, embedding count=\(self.savedEmbedding.count)")
        if self.saveEmbeddingsData(embeddings: final_all_results, fileName: self.EMBEDDING_DATA_NAME) {
            print("Embedding saved")
        } else {
            print("Embedding not saved")
        }
        
        final_all_results = [Embedding]()
    }

    /**
     Build index
     */
    func buildIndex() async {
        self.buildingEmbedding = [String: MLMultiArray]()
        
        // set network authorization
        await self.photoCollection.cache.requestOptions.isNetworkAccessAllowed = false
        
        do {
             for idx in stride(from: 0, to: self.unIndexedPhotos.count, by: self.BUILD_INDEX_FRAGMENT_LENGTH) {
                 let endPoint = min(idx+self.BUILD_INDEX_FRAGMENT_LENGTH, self.unIndexedPhotos.count)
                 let assets = Array(self.unIndexedPhotos[idx..<endPoint])
                 
                 // Speed is 2000 photos @ 1min.
                 try await self.batchBuildIndex(assets: assets)
                 
                 // Speed is 2000 photos @ 1min 19s
                 // let batch_results = try await self.fetchAsstesComputeEmbeddings(assets: assets)
                
                 self.curIndexingNums += assets.count
                 self.curShowingPhoto = self.curIndexingPhoto
                 
                 if curIndexingNums > 0 && self.buildingEmbedding.count >= SAVE_EMBEDDING_EVERY {
                     print("Save index for \(curIndexingNums) images.")
                     self.updateEmbedding(new_indexed_results: self.buildingEmbedding)
                     self.buildingEmbedding = [String: MLMultiArray]()
                 }
            }
            
            // save embeddding
            self.updateEmbedding(new_indexed_results: self.buildingEmbedding)

        } catch {
            self.updateEmbedding(new_indexed_results: self.buildingEmbedding)
        }
        
        // delete large memory usage
        self.buildingEmbedding = [String: MLMultiArray]()
        self.imageEncoder = nil
        self.buildIndexCode = .BUILD_FINISHED
        self.totalUnIndexedPhotosNum = 0
        
        clearCache()
        print("Loading text encoder..")
        self.photoSearchModel.load_text_encoder()
        print("Text encoder loaded.")

    }
    
    func loadEmbeddingsData(fileName: String) -> Bool {
        //Code from https://stackoverflow.com/questions/74871767/how-to-unarchive-mlmultiarray-with-nskeyedunarchiver
        let filePath = self.getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let startingTime = Date()
            let data = try Data(contentsOf: filePath)
            let embeddings = try NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClasses: [Embedding.self, MLMultiArray.self, NSString.self], from: data) as? [Embedding]
            print("\(startingTime.timeIntervalSinceNow * -1) seconds used for loading embeddingData")
            
            for idx in 0..<embeddings!.count {
                let cur_emb = embeddings![idx]
                self.savedEmbedding[cur_emb.id!] = cur_emb.embedding
            }

            print("total saved embedding num: \(self.savedEmbedding.count)")
            return true
        } catch {
            print("error is: \(String(describing: error))")
        }
        return false
    }
    
    private func saveEmbeddingsData(embeddings: [Embedding], fileName: String) -> Bool {
        let filePath = self.getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: embeddings, requiringSecureCoding: true)
            try data.write(to: filePath)
            return true
        } catch {
            print("error is: \(error.localizedDescription)")
        }
        return false
    }
    
    private func getDocumentsDirectory() -> URL {
        let arrayPaths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return arrayPaths[0]
    }
    
    
    /**
     Search Part
     */
    func search(with query: String) async {
        // clean before results.
        self.searchString = query
        self.searchResultPhotoAssets = [PhotoAsset]()
        
        self.searchResultCode = .IS_SEARCHING
        Task {
            do {
                if self.savedEmbedding.isEmpty {
                    print("Never indexed.")
                    self.searchResultCode = .NEVER_INDEXED
                } else {
                    // search from indexed result
                    print("Has indexed data, now begin to search.")
                    print("Test if I can fetch all photos: \(self.photoCollection.photoAssets.count)")
                    
                    // Filter whether Photo has been deleted.
                    if !self.allPhotosId.isEmpty {
                        let startingTime = Date()
                        
                        var cnt = 0
                        for key in self.savedEmbedding.keys {
                            if let _ = self.allPhotosId[key] {
                            } else {
                                cnt += 1
                                self.savedEmbedding.removeValue(forKey: key)
                            }
                        }
                        print("\(cnt) keys in savedEmbedding has been deleted.")
                        
                        if cnt > 0 {
                            self.updateEmbedding(new_indexed_results: [String : MLMultiArray]())
                        }
                        print("\(startingTime.timeIntervalSinceNow * -1) seconds used for save the updated embedding to file.")
                    }
                    
                    print("Searching query = \(query)")
                    let _text_emb = self.photoSearchModel.text_embedding(prompt: query)
                    print(_text_emb)
                    
                    let startingTime = Date()
        
                    
                    let img_emb_pieces_lst = self.seperateEmbeddingsByCoreNums(img_embs_dict: self.savedEmbedding)
                    
                    // 6.69201397895813 seconds used for calculat sim between 34639 embs before.
                    // self.simpleComputeAllEmbeddingSim(text_emb: _text_emb, img_emb_pieces_lst: img_emb_pieces_lst)
                    
                    // reduce to 2.8s.
                    try await self.batchComputeEmbeddingSimilarity(text_emb: _text_emb, img_embs_dict_lst: img_emb_pieces_lst)
                    print("\(startingTime.timeIntervalSinceNow * -1) seconds used for calculat sim between \(self.savedEmbedding.keys.count) embs.")
                    
                    let startingTime2 = Date()
                    // 0.20966589450836182 seconds used for find top3 sim in 34639 scores.
                    
                    let FINAL_TOP_K = min(self.TOPK_SIM, self.emb_sim_dict.count)
                    let topK_sim = self.emb_sim_dict.sorted { $0.value > $1.value }.prefix(FINAL_TOP_K)
                    print("\(startingTime2.timeIntervalSinceNow * -1) seconds used for find top\(FINAL_TOP_K) sim in \(self.emb_sim_dict.keys.count) scores.")
                    
                    let startingTime3 = Date()
                    
                    for photo in topK_sim {
                        let photoSim = photo.value
                        let photoID = photo.key
                        print(photoID, photoSim)
                        
                        let _asset = PhotoAsset(identifier: photoID)
                        self.searchResultPhotoAssets.append(_asset)
                    }
                    print("\(startingTime3.timeIntervalSinceNow * -1) seconds used for download top\(FINAL_TOP_K) sim images.")
                    
                    self.searchResultCode = .HAS_RESULT
                }
                
            } catch let error {
                logger.error("Failed to search photos: \(error.localizedDescription)")
            }
        }
    }
    
    
    /**
     Similarity ranking
     */
    func similarPhoto(with photoAsset: PhotoAsset) async {
        self.isFindingSimilarPhotos = true
        self.similarPhotoAssets = [PhotoAsset]()
        Task {
            do {
                let _img_emb = MLShapedArray<Float32>(converting: self.savedEmbedding[photoAsset.id]!)
                print(_img_emb)
                let startingTime = Date()
    
                let img_emb_pieces_lst = self.seperateEmbeddingsByCoreNums(img_embs_dict: self.savedEmbedding)
                // reduce to 2.8s.
                try await self.batchComputeEmbeddingSimilarity(text_emb: _img_emb, img_embs_dict_lst: img_emb_pieces_lst)
                print("\(startingTime.timeIntervalSinceNow * -1) seconds used for calculat sim between \(self.savedEmbedding.keys.count) embs.")
                
                let startingTime2 = Date()
                // 0.20966589450836182 seconds used for find top3 sim in 34639 scores.
                
                let FINAL_TOP_K = min(self.TOPK_SIM, self.emb_sim_dict.count)
                let topK_sim = self.emb_sim_dict.sorted { $0.value > $1.value }.prefix(FINAL_TOP_K)
                print("\(startingTime2.timeIntervalSinceNow * -1) seconds used for find top\(FINAL_TOP_K) sim in \(self.emb_sim_dict.keys.count) scores.")
                
                let startingTime3 = Date()
                
                for photo in topK_sim {
                    let photoSim = photo.value
                    let photoID = photo.key
                    print(photoID, photoSim)
                    
                    let _asset = PhotoAsset(identifier: photoID)
                    self.similarPhotoAssets.append(_asset)
                }
                print("\(startingTime3.timeIntervalSinceNow * -1) seconds used for download top\(FINAL_TOP_K) sim images.")
                
                self.isFindingSimilarPhotos = false
                
            } catch let error {
                logger.error("Failed to search photos: \(error.localizedDescription)")
            }
        }
    }
    
    private func seperateEmbeddingsByCoreNums(img_embs_dict: [String: MLMultiArray]) -> [[String: MLMultiArray]]{
        let  processors = ProcessInfo.processInfo.activeProcessorCount
        let PART_OF_LIST = Int(img_embs_dict.count / Int(processors)) + 1
        
        var cnt = 0
        var img_emb_piece = [String: MLMultiArray]()
        var img_emb_pieces_lst = [[String: MLMultiArray]()]
        for emb in img_embs_dict {
            img_emb_piece[emb.key] = emb.value
            cnt += 1
            if img_emb_piece.count == PART_OF_LIST ||  cnt == img_embs_dict.count {
                img_emb_pieces_lst.append(img_emb_piece)
                img_emb_piece = [String: MLMultiArray]()
            }
        }
        
        print("Total \(img_emb_pieces_lst.count) pieces.")
        for emb_dict in img_emb_pieces_lst {
            print("\(emb_dict.count)")
        }
        
        return img_emb_pieces_lst
    }
    
    private func batchComputeEmbeddingSimilarity(text_emb: MLShapedArray<Float32>, img_embs_dict_lst: [[String: MLMultiArray]]) async throws {
        self.emb_sim_dict = [String: Float32]()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for emb_dict in img_embs_dict_lst {
                if !emb_dict.isEmpty {
                    group.addTask {
                        for key in emb_dict.keys {
                            let cur_img_emb = emb_dict[key]
                            await self.computeSingleEmbeddingSim(text_emb: text_emb, img_emb: cur_img_emb!, img_id: key)
                        } 
                    }
                }
            }
            
            for try await _ in group {
                // progress += 1
            }
        }
        
    }
    
    private func simpleComputeAllEmbeddingSim(text_emb: MLShapedArray<Float32>, img_embs_dict: [String: MLMultiArray]) async {
        for key in img_embs_dict.keys {
            let cur_img_emb = img_embs_dict[key]
            await self.computeSingleEmbeddingSim(text_emb: text_emb, img_emb: cur_img_emb!, img_id: key)
        }
    }
    
    private func computeSingleEmbeddingSim(text_emb: MLShapedArray<Float32>, img_emb: MLMultiArray, img_id: String) async {
//        if img_emb.count == 0 {
//            self.emb_sim_dict[img_id] = MAX_EMBEDDING_DIST
//            return
//        }
        let img_emb = MLShapedArray<Float32>(converting: img_emb)
        let sim = await self.photoSearchModel.cosine_similarity(A: text_emb, B: img_emb)
        self.emb_sim_dict[img_id] = sim
    }
    
}


public func clearCache(){
    URLCache.shared.removeAllCachedResponses()
    
    do {
        let tmpDirURL = FileManager.default.temporaryDirectory
        let tmpDirectory = try FileManager.default.contentsOfDirectory(atPath: tmpDirURL.path)
        try tmpDirectory.forEach { file in
            let fileUrl = tmpDirURL.appendingPathComponent(file)
            print("File to be removed: \(fileUrl)")
            try FileManager.default.removeItem(atPath: fileUrl.path)
        }
    } catch {
        //catch the error somehow
    }
}


fileprivate let logger = Logger(subsystem: "com.mazzystar.Queryable", category: "PhotoSearcher")
