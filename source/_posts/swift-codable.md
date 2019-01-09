---
title: Swift Codable深度实践
date: 2019-01-09 20:25:16
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

####0x01 基本用法

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

####0x02  手动实现Codable协议  

这一节介绍如何手动实现`Codable`协议。先上一个稍微复杂的Demo。  

首先，定义Person类型如下，其中的gender字段是Optional<Gender>类型，birthday字段是`yyyy-MM-dd`格式的字符串。

```swift
struct Person {
    enum Gender: Int, Codable {
        case male = 0, female
    }
    
    let name: String
    let gender: Gender?
    let birthday: String // Format of yyyy-MM-dd
    
    init(name: String, gender: Gender?, birthday: String) {
        self.name = name
        self.gender = gender
        self.birthday = birthday
    }
    
    static func birthdayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
```  

然后，给Person类型实现自定义的`Codable`协议：

```swift
extension Person: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case gender
        case birthday = "timestamp_birthday"
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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
        let timestamp: TimeInterval = try container.decode(TimeInterval.self, forKey: .birthday)
        birthday = Person.birthdayFormatter().string(from: Date(timeIntervalSince1970: timestamp))
    }
}
```

为了实现`Codable`协议，编写了三部分代码：  

1. `enum CodingKeys: String, CodingKey`，定义了一个enum并遵循`CodingKey`。只有遵循`CodingKey`协议的类型才可被用做编解码时的Key。   
2. `Decodable`协议中的`init(from:)`，初始化方法，把二进制数据解码成内存Instance。
3. `Encodable`中的`encode(to:)`，编码方法，把Instance编码城二进制数据。  

首先看`init(from:)`方法。一进来通过调用`decoder.container(keyedBy: CodingKeys.self)`拿到一个container，有了这个container，我们就可以根据每个key依次取value出来。取value使用`decode(_:forKey:)`或者`decodeIfPresent(_:forKey:)`，后者用于optional类型的成员变量。  

再看`encode(to:)`。同样的，先用`encoder.container(keyedBy: CodingKeys.self)`拿到一个container，然后调用container的`encode(_:forKey:)`或`encodeIfPresent(_:forKey:)`将各个成员变量依次编码。  

以上Demo里，我们使用Key-Value的方式对成员变量进行编解码，用到Keyed Container。Swift也提供了其他的编码方式，相应的有其他Container，例如`unkeyedContainer`、`singleValueContainer`等。  

Demo中，成员变量birthday的类型是String，用`yyyy-MM-dd`的格式表示日期。在编码前，我们手动把birthday转换成了时间戳，实际编码进二进制的也是时间戳。这里想表达的是，很多情况下编码前后的值不是相同的类型/格式，可以通过手动实现编解码方法来做转换。常见的应用场景是服务端返回的json数据以时间戳的形式表示时间，客户端拿到时间戳之后根据时区等信息把时间戳转换成用户可以理解的字符串格式。  

最后是测试代码，与上一个例子类似：

```swift
let ming = Person(name: "小明", gender: .male, birthday: "1999-02-11")
let jsonData = try JSONEncoder().encode(ming)
if let str = String(data: jsonData, encoding: .utf8) {
    print(str)
    // {"name":"小明","timestamp_birthday":918662400,"gender":0}
}

// 用JSONDecoder把JSON Data转回instance
let decodedMing = try JSONDecoder().decode(Person.self, from: jsonData)
```

总结一下可能需要手动实现`Codable`协议的场景：  

1. `Codable`默认把每个成员变量都进行编码。有时候我们可以只编解码部分字段，或者想编解码额外的字段。  
2. 对于同一个字段，编码前后需要用到不同的字段名称，如服务端API返回字段`unit_price`，客户端对应的是`unitPrice`。  
3. 对于同一个字段，编码前后需要使用不同的格式/类型，如时间戳和格式化的时间字符串。  

####0x03  继承

以上的例子都是定义了struct类型，swift的struct和class之间有许多区别，一个非常大的区别是只有class才支持继承！对于有继承的情况，应该如何使用`Codable`呢？  

首先定义一个父类Creature，来表示生物。这个父类使用了默认的`Codable`实现。  

```swift
class Creature: Codable {
    var name: String
    var age: Int
    
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}
```

然后定义两个子类Animal和Plant，继承自Creature。因为子类里增加了成员变量，所以实现了自定义的`Codable`协议。自定义的encode和decode方法需要调用父类的实现。如下所示：  

