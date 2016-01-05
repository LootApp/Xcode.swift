//
//  PBXObject.swift
//  Xcode
//
//  Created by Tom Lokhorst on 2015-08-29.
//  Copyright © 2015 nonstrict. All rights reserved.
//

import Foundation

typealias JsonObject = [String: AnyObject]

public /* abstract */ class PBXObject {
  let id: String
  let dict: JsonObject
  let allObjects: AllObjects

  public lazy var isa: String = self.string("isa")!

  public required init(id: String, dict: AnyObject, allObjects: AllObjects) {
    self.id = id
    self.dict = dict as! JsonObject
    self.allObjects = allObjects
  }

  func string(key: String) -> String? {
    return dict[key] as? String
  }

  func object<T : PBXObject>(key: String) -> T? {
    guard let objectKey = dict[key] as? String else {
      return nil
    }

    let obj: T = allObjects.object(objectKey)
    return obj
  }

  func object<T : PBXObject>(key: String) -> T {
    let objectKey = dict[key] as! String
    return allObjects.object(objectKey)
  }

  func objects<T : PBXObject>(key: String) -> [T] {
    let objectKeys = dict[key] as! [String]
    return objectKeys.map(allObjects.object)
  }
}

public /* abstract */ class PBXContainer : PBXObject {
}

public class PBXProject : PBXContainer {
  public lazy var targets: [PBXNativeTarget] = self.objects("targets")
  public lazy var mainGroup: PBXGroup = self.object("mainGroup")
  public lazy var buildConfigurationList: XCConfigurationList = self.object("buildConfigurationList")
  var format: NSPropertyListFormat
  
  public convenience init(propertyListData data: NSData) throws {
    
    let options = NSPropertyListReadOptions.Immutable
    var format: NSPropertyListFormat = NSPropertyListFormat.BinaryFormat_v1_0
    let obj = try NSPropertyListSerialization.propertyListWithData(data, options: options, format: &format)
    
    guard let dict = obj as? JsonObject else {
      throw ProjectFileError.InvalidData
    }
    
    self.init(dict: dict, format: format)
  }
  
  convenience init(dict: JsonObject, format: NSPropertyListFormat) {
    let allObjects = AllObjects()
    let objects = dict["objects"] as! [String: JsonObject]
    let rootObjectId = dict["rootObject"] as! String
    let projDict = objects[rootObjectId]!
    
    self.init(id: rootObjectId, dict: projDict, allObjects: allObjects)
    self.format = format
    
    for (key, obj) in objects {
      allObjects.dict[key] = PBXProject.createObject(key, dict: obj, allObjects: allObjects)
    }
    
    for (key, obj) in objects {
      allObjects.dict[key] = PBXProject.createObject(key, dict: obj, allObjects: allObjects)
    }
    self.allObjects.fullFilePaths = paths(self.mainGroup, prefix: "")
  }

  public required init(id: String, dict: AnyObject, allObjects: AllObjects) {
    self.format = .OpenStepFormat
    super.init(id: id, dict: dict, allObjects: allObjects)
  }
  
  static func createObject(id: String, dict: JsonObject, allObjects: AllObjects) -> PBXObject {
    let isa = dict["isa"] as? String
    
    if let isa = isa, let type = types[isa] {
        return type.init(id: id, dict: dict, allObjects: allObjects)
    }
    
    // Fallback
    assertionFailure("Unknown PBXObject subclass isa=\(isa)")
    return PBXObject(id: id, dict: dict, allObjects: allObjects)
  }
  
  func paths(current: PBXGroup, prefix: String) -> [String: Path] {
    
    var ps: [String: Path] = [:]
    
    for file in current.fileRefs {
      switch file.sourceTree {
      case .Group:
        ps[file.id] = .RelativeTo(.SourceRoot, prefix + "/" + file.path!)
      case .Absolute:
        ps[file.id] = .Absolute(file.path!)
      case let .RelativeTo(sourceTreeFolder):
        ps[file.id] = .RelativeTo(sourceTreeFolder, file.path!)
      }
    }
    
    for group in current.subGroups {
      if let path = group.path {
        ps += paths(group, prefix: prefix + "/" + path)
      }
      else {
        ps += paths(group, prefix: prefix)
      }
    }
    
    return ps
  }
}

