//
//  Embedding.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/20.
//

import Foundation
import CoreML

class Embedding: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool = true
    
    var id: String?
    var embedding: MLMultiArray?
    
    init(id: String, embedding: MLMultiArray) {
        self.id = id
        self.embedding = embedding
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.id, forKey: "id")
        aCoder.encode(self.embedding, forKey: "embedding")
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.id = aDecoder.decodeObject(forKey: "id") as? String
        self.embedding = aDecoder.decodeObject(forKey: "embedding") as? MLMultiArray
    }
}
