---
title: swift_codable
tags:
---

## Codable前世

Swift 4为我们带来了新的协议--`Codable`，遵循此协议的实例可以在集中不同的类型之间转换（JSON、Proterty List、二进制等）。  

从Objective-C转过来的开发者一定很熟悉另一个协议--`NSCoding`，这个协议存在于`Foundation`框架内，作用是让遵循此协议的对象可以转换成二进制格式。既然已经有`NSCoding`，为何还要新出一个`Codable`呢？我自己的理解，大概是以下几个原因：  

1. `Codable`是Swift语言的一部分，不需要`Foundation`。
2. `NSCoding`只支持继承自NSObject的Class，而`Codable`可以支持原始类型、Struct、Enum、Class等多种类型。  
3. 相当多情况下，只需要在类型声明时加上`Codable`关键字，类型就直接具备了Codable能力，不需要多写一行代码！  
4. `NSCoding`只能让对象在内存实例和二进制格式之间互相转换，而`Codable`还支持了JSON、Proterty List等其他不同的格式。用了`Codable`之后甚至也可以不再用`ObjectMapper`等第三方库（这部分不展开讨论）。  

## Codable今生  

那么Codable这个协议到底是什么样子的？首先上定义：  

```swift
public typealias Codable = Decodable & Encodable  

public protocol Encodable {
    public func encode(to encoder: Encoder) throws
}  

public protocol Decodable {
    public init(from decoder: Decoder) throws
}
```  

可以看到，`Codable`本质是打包了`Decodable`和`Encodable`两个协议，这两个协议分别定义了一个方法。整体看上去非常简洁。  

很多时候，我们也许只需要用到Encode或Decode，那么只需要实现相应的协议即可。  

## 上手实践  

####0x01

从一个简单的例子来说明`Codable`到底怎么用。  

```swift
struct Animal: Codable {
    let name: String
    let age: Int
}

let animal = Animal(name: "旺财", age: 1)

// 用JSONEncoder把animal实例编码成JSON Data
let jsonEncoder = JSONEncoder()
let jsonData = try jsonEncoder.encode(animal)
if let str = String(data: jsonData, encoding: .utf8) {
    print(str)
    // {"name":"旺财","age":1}
}

// 用JSONDecoder把JSON Data解码回instance
let jsonDecoder = JSONDecoder()
let decodedAnimal = try jsonDecoder.decode(Animal.self, from: jsonData)
```

可以看到，我们定义了一个类型struct Animal，同时声明这个类型遵循`Codable`协议。然后创建了一个实例animal，用`JSONEncoder`直接将其编码成了JSON Data。

struct Animal的定义中没有一行多余的跟`Codable`相关的代码，为什么就获得了编解码能力呢？因为当定义一个新的类型，其中的所有成员变量的类型都支持`Codable`协议，那么只要这个新类型声明`Codable`就直接获得了`Codable`能力。Swift默认给Int、Double、Bool、Float、String等基本类型提供了`Codable`支持。  

####0x02  

这一节介绍如何手动实现`Codable`协议。先上一个稍微复杂的Demo。  

```swift
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
```  

为了实现`Codable`协议，需要至少三部分代码：  

1. `enum CodingKeys: String, CodingKey`，定义了一个enum并遵循`CodingKey`。只有遵循`CodingKey`协议的类型才可被用做编解码时的Key。   
2. `init(from decoder: Decoder) throws`，初始化方法，把二进制数据解码成内存Instance。
3. `func encode(to encoder: Encoder) throws`，编码方法，把Instance编码城二进制数据。  

首先看`init(from decoder: Decoder) throws`方法。一进来通过调用`decoder.container(keyedBy: CodingKeys.self)`拿到一个container，有了这个container，我们就可以根据每个key依次取value出来。取value使用`decode(_:forKey:)`或者`decodeIfPresent(_:forKey:)`，后者用于optional类型的成员变量。  

再看`func encode(to encoder: Encoder) throws`。同样的，先用`encoder.container(keyedBy: CodingKeys.self)`拿到一个container，然后调用container的`encode(_:forKey:)`或`encodeIfPresent(_:forKey:)`将各个成员变量依次编码。  

以上Demo里，我们使用Key-Value的方式对成员变量进行编解码，用到Keyed Container。Swift也提供了其他的编码方式，相应的有其他Container，例如`unkeyedContainer`、`singleValueContainer`等。  

Demo中，成员变量birthday的类型是String，用`yyyy-MM-dd`的格式表示日期。在编码前，我们手动把birthday转换成了时间戳，实际编码进二进制的也是时间戳。这里想表达的是，很多情况下编码前后的值不是相同的类型/格式，可以通过手动实现编解码方法来做转换。常见的应用场景是服务端返回的json数据以时间戳的形式表示时间，客户端拿到时间戳之后根据时区等信息把时间戳转换成用户可以理解的字符串格式。  

总结一下可能需要手动实现`Codable`协议的场景：  

1. `Codable`默认把每个成员变量都进行编码。有时候我们可以只编解码部分字段，或者想编解码额外的字段。  
2. 对于同一个字段，编码前后需要用到不同的字段名称，如服务端API返回字段`unit_price`，客户端对应的是`unitPrice`。  
3. 对于同一个字段，编码前后需要使用不同的格式/类型，如时间戳和格式化的时间字符串。  

####0x03  

以上的例子都是定义了struct类型，swift的struct和class之间有许多区别，一个非常大的区别是只有class才支持继承！对于有继承的情况，应该如何使用`Codable`呢？


#### 0x04