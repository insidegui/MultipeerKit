//
//  ViewController.swift
//  RemoteCamera
//
//  Created by Oliver Michalak on 01.03.20.
//  Copyright © 2020 Oliver Michalak. All rights reserved.
//

import UIKit
import MultipeerKit


class ViewController: UIViewController {
  
  @IBOutlet weak var imageView: UIImageView!
  
  private lazy var transceiver: MultipeerTransceiver = {
    var config = MultipeerConfiguration.default
    config.serviceType = "RemoteCamera"
    let t = MultipeerTransceiver(configuration: config)
    
    t.receive(PhotoPayload.self) { [weak self] payload in
      self?.imageView.image = payload.image
    }
    return t
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    
    transceiver.resume()
  }

  @IBAction func recordImage() {
    guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }

    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = self
    present(picker, animated: true, completion: nil)
  }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
      let payload = PhotoPayload(image: image)
      imageView.image = image
      transceiver.broadcast(payload)
    }
    picker.dismiss(animated: true, completion: nil)
  }
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }
}