```swift
class Animal: Creature {
    var hasLeg: Bool
    
    init(name: String, age: Int, hasLeg: Bool) {
        self.hasLeg = hasLeg
        super.init(name: name, age: age)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasLeg = try container.decode(Bool.self, forKey: .hasLeg)
        // 注意：调用父类的init(from:)方法
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasLeg, forKey: .hasLeg)
        // 注意：调用父类的encode(to:)方法
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    enum CodingKeys: String, CodingKey {
        case hasLeg
    }
}

class Plant: Creature {
    var height: Double
    
    init(name: String, age: Int, height: Double) {
        self.height = height
        super.init(name: name, age: age)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        height = try container.decode(Double.self, forKey: .height)
    
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(height, forKey: .height)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    enum CodingKeys: String, CodingKey {
        case height
    }
}
```

验证一下，首先编解码父类Creature:  

```swift
let creature = Creature(name: "some_name", age: 12)
let creatureJsonData = try JSONEncoder().encode(creature)
if let str = String(data: creatureJsonData, encoding: .utf8) {
    print(str)
    // {"name":"some_name","age":12}
}
let decodedCreature: Creature = try JSONDecoder().decode(Creature.self, from: creatureJsonData)
```

然后再验证编解码子类Animal:  

```swift
let animal = Animal(name: "miaomiao", age: 2, hasLeg: true)
let animalJsonData = try JSONEncoder().encode(animal)
if let str = String(data: animalJsonData, encoding: .utf8) {
    print(str)
    // {"super":{"name":"miaomiao","age":2},"hasLeg":true}
}
let decodedAnimal: Animal = try JSONDecoder().decode(Animal.self, from: animalJsonData)
```

注意子类Animal编码后的json格式，属于父类的成员变量单独编码成了`"super":{"name":"miaomiao","age":2}`。  

到这里一切都还很美好。

#### 0x04   多态  

面向对象编程，很重要的一个思想是“多态”。我们来试试多态场景下`Codable`表现的怎么样。

先来把上一节验证编解码子类`Animal`的代码改成下面这样：  

```swift
// 首先定义一个Creature类型的对象，并且用子类Animal初始化
let creature: Creature = Animal(name: "miaomiao", age: 2, hasLeg: true)
let creatureJsonData = try JSONEncoder().encode(creature)
if let str = String(data: creatureJsonData, encoding: .utf8) {
    print(str)
    // 这里打印出了以下信息，符合预期 
    //{"super":{"name":"miaomiao","age":2},"hasLeg":true}
}
// 用JSONDecoder把JSON Data转回instance
// 以下这句代码报错了！
let decodedAnimal: Creature = try JSONDecoder().decode(Creature.self, from: creatureJsonData)
```

执行一下，最后这句报错了：  

```
▿ DecodingError
  ▿ keyNotFound : 2 elements
    - .0 : CodingKeys(stringValue: "name", intValue: nil)
    ▿ .1 : Context
      - codingPath : 0 elements
      - debugDescription : "No value associated with key CodingKeys(stringValue: \"name\", intValue: nil) (\"name\")."
      - underlyingError : nil
```

为什么报错了呢？
因为`try JSONDecoder().decode(Creature.self, from: creatureJsonData)`这个decode方法的第一个参数是`Creature.self`，因此期望第二个参数的内容的形式是`{"name":"miaomiao","age":2}`，而不是我们提供的`{"super":{"name":"miaomiao","age":2},"hasLeg":true}`！  

显然，多态的思想在这里不Work了。怎么办呢？  

面向对象编程时，对象的类型信息在编译或运行时会记录在内存里。举例来说，`Objective-C`是一门动态语言，运行时每个对象有`isa`指针，通过这个指针就可以读取到类型信息。再举个例子，C语言里定义一个指向int的指针`int *`，这个指针本质其实是一个数据结构，这个数据结构里不但存储了指向的地址，同时也要说明指向的地址里存储的是一个int类型的数据。  

说到这里我们应该可以想到解决方法了：**encode时，把对象的类型信息一并编码进去；decode时，先把类型信息拿出来，然后再解码成对应类型的对象**。  

