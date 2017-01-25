//
//  SearchResultsViewController.swift
//  FaceDetection
//
//  Created by victor.sy_wang on 1/18/17.
//  Copyright © 2017 victor. All rights reserved.
//

import UIKit

class SearchResultsViewController: UIViewController {
    
    var resultImage: UIImage? {
        didSet {
            updateUI()
            
        }
    }
    
    fileprivate func updateUI() {
//        print("did set", resultImage)
    }
    
    var testString = String()
    
//    fileprivate func updateUI() {
//        if ResultImageView != nil {
//            ResultImageView.image = resultImage
//        }
//    }
    override func awakeFromNib() {
        print("awake from nib", resultImage == nil)
    }
    
    @IBOutlet weak var ResultImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("in the viewDidLoad \(testString)")
        print((resultImage == nil))
        ResultImageView.image = resultImage ?? nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
