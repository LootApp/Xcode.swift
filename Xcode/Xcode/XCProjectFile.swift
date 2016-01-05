//
//  XCProjectFile.swift
//  Xcode
//
//  Created by Tom Lokhorst on 2015-08-12.
//  Copyright (c) 2015 nonstrict. All rights reserved.
//

import Foundation

enum ProjectFileError : ErrorType, CustomStringConvertible {
  case InvalidData
  case NotXcodeproj
  case MissingPbxproj

  var description: String {
    switch self {
    case .InvalidData:
      return "Data in .pbxproj file not in expected format"
    case .NotXcodeproj:
      return "Path is not a .xcodeproj package"
    case .MissingPbxproj:
      return "project.pbxproj file missing"
    }
  }
}

public class AllObjects {
  var dict: [String: PBXObject] = [:]
  var fullFilePaths: [String: Path] = [:]
  func object<T : PBXObject>(key: String) -> T {
    let obj = dict[key]!
    if let t = obj as? T {
      return t
    }

    return T(id: key, dict: obj.dict, allObjects: self)
  }
}

public class XCProjectFile {
  public let projectURL: NSURL?
  public let project: PBXProject!

  public init(xcodeprojURL: NSURL) throws {
    
    self.projectURL = xcodeprojURL
    let pbxprojURL = xcodeprojURL.URLByAppendingPathComponent("project.pbxproj")
    guard let data = NSData(contentsOfURL: pbxprojURL) else {
      self.project = nil
      throw ProjectFileError.MissingPbxproj
    }
    
    do {
      self.project = try PBXProject(propertyListData: data)
    } catch let error {
      self.project = nil
      throw error
    }
  }

  static func projectName(url: NSURL) throws -> String {

    guard let subpaths = url.pathComponents,
          let last = subpaths.last,
          let range = last.rangeOfString(".xcodeproj")
    else {
      throw ProjectFileError.NotXcodeproj
    }

    return last.substringToIndex(range.startIndex)
  }
}

let types: [String: PBXObject.Type] = [
  "PBXProject": PBXProject.self,
  "PBXContainerItemProxy": PBXContainerItemProxy.self,
  "PBXBuildFile": PBXBuildFile.self,
  "PBXCopyFilesBuildPhase": PBXCopyFilesBuildPhase.self,
  "PBXFrameworksBuildPhase": PBXFrameworksBuildPhase.self,
  "PBXHeadersBuildPhase": PBXHeadersBuildPhase.self,
  "PBXResourcesBuildPhase": PBXResourcesBuildPhase.self,
  "PBXShellScriptBuildPhase": PBXShellScriptBuildPhase.self,
  "PBXSourcesBuildPhase": PBXSourcesBuildPhase.self,
  "PBXBuildStyle": PBXBuildStyle.self,
  "XCBuildConfiguration": XCBuildConfiguration.self,
  "PBXAggregateTarget": PBXAggregateTarget.self,
  "PBXNativeTarget": PBXNativeTarget.self,
  "PBXTargetDependency": PBXTargetDependency.self,
  "XCConfigurationList": XCConfigurationList.self,
  "PBXReference": PBXReference.self,
  "PBXReferenceProxy": PBXReferenceProxy.self,
  "PBXFileReference": PBXFileReference.self,
  "PBXGroup": PBXGroup.self,
  "PBXVariantGroup": PBXVariantGroup.self,
  "XCVersionGroup": XCVersionGroup.self
]