照着这个思路做，就可以解决多态的问题。只不过，写起来很麻烦。后来我从[StackOverflow](https://stackoverflow.com/questions/44441223/encode-decode-array-of-types-conforming-to-protocol-with-jsonencoder)发现了一个优雅的解决方案：  

首先定义一个Protocol：  

```swift
// Swift无法使用type string来构造Type，因此对每个使用了多态的类簇，实现一个遵守此协议的enum，间接获取Type。
protocol Meta: Codable {
    associatedtype Element
    
    static func metatype(for typeString: String) -> Self
    var type: Decodable.Type { get }
}
```

然后定义一个wrapper，这个Wrapper是一个泛型，它实现了Codable:  

```swift
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
        // 首先取出类型信息
        let typeStr = try container.decode(String.self, forKey: .metatype)
        // 然后通过类型信息获得Type
        let metatype = M.metatype(for: typeStr)
        
        let superDecoder = try container.superDecoder(forKey: .object)
        // 根据Type调用相对应的类型的init(from:)方法
        let obj = try metatype.type.init(from: superDecoder)
        guard let element = obj as? M.Element else {
            fatalError()
        }
        self.object = element
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // 这里编码了type信息
        let typeStr = String(describing: type(of: object))
        try container.encode(typeStr, forKey: .metatype)
        
        let superEncoder = container.superEncoder(forKey: .object)
        let encodable = object as? Encodable
        try encodable?.encode(to: superEncoder)
    }
}
```

接下来，定义一个枚举，这个枚举需要遵守`Meta`协议，其中的case是Creature这个类簇的各个具体的类型：  

```swift
enum CreatureMetaType: String, Meta {
    typealias Element = Creature
    
    // Raw Value需要与类名Type严格一致；case需要覆盖到类簇里的每一类型！
    case creature = "Creature"
    case animal = "Animal"
    case plant = "Plant"
    
    static func metatype(for element: Creature) -> CreatureMetaType {
        return element.metatype
    }
    
    var type: Decodable.Type {
        switch self {
        case .creature:
            return Creature.self
        case .animal:
            return Animal.self
        case .plant:
            return Plant.self
        }
    }
}
```

最后，对一个动态类型编解码时，需要这样写：  

```swift
let creature: Creature = Animal(name: "miaomiao", age: 2, hasLeg: true)
// Encode时，Encode的不是creature对象本身，而是装着creature对象的Wrapper: MetaObject<CreatureMetaType>
let creatureJsonData = try JSONEncoder().encode(MetaObject<CreatureMetaType>(creature))
if let str = String(data: creatureJsonData, encoding: .utf8) {
    print(str)
    // 可以看到，creature对象实际的类型"Animal"被编码进json了
    // {"metatype":"Animal","object":{"super":{"name":"miaomiao","age":2},"hasLeg":true}}
}
// 解码时，也是先解码出Wrapper
let decodedMetaObject: MetaObject<CreatureMetaType> = try JSONDecoder().decode(MetaObject<CreatureMetaType>.self, from: creatureJsonData)
// 然后再取出其中Object，这个Object的类型是"Animal"
let decodedCreature = decodedMetaObject.object
```  

以上就是通过借助Wrapper对象MetaObject来编解码一个类簇的instance的方法（抱歉这句话好拗口）。  

接下来，我们要编码一个数组creatures，类型是[Creature]。其中实际装的是Animal、Plant或Creature本身。  
  
```swift
let creatures: [Creature] = [
    Animal(name: "miaomiao", age: 2, hasLeg: true),
    Plant(name: "tree", age: 463, height: 32.1),
    Creature(name: "WangWang", age: 2)
]
```

类似于编码单个对象，我们同样是定义一个Wrapper，这个Wrapper里面装的是array：

```swift
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
            let typeStr = try nested.decode(String.self, forKey: .metatype)
            let metatype = M.metatype(for: typeStr)
            
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
            let typeStr = String(describing: type(of: object))
            var nested = container.nestedContainer(keyedBy: CodingKeys.self)
            try nested.encode(typeStr, forKey: .metatype)
            let superEncoder = nested.superEncoder(forKey: .object)
            
            let encodable = object as? Encodable
            try encodable?.encode(to: superEncoder)
        }
    }
}
```  

然后借助这个Wrapper来对多态特性的Array进行编解码：  

```swift
let creaturesJsonData = try JSONEncoder().encode(MetaArray<CreatureMetaType>(creatures))
if let str = String(data: creaturesJsonData, encoding: .utf8) {
    print(str)
    // [{"metatype":"Animal","object":{"super":{"name":"miaomiao","age":2},"hasLeg":true}},{"metatype":"Plant","object":{"super":{"name":"tree","age":463},"height":32.100000000000001}},{"metatype":"Creature","object":{"name":"WangWang","age":2}}]
}


let decodedMetaArray: MetaArray<CreatureMetaType> = try JSONDecoder().decode(MetaArray<CreatureMetaType>.self, from: creaturesJsonData)
let decodedCreatures = decodedMetaArray.array
```  

全部代码请[点击这里](https://gist.github.com/anthann/a638ca1cd7f82f5bdfa48a6560cf7900)。代码使用Swift4.2编写，在XCode 10.1的Playground里测试有效。  

## 总结  

本文首先介绍了Swift 4里的`Codable`协议是什么，然后介绍了`Codable`的常规使用姿势，最后挖了一个“多态”的坑并且填了这个坑。  
`Codable`协议使得我们可以方便的把类型在二进制、Plist、JSON等格式之间编解码，而无需借助第三方库。开发朋友可以尝试学习并实践这个协议，相信可以一定程度上提高开发效率。

引用:  
[Encode/Decode Array of Types conforming to protocol with JSONEncoder](https://stackoverflow.com/questions/44441223/encode-decode-array-of-types-conforming-to-protocol-with-jsonencoder)
