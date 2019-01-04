import UIKit

struct Animal: Codable {
    let name: String
    let age: Int
}

let animal = Animal(name: "旺财", age: 1)
let jsonEncoder = JSONEncoder()
let jsonData = try jsonEncoder.encode(animal)
if let str = String(data: jsonData, encoding: .utf8) {
    print(str)
    // 输出{"name":"旺财","age":1}
}

// 用JSONDecoder把JSON Data转回instance
let jsonDecoder = JSONDecoder()
let decodedAnimal = try jsonDecoder.decode(Animal.self, from: jsonData)


struct Person: Codable {
    enum Gender: Int, Codable {
        case male = 0, female
    }
    
    let name: String
    let gender: Gender?
    let birthday: String // Format of yyyy-MM-dd
    
    enum CodingKeys: String, CodingKey {
        case name
        case gender
        case birthday = "timestamp_birthday"
    }
    
    init(name: String, gender: Gender?, birthday: String) {
        self.name = name
        self.gender = gender
        self.birthday = birthday
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
        let timestamp: TimeInterval = try container.decode(TimeInterval.self, forKey: .birthday)
        birthday = Person.birthdayFormatter().string(from: Date(timeIntervalSince1970: timestamp))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(gender, forKey: .gender)
        guard let timestamp: TimeInterval = Person.birthdayFormatter().date(from: birthday)?.timeIntervalSince1970 else {
            fatalError("invalid birthday")
        }
        try container.encode(timestamp, forKey: .birthday)
        
    }
    
    static func birthdayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

let ming = Person(name: "小明", gender: .male, birthday: "1999-02-11")
let jsonData2 = try JSONEncoder().encode(ming)
if let str = String(data: jsonData2, encoding: .utf8) {
    print(str)
    // {"name":"小明","timestamp_birthday":918662400,"gender":0}
}

// 用JSONDecoder把JSON Data转回instance
let decodedMing = try JSONDecoder().decode(Person.self, from: jsonData2)



import Foundation


// https://stackoverflow.com/a/52966359/3651727
protocol Meta: Codable {
    associatedtype Element
    
    static func metatype(for element: Element) -> Self
    var type: Decodable.Type { get }
}

struct MetaArray<M: Meta>: Codable, ExpressibleByArrayLiteral {
    
    let array: [M.Element]
    
    init(_ array: [M.Element]) {
        self.array = array
    }
    
    init(arrayLiteral elements: M.Element...) {
        self.array = elements
    }
    
    enum CodingKeys: String, CodingKey {
        case metatype
        case object
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        var elements: [M.Element] = []
        while !container.isAtEnd {
            let nested = try container.nestedContainer(keyedBy: CodingKeys.self)
            let metatype = try nested.decode(M.self, forKey: .metatype)
            
            let superDecoder = try nested.superDecoder(forKey: .object)
            let object = try metatype.type.init(from: superDecoder)
            if let element = object as? M.Element {
                elements.append(element)
            }
        }
        array = elements
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try array.forEach { object in
            let metatype = M.metatype(for: object)
            var nested = container.nestedContainer(keyedBy: CodingKeys.self)
            try nested.encode(metatype, forKey: .metatype)
            let superEncoder = nested.superEncoder(forKey: .object)
            
            let encodable = object as? Encodable
            try encodable?.encode(to: superEncoder)
        }
    }
}

struct MetaObject<M: Meta>: Codable {
    let object: M.Element
    
    init(_ object: M.Element) {
        self.object = object
    }
    
    enum CodingKeys: String, CodingKey {
        case metatype
        case object
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let metatype = try container.decode(M.self, forKey: .metatype)
        
        let superDecoder = try container.superDecoder(forKey: .object)
        let obj = try metatype.type.init(from: superDecoder)
        guard let element = obj as? M.Element else {
            fatalError()
        }
        self.object = element
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let metatype = M.metatype(for: object)
        try container.encode(metatype, forKey: .metatype)
        
        let superEncoder = container.superEncoder(forKey: .object)
        let encodable = object as? Encodable
        try encodable?.encode(to: superEncoder)
    }
}



enum FlexModelMetatype: String, Meta {
    typealias Element = BaseFlexModel
    
    case base = "base"
    case button = "button"
    case imageView = "imageView"
    case textField = "textField"
    case view = "view"
    case label = "label"
    case video = "video"
    case radio = "radio"
    case swiper = "swiper"
    case map = "map"
    case `switch` = "switch"
    
    static func metatype(for element: BaseFlexModel) -> FlexModelMetatype {
        return element.metatype
    }
    
    var type: Decodable.Type {
        switch self {
        case .base:
            return BaseFlexModel.self
        case .view:
            return ViewFlexModel.self
        case .button:
            return ButtonFlexModel.self
        case .textField:
            return TextFieldFlexModel.self
        case .imageView:
            return ImageViewFlexModel.self
        case .label:
            return LabelFlexModel.self
        case .video:
            return VideoFlexModel.self
        case .radio:
            return RadioFlexModel.self
        case .swiper:
            return SwiperFlexModel.self
        case .map:
            return MapFlexModel.self
        case .`switch`:
            return SwitchFlexModel.self
        }
    }
}

class BaseFlexModel: NSObject, Codable, NSCopying, BaseModel {
    
    var metatype: FlexModelMetatype { return .base }

    struct PersistenceModel: Codable {
        let nodes: MetaArray<NodeMetatype>
    //    let metaFlexModel: MetaObject<FlexModelMetatype>
