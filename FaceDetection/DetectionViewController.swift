//
//  ViewController.swift
//  FaceDetection
//
//  Created by victor.sy_wang on 1/10/17.
//  Copyright © 2017 victor. All rights reserved.
//

import UIKit
import AVFoundation

class DetectViewController: UIViewController,AVCaptureMetadataOutputObjectsDelegate {
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
    
    @IBAction func cameraSwitcher(_ sender: UIButton) {
        changeInputDevice()
    }
    
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
        
        for metadataObject in metadataObjects as! [AVMetadataObject] {
            if metadataObject.type == AVMetadataObjectTypeFace {
                let transformedMetadataObject = previewLayer.transformedMetadataObject(for: metadataObject)
                let face = transformedMetadataObject?.bounds
                faces.append(face!)
            }
        }
        
        print("FACE",faces)
        
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
    
    
    
    
}
