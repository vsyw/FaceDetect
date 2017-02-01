//
//  SearchResultsViewController.swift
//  FaceDetection
//
//  Created by victor.sy_wang on 1/18/17.
//  Copyright © 2017 victor. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import PKHUD

class SearchResultsViewController: UIViewController {

    var resultImage: UIImage?
    var resultFaceRect = CGRect()
    
    @IBOutlet weak var ResultImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        HUD.dimsBackground = true
        ResultImageView.image = resultImage ?? nil
        searchFace(image: ResultImageView.image!)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func parseFaceRect(faceRect: JSON) -> CGRect {
        return CGRect(
            x: CGFloat(faceRect["left"].floatValue / 2),
            y: CGFloat(faceRect["top"].floatValue / 2),
            width: CGFloat(faceRect["width"].floatValue / 2),
            height: CGFloat(faceRect["height"].floatValue / 2)
        )
    }
    
    
    func searchFace(image: UIImage) {
        let img = FaceConstants.fixOrientation(image)
        HUD.show(.progress)
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(FaceConstants.key.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withName: "api_key")
                multipartFormData.append(FaceConstants.secret.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withName: "api_secret")
                multipartFormData.append(FaceConstants.faceSet_outer_id.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withName: "outer_id")
                multipartFormData.append(UIImageJPEGRepresentation(img, 1.0)!, withName: "image_file", fileName: "file.jpeg", mimeType: "image/jpeg")
        },
            to: FaceConstants.faceApiBaseURL + "search",
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.responseJSON {[unowned self] response in
                        debugPrint(response)
                        if let value = response.result.value {
                            let result = JSON(value)
//                            let faceRect = result["faces"][0]["face_rectangle"]
                            let faceRect = self.parseFaceRect(faceRect: result["faces"][0]["face_rectangle"])
                            let name = result["results"][0]["user_id"].string
                            DispatchQueue.main.async(execute: {
                              () -> Void in
                                self.setupFace(faceRect, displayedName: name)
                            })
                            print("show me the result", faceRect)
                        }
                        HUD.hide()
                    }
                case .failure(let encodingError):
                    print(encodingError)
                    HUD.hide()
                }
        })
    }

    func setupFace(_ faceRect: CGRect, displayedName: String?) {
        let faceLayer = CALayer()
        
        faceLayer.borderColor = UIColor.red.cgColor
        faceLayer.borderWidth = 3.0
        faceLayer.frame = self.resultFaceRect
        view.layer.addSublayer(faceLayer)
        
        let labelRect = CGRect(
            x: self.resultFaceRect.origin.x,
            y: self.resultFaceRect.origin.y - 80,
            width: 100,
            height: 40
        )
        let label = UILabel(frame: labelRect)
        label.backgroundColor = UIColor.lightGray
        
        if let name = displayedName {
            label.text = name
        } else {
            label.text = "Not Found"
        }
        view.addSubview(label)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
