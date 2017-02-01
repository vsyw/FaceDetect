//
//  ViewController.swift
//  FaceDetection
//
//  Created by victor.sy_wang on 1/10/17.
//  Copyright © 2017 victor. All rights reserved.
//

import UIKit
import AVFoundation
import Alamofire
import SwiftyJSON
import PKHUD

class DetectViewController: UIViewController,AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
    var previewLayer: AVCaptureVideoPreviewLayer!
    var faceRectCALayer: CALayer!
    var isBackCamera = true
    
    fileprivate var currentCameraFace: AVCaptureDevice?
    fileprivate var sessionQueue: DispatchQueue = DispatchQueue(label: "videoQueue", attributes: [])
    
    fileprivate var session: AVCaptureSession!
    fileprivate var backCameraDevice: AVCaptureDevice?
    fileprivate var frontCameraDevice: AVCaptureDevice?
    fileprivate var cameraDevice: AVCaptureDevice?
    fileprivate var metadataOutput: AVCaptureMetadataOutput!
    fileprivate var input: AVCaptureDeviceInput!
    fileprivate var cameraOutput = AVCapturePhotoOutput()
    fileprivate var resultImage = UIImage()
    fileprivate var faceRect = CGRect()
    
    fileprivate var newFaceName = String()
    fileprivate var isToggleAddButton = false
    
    @IBAction func switchCamera(_ sender: Any) {
        changeInputDevice()
    }
    
    @IBAction func addFace(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(
            title: "Add A New Face",
            message: "Please enter the name of whom you want to add",
            preferredStyle: UIAlertControllerStyle.alert
        )
        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel)
        )
        alert.addAction(UIAlertAction(title: "Done", style: .default) {
            [unowned self] (action: UIAlertAction) -> Void in
                self.newFaceName = alert.textFields?.first?.text ?? ""
                //print("here \(alert.textFields?.first.text)")
        })
    
        alert.addTextField(configurationHandler: {(textFiled) in
            textFiled.placeholder = "Name or ID"
        })
        present(alert, animated: true, completion: nil)

    }
    
