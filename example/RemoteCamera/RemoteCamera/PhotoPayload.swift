//
//  PhotoPayload.swift
//  RemoteCamera
//
//  Created by Oliver Michalak on 01.03.20.
//  Copyright © 2020 Oliver Michalak. All rights reserved.
//

import UIKit


struct PhotoPayload: Codable {
  let image: UIImage
}


extension PhotoPayload {
  
  enum CodingKeys: String, CodingKey {
    case image
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let data = try? container.decode(Data.self, forKey: .image),
      let img = UIImage(data: data) {
      image = img
    }
    else {
      image = UIImage()
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let data = image.jpegData(compressionQuality: 0.8)
    try container.encode(data, forKey: .image)
  }
}
