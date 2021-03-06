//
//  StoredPropertyIterable.swift
//  Echo
//
//  Created by Alejandro Alonso
//  Copyright © 2020 Alejandro Alonso. All rights reserved.
//

import Swift
import Echo

public enum Reflection {}

extension Reflection {
  public static func allKeyPaths<T>(for type: T.Type) -> [PartialKeyPath<T>] {
    guard let metadata = reflect(type) as? TypeMetadata,
          metadata.kind == .struct || metadata.kind == .class else {
      return []
    }
    
    var result = [PartialKeyPath<T>]()
    
    for i in 0 ..< metadata.contextDescriptor.fields.records.count {
      let kp = createKeyPath(root: metadata, leaf: i) as! PartialKeyPath<T>
      result.append(kp)
    }
    
    return result
  }
  
  public static func allKeyPaths<T>(for instance: T) -> [PartialKeyPath<T>] {
    allKeyPaths(for: T.self)
  }
  
  public static func allNamedKeyPaths<T>(
    for type: T.Type
  ) -> [String: PartialKeyPath<T>] {
    guard let metadata = reflect(type) as? TypeMetadata,
          metadata.kind == .struct || metadata.kind == .class else {
      return [:]
    }
    
    var result = [String: PartialKeyPath<T>]()
    
    for i in 0 ..< metadata.contextDescriptor.fields.records.count {
      let kp = createKeyPath(root: metadata, leaf: i) as! PartialKeyPath<T>
      result[metadata.contextDescriptor.fields.records[i].name] = kp
    }
    
    return result
  }
  
  public static func allNamedKeyPaths<T>(
    for instance: T
  ) -> [String: PartialKeyPath<T>] {
    allNamedKeyPaths(for: T.self)
  }
}
