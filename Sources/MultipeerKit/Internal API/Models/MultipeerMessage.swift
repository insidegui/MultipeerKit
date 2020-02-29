/**
 (c) 2020 Guilherme Rambo

 Based on code from https://github.com/gonzalezreal/IndeterminateTypesWithCodable
 Copyright (c) 2018 Guille Gonzalez

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

 */

import Foundation

struct MultipeerMessage: Codable {
    let type: String
    let payload: Any?

    init(type: String, payload: Any) {
        self.type = type
        self.payload = payload
    }

    enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private typealias MessageDecoder = (KeyedDecodingContainer<CodingKeys>) throws -> Any
    private typealias MessageEncoder = (Any, inout KeyedEncodingContainer<CodingKeys>) throws -> Void

    private static var decoders: [String: MessageDecoder] = [:]
    private static var encoders: [String: MessageEncoder] = [:]

    static func register<T: Codable>(_ type: T.Type, for typeName: String, closure: @escaping (T) -> Void) {
        decoders[typeName] = { container in
            let payload = try container.decode(T.self, forKey: .payload)

            DispatchQueue.main.async { closure(payload) }

            return payload
        }

        register(T.self, for: typeName)
    }

    static func register<T: Encodable>(_ type: T.Type, for typeName: String) {
        encoders[typeName] = { payload, container in
            try container.encode(payload as! T, forKey: .payload)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        if let decode = Self.decoders[type] {
            payload = try decode(container)
        } else {
            payload = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(type, forKey: .type)

        if let payload = self.payload {
            guard let encode = Self.encoders[type] else {
                let context = EncodingError.Context(codingPath: [], debugDescription: "Invalid payload type: \(type).")
                throw EncodingError.invalidValue(self, context)
            }

            try encode(payload, &container)
        } else {
            try container.encodeNil(forKey: .payload)
        }
    }

}
