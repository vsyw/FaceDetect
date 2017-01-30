//
//  SearchResultsViewController.swift
//  FaceDetection
//
//  Created by victor.sy_wang on 1/18/17.
//  Copyright © 2017 victor. All rights reserved.
//

import UIKit
import Alamofire

class SearchResultsViewController: UIViewController {

    var resultImage: UIImage?
    
    @IBOutlet weak var ResultImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
