//
//  FaceConstants.swift
//  FaceDetection
//
//  Created by victor.sy_wang on 2/1/17.
//  Copyright © 2017 victor. All rights reserved.
//

import UIKit
import Foundation

struct FaceConstants {
    static let key = "-UpIe-nO4Zr-AwPjei1eydesDt-7w53c"
    static let secret = "hZzBR3U_-bWelN6qQBDQ-BEMwOvJn_zV"
    static let faceSet_outer_id = "testSet"
    static let faceApiBaseURL = "https://api-cn.faceplusplus.com/facepp/v3/"
    static let testIMG = "http://img3.cache.netease.com/ent/2012/5/29/201205290821195f1ff.jpg"
    static let testURL = "http://img3.cache.netease.com/ent/2012/5/29/201205290821195f1ff.jpg"
    
    static func fixOrientation(_ img:UIImage) -> UIImage {
        
        if (img.imageOrientation == UIImageOrientation.up) {
            return img;
        }
        
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale);
        let rect = CGRect(x: 0, y: 0, width: img.size.width, height: img.size.height)
        img.draw(in: rect)
        
        let normalizedImage : UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext();
        return normalizedImage;
        
    }
}
