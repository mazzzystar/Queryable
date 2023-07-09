//
//  PhotoSearcherModel.swift
//  TestEncoder
//
//  Created by Ke Fang on 2022/12/08.
//
import UIKit
import CoreML
import Foundation
import Accelerate

struct PhotoSearcherModel {
    // TODO: Seperate TextEncode & ImgEncoder. Because only text encoder is needed
    // TODO: when searching.
    private var texEncoder: TextEncoder?
    
    mutating func load_text_encoder() {
        guard let path = Bundle.main.path(forResource: "CoreMLModels", ofType: nil, inDirectory: nil) else {
            fatalError("Fatal error: failed to find the CoreML models.")
        }
        let resourceURL = URL(fileURLWithPath: path)
        // TODO: move the pipeline creation to background task because it's heavy
        
        let encoder = try! TextEncoder(resourcesAt: resourceURL)
        texEncoder = encoder
    }
    
    func text_embedding(prompt: String) -> MLShapedArray<Float32> {
        let emb = try! texEncoder?.computeTextEmbedding(prompt: prompt)
        return emb!
    }
    
//    func img_embedding(image: UIImage) -> MLShapedArray<Float32> {
//        let emb = try! clip.computeImgEmbedding(img: image)
//        return emb
//    }
    
    func cosine_similarity(A: MLShapedArray<Float32>, B: MLShapedArray<Float32>) -> Float {
        let magnitude = vDSP.rootMeanSquare(A.scalars) * vDSP.rootMeanSquare(B.scalars)
        let dotarray = vDSP.dot(A.scalars, B.scalars)
        return  dotarray / magnitude
    }
    
    /**
    # Python version of spherical_dist_loss
    def spherical_dist_loss(x, y):
        x = F.normalize(x, dim=-1)
        y = F.normalize(y, dim=-1)
        return (x - y).norm(dim=-1).div(2).arcsin().pow(2).mul(2)
     */
    
    func spherical_dist_loss(A: MLShapedArray<Float32>, B: MLShapedArray<Float32>) async -> Float {
        let a = vDSP.divide(A.scalars, sqrt(vDSP.sumOfSquares(A.scalars)))
        let b = vDSP.divide(B.scalars, sqrt(vDSP.sumOfSquares(B.scalars)))
        
        let magnitude = sqrt(vDSP.sumOfSquares(vDSP.subtract(a, b)))
        return pow(asin(magnitude / 2.0), 2) * 2.0
    }
    
//    func calculate_emb_for_all_photos(images: [Photo]) -> MLShapedArray<Float32> {
//        for image in images {
//            let emb = try! clip.computeImgEmbedding(img: image)
//        }
//
//        return emb
//    }

}