public /* abstract */ class PBXContainerItem : PBXObject {
}

public class PBXContainerItemProxy : PBXContainerItem {
}

public /* abstract */ class PBXProjectItem : PBXContainerItem {
}

public class PBXBuildFile : PBXProjectItem {
  public lazy var fileRef: PBXReference? = self.object("fileRef")
}


public /* abstract */ class PBXBuildPhase : PBXProjectItem {
  public lazy var files: [PBXBuildFile] = self.objects("files")
}

public class PBXCopyFilesBuildPhase : PBXBuildPhase {
  public lazy var name: String? = self.string("name")
}

public class PBXFrameworksBuildPhase : PBXBuildPhase {
}

public class PBXHeadersBuildPhase : PBXBuildPhase {
}

public class PBXResourcesBuildPhase : PBXBuildPhase {
}

public class PBXShellScriptBuildPhase : PBXBuildPhase {
  public lazy var name: String? = self.string("name")
  public lazy var shellScript: String = self.string("shellScript")!
}

public class PBXSourcesBuildPhase : PBXBuildPhase {
}

public class PBXBuildStyle : PBXProjectItem {
}

public class XCBuildConfiguration : PBXBuildStyle {
  public lazy var name: String = self.string("name")!
}

public /* abstract */ class PBXTarget : PBXProjectItem {
  public lazy var buildConfigurationList: XCConfigurationList = self.object("buildConfigurationList")
  public lazy var name: String = self.string("name")!
  public lazy var productName: String = self.string("productName")!
  public lazy var productType: PBXProductType = PBXProductType(rawValue: self.string("productType")!)!
  public lazy var buildPhases: [PBXBuildPhase] = self.objects("buildPhases")
}

public class PBXAggregateTarget : PBXTarget {
}

public class PBXNativeTarget : PBXTarget {
}

public class PBXTargetDependency : PBXProjectItem {
}

public class XCConfigurationList : PBXProjectItem {
}

public class PBXReference : PBXContainerItem {
  public lazy var name: String? = self.string("name")
  public lazy var path: String? = self.string("path")
  public lazy var sourceTree: SourceTree = self.string("sourceTree").flatMap(SourceTree.init)!
}

public class PBXFileReference : PBXReference {

  // convenience accessor
  public lazy var fullPath: Path = self.allObjects.fullFilePaths[self.id]!
}

public class PBXReferenceProxy : PBXReference {

  // convenience accessor
  public lazy var remoteRef: PBXContainerItemProxy = self.object("remoteRef")
}

public class PBXGroup : PBXReference {
  public lazy var children: [PBXReference] = self.objects("children")

  // convenience accessors
  public lazy var subGroups: [PBXGroup] = self.children.ofType(PBXGroup.self)
  public lazy var fileRefs: [PBXFileReference] = self.children.ofType(PBXFileReference)
}

public class PBXVariantGroup : PBXGroup {
}

public class XCVersionGroup : PBXReference {
}


public enum SourceTree {
  case Absolute
  case Group
  case RelativeTo(SourceTreeFolder)

  init?(sourceTreeString: String) {
    switch sourceTreeString {
    case "<absolute>":
      self = .Absolute
    case "<group>":
      self = .Group
    default:
      guard let sourceTreeFolder = SourceTreeFolder(rawValue: sourceTreeString) else { return nil }
      self = .RelativeTo(sourceTreeFolder)
    }
  }
}

public enum SourceTreeFolder: String {
  case SourceRoot = "SOURCE_ROOT"
  case BuildProductsDir = "BUILT_PRODUCTS_DIR"
  case DeveloperDir = "DEVELOPER_DIR"
  case SDKRoot = "SDKROOT"
}

public enum Path {
  case Absolute(String)
  case RelativeTo(SourceTreeFolder, String)
}

public enum PBXProductType: String {
  case Application        = "com.apple.product-type.application"
  case CommandLineTool    = "com.apple.product-type.tool"
  case Framework          = "com.apple.product-type.framework"
  case UITests            = "com.apple.product-type.bundle.ui-testing"
  case UnitTest           = "com.apple.product-type.bundle.unit-test"
}