//    @IBAction func cameraSwitcher(_ sender: UIButton) {
//        changeInputDevice()
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinch))
        view.addGestureRecognizer(pinchGestureRecognizer)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap))
        view.addGestureRecognizer(tapGestureRecognizer)
        setupSession()
        setupPreview()
        setupFace()
        startSession()
        //        print("if its' auto focus", backCameraDevice?.isFocusModeSupported(.continuousAutoFocus) ?? false)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        session.stopRunning()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func focusAndExposeTap(gestureRecognizer: UITapGestureRecognizer) {
        print("focus")
        let devicePoint = self.previewLayer.captureDevicePointOfInterest(for: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
    }
    
    private func focus(with focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        sessionQueue.async { [unowned self] in
            if let device = self.input.device {
                do {
                    try device.lockForConfiguration()
                    
                    /*
                     Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                     Call set(Focus/Exposure)Mode() to apply the new point of interest.
                     */
                    print("device \(device)")
                    if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                        device.focusPointOfInterest = devicePoint
                        device.focusMode = focusMode
                        print("in side ")
                    }
                    
                    if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                        device.exposurePointOfInterest = devicePoint
                        device.exposureMode = exposureMode
                    }
                    
                    device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                    device.unlockForConfiguration()
                }
                catch {
                    print("Could not lock device for configuration: \(error)")
                }
            }
        }
    }
    
    // Mark: - Setup pinch gesture recognizer
    // Reference: http://stackoverflow.com/questions/33180564/pinch-to-zoom-camera
    
    func pinch(gestureRecognizer: UIPinchGestureRecognizer) {
        print("pinch", gestureRecognizer)
        
        var device: AVCaptureDevice = self.backCameraDevice!
        var vZoomFactor = gestureRecognizer.scale
        var error:NSError!
        do{
            try device.lockForConfiguration()
            defer {device.unlockForConfiguration()}
            if (vZoomFactor <= device.activeFormat.videoMaxZoomFactor) {
                device.videoZoomFactor = max(1.0, min(vZoomFactor, device.activeFormat.videoMaxZoomFactor))
                print("zoom factor", device.videoZoomFactor)
            }
            else {
                
                NSLog("Unable to set videoZoom: (max %f, asked %f)", device.activeFormat.videoMaxZoomFactor, vZoomFactor)
            }
        }
        catch error as NSError{
            
            NSLog("Unable to set videoZoom: %@", error.localizedDescription)
        }
        catch _{
            
        }
    }
    
    // MARK: - Setup session and preview
    
    func setupSession(){
        session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetHigh
        
        let avaliableCameraDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        for device in avaliableCameraDevices as! [AVCaptureDevice]{
            if device.position == .back {
                backCameraDevice = device
                try! backCameraDevice?.lockForConfiguration()
                backCameraDevice?.focusMode = .continuousAutoFocus
                backCameraDevice?.unlockForConfiguration()
            } else if device.position == .front{
                frontCameraDevice = device
            }
        }
        
        do {
            if self.isBackCamera {
                cameraDevice = backCameraDevice
            } else {
                cameraDevice = frontCameraDevice
            }
            
            try! cameraDevice?.lockForConfiguration()
            cameraDevice?.focusMode = .continuousAutoFocus
            cameraDevice?.unlockForConfiguration()
            
            self.input = try AVCaptureDeviceInput(device: cameraDevice)
            if session.canAddInput(input){
                session.addInput(input)
            }
        } catch {
            print("Error handling the camera Input: \(error)")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: sessionQueue)
            metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
        }

        if session.canAddOutput(cameraOutput) {
            session.addOutput(cameraOutput)
        }
        
    }
    
    func setupPreview(){
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.affineTransform()
        
        view.layer.insertSublayer(previewLayer, at: 0)
        
    }
    
    func startSession() {
        if !session.isRunning{
            session.startRunning()
        }
    }
    
    func changeInputDevice() {
        /* Remove face bounds first */
        for (idx, e) in (previewLayer.sublayers?.enumerated())! {
            if (idx > 0) {
                e.removeFromSuperlayer();
            }
        }
        
        /* Remove oldInput and add new inputDevice */
        do {
            session.removeInput(input)
            input = try AVCaptureDeviceInput(device: isBackCamera ? frontCameraDevice : backCameraDevice)
            if session.canAddInput(input){
                session.addInput(input)
                self.isBackCamera = !self.isBackCamera
            }
            
        } catch {
            print("Error handling the camera Input: \(error)")
            return
        }
    }
    
    func setupFace(){
        faceRectCALayer = CALayer()
        faceRectCALayer.zPosition = 1
        faceRectCALayer.borderColor = UIColor.red.cgColor
        faceRectCALayer.borderWidth = 3.0
    }
    
    func mySetupFace(_ faces : Array<CGRect>) {
        //        previewLayer.sublayers = nil
        //        previewLayer.sublayers?.forEach {
        //            $0.removeFromSuperlayer()
        //        }
        //        print("\n")
        //        print(previewLayer.sublayers?.count)
        for (idx, e) in (previewLayer.sublayers?.enumerated())! {
            if (idx > 0) {
                e.removeFromSuperlayer();
            }
        }
        
        for face in faces {
            let faceRect = CALayer()
            faceRect.zPosition = 1
            faceRect.borderColor = UIColor.red.cgColor
            faceRect.borderWidth = 3.0
            faceRect.frame = face
            previewLayer.addSublayer(faceRect)
        }
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        var faces = [CGRect]()
        connection.automaticallyAdjustsVideoMirroring = true
        for metadataObject in metadataObjects as! [AVMetadataObject] {
            if metadataObject.type == AVMetadataObjectTypeFace {
                let transformedMetadataObject = previewLayer.transformedMetadataObject(for: metadataObject)
                faceRect = (transformedMetadataObject?.bounds)!

                print("face bounds", faceRect)
                faces.append(faceRect)
            }
        }
        
//        print("FACE",faces)
        
        if faces.count > 0 {
            //            setlayerHidden(false)
            DispatchQueue.main.async(execute: {
                () -> Void in
                self.mySetupFace(faces)
                //                self.faceRectCALayer.frame = self.findMaxFaceRect(faces)
            })
        } else {
            DispatchQueue.main.async(execute: {
                () -> Void in
                for (idx, e) in (self.previewLayer.sublayers?.enumerated())! {
                    if (idx > 0) {
                        e.removeFromSuperlayer();
                    }
                }
            })
            //            previewLayer.sublayers = nil;
            //            setlayerHidden(true)
        }
    }
    
    func setlayerHidden(_ hidden: Bool) {
        if (faceRectCALayer.isHidden != hidden){
            print("hidden:" ,hidden)
            DispatchQueue.main.async(execute: {
                () -> Void in
                self.faceRectCALayer.isHidden = hidden
            })
        }
    }
    
    func findMaxFaceRect(_ faces : Array<CGRect>) -> CGRect {
        if (faces.count == 1) {
            return faces[0]
        }
        var maxFace = CGRect.zero
        var maxFace_size = maxFace.size.width + maxFace.size.height
        for face in faces {
            let face_size = face.size.width + face.size.height
            if (face_size > maxFace_size) {
                maxFace = face
                maxFace_size = face_size
            }
        }
        return maxFace
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        print("capture photo");
        print("name", self.newFaceName)
        let settings = AVCapturePhotoSettings()
        settings.isAutoStillImageStabilizationEnabled = true
        settings.isHighResolutionPhotoEnabled = false
        self.cameraOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let photoSampleBuffer = photoSampleBuffer {
            let photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
            if let image = UIImage(data: photoData!) {
                self.resultImage = image
            }
            if self.newFaceName.characters.count > 0 {
                print("fuck")
                HUD.show(.progress)
                detectFace(self.resultImage, user_id: self.newFaceName, setUserId: setUserID)
            } else {
                performSegue(withIdentifier: "showSearchResults", sender: self)
    //            UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showSearchResults" {
            if let destinationvc = segue.destination as? SearchResultsViewController {
                destinationvc.resultImage = self.resultImage
                destinationvc.resultFaceRect = self.faceRect
            }
        }
    }
    
    func detectFace(_ image: UIImage?, user_id: String, setUserId: @escaping (String, String, @escaping(String) -> Void) -> Void) {
        //        let img = UIImage(named: "people")
        let img = FaceConstants.fixOrientation(image!)
        Alamofire.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(FaceConstants.key.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withName: "api_key")
                multipartFormData.append(FaceConstants.secret.data(using: String.Encoding.utf8, allowLossyConversion: false)!, withName: "api_secret")
                multipartFormData.append(UIImageJPEGRepresentation(img, 1.0)!, withName: "image_file", fileName: "file.jpeg", mimeType: "image/jpeg")
        },
        to: FaceConstants.faceApiBaseURL + "detect",
        encodingCompletion: {[unowned self] encodingResult in
            switch encodingResult {
            case .success(let upload, _, _):
                upload.responseJSON { response in
                    debugPrint(response)
                    if let value = response.result.value {
                        let result = JSON(value)
                        print("result \(result["faces"][0]["face_token"].string)")
                        setUserId(result["faces"][0]["face_token"].string!, user_id, self.addFace)
                    }
                }
            case .failure(let encodingError):
                print(encodingError)
            }
        })
    }
    
    func setUserID(_ token: String, user_id: String, addFace: @escaping (String) -> Void) {
        print("fire set user id api")
        let parameters: Parameters = [
            "api_key": FaceConstants.key,
            "api_secret": FaceConstants.secret,
            "face_token": token,
            "user_id": user_id
        ]
        Alamofire.request(FaceConstants.faceApiBaseURL + "face/setuserid", method: .post, parameters: parameters).responseJSON { response in
                switch response.result {
                case .success:
                    addFace(token)
                case .failure(let error):
                    print(error)
            }
            
        }
    }
    
    func addFace(token: String) {
        let parameters: Parameters = [
            "api_key": FaceConstants.key,
            "api_secret": FaceConstants.secret,
            "face_tokens": token,
            "outer_id": FaceConstants.faceSet_outer_id
        ]
        Alamofire.request(FaceConstants.faceApiBaseURL + "faceset/addface", method: .post, parameters: parameters).responseJSON { response in
            HUD.flash(.success, delay: 1.0)
            debugPrint(response)
        }
        self.newFaceName = ""
    }
}
