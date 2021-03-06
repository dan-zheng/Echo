//
//  ReflectionMirror.swift
//  Echo
//
//  Created by Alejandro Alonso
//  Copyright © 2019 - 2020 Alejandro Alonso. All rights reserved.
//

// TODO: Handle weak, unowned, and unmanaged properties.

import Echo

func reflectInstance(_ instance: Any) -> EchoMirror {
  let subjectType = type(of: instance)
  let metadata = reflect(subjectType)
  
  let children = getChildren(of: instance, with: metadata)
  let displayStyle = getDisplayStyle(of: metadata)
  
  return EchoMirror(
    subjectType: subjectType,
    children: Swift.Mirror.Children(children),
    displayStyle: displayStyle
  )
}

func getDisplayStyle(of metadata: Metadata) -> Swift.Mirror.DisplayStyle? {
  switch metadata.kind {
  case .class:
    return .class
  case .enum:
    return .enum
  case .struct:
    return .struct
  case .tuple:
    return .tuple
  default:
    return nil
  }
}

func getChildren(
  of instance: Any,
  with metadata: Metadata
) -> [Swift.Mirror.Child] {
  switch metadata {
  case let structMetadata as StructMetadata:
    return getStructFields(from: instance, with: structMetadata)
  case let tupleMetadata as TupleMetadata:
    return getTupleFields(from: instance, with: tupleMetadata)
  case let enumMetadata as EnumMetadata:
    return getEnumFields(from: instance, with: enumMetadata)
  case let classMetadata as ClassMetadata:
    return getClassFields(from: instance, with: classMetadata)
  default:
    return []
  }
}

func getStructFields(
  from instance: Any,
  with metadata: StructMetadata
) -> [Swift.Mirror.Child] {
  guard metadata.descriptor.isReflectable else {
    return []
  }
  
  var container = unsafeBitCast(instance, to: AnyExistentialContainer.self)
  let opaqueValue = container.projectValue()
  
  var result = [Swift.Mirror.Child]()
  
  for i in 0 ..< metadata.descriptor.numFields {
    let field = metadata.descriptor.fields.records[i]
    let label = field.name
    let type = metadata.type(of: field.mangledTypeName)!
    let fieldMetadata = reflect(type)
    let offset = metadata.fieldOffsets[i]
    var value = AnyExistentialContainer(type: type)
    let buffer = fieldMetadata.allocateBoxForExistential(in: &value)
    fieldMetadata.vwt.initializeWithCopy(buffer, opaqueValue + offset)
    
    result.append((label: label, value: unsafeBitCast(value, to: Any.self)))
  }
  
  return result
}

func getTupleFields(
  from instance: Any,
  with metadata: TupleMetadata
) -> [Swift.Mirror.Child] {
  var container = unsafeBitCast(instance, to: AnyExistentialContainer.self)
  let opaqueValue = container.projectValue()
  
  var result = [Swift.Mirror.Child]()
  
  for i in 0 ..< metadata.numElements {
    var label = String(metadata.labels[i])
    if label.isEmpty {
      label = ".\(i)"
    }
    
    let elt = metadata.elements[i]
    var value = AnyExistentialContainer(type: elt.type)
    let buffer = elt.metadata.allocateBoxForExistential(in: &value)
    elt.metadata.vwt.initializeWithCopy(buffer, opaqueValue + elt.offset)
    
    result.append((label: label, value: unsafeBitCast(value, to: Any.self)))
  }
  
  return result
}

func getEnumFields(
  from instance: Any,
  with metadata: EnumMetadata
) -> [Swift.Mirror.Child] {
  guard metadata.descriptor.isReflectable else {
    return []
  }
  
  var container = unsafeBitCast(instance, to: AnyExistentialContainer.self)
  var opaqueValue = container.projectValue()
  
  var result = [Swift.Mirror.Child]()
  
  let tag = metadata.enumVwt.getEnumTag(for: opaqueValue)
  let field = metadata.descriptor.fields.records[Int(tag)]
  let name = field.name
  let type = metadata.type(of: field.mangledTypeName)
  
  // If we have no payload case, or if the enum is not indirect, we're done.
  guard type != nil || field.flags.isIndirectCase else {
    return result
  }
  
  let nativeObject = KnownMetadata.Builtin.nativeObject
  let payloadMetadata = field.flags.isIndirectCase ?
                          nativeObject : reflect(type!)
  let pair = swift_allocBox(for: payloadMetadata)
  
  metadata.enumVwt.destructiveProjectEnumData(for: opaqueValue)
  payloadMetadata.vwt.initializeWithCopy(pair.buffer, opaqueValue)
  metadata.enumVwt.destructiveInjectEnumTag(for: opaqueValue, tag: tag)
  
  opaqueValue = pair.buffer
  
  if field.flags.isIndirectCase {
    let owner = UnsafePointer<UnsafePointer<HeapObject>>(
      opaqueValue._rawValue
    ).pointee
    opaqueValue = swift_projectBox(for: owner)
  }
  
  var value = AnyExistentialContainer(metadata: payloadMetadata)
  let buffer = payloadMetadata.allocateBoxForExistential(in: &value)
  payloadMetadata.vwt.initializeWithCopy(buffer, opaqueValue)
  
  swift_release(pair.heapObj)
  
  result.append((label: name, value: unsafeBitCast(value, to: Any.self)))
  
  return result
}

// FIXME: Handle ObjC stuff
func getClassFields(
  from instance: Any,
  with metadata: ClassMetadata
) -> [Swift.Mirror.Child] {
  guard metadata.descriptor.isReflectable else {
    return []
  }
  
  var result = [Swift.Mirror.Child]()
  
  for i in 0 ..< metadata.descriptor.numFields {
    let field = metadata.descriptor.fields.records[i]
    let label = field.name
    let type = metadata.type(of: field.mangledTypeName)!
    let fieldMetadata = reflect(type)
    let offset = metadata.fieldOffsets[i]
    var value = AnyExistentialContainer(type: type)
    let buffer = fieldMetadata.allocateBoxForExistential(in: &value)
    withUnsafePointer(to: instance) {
      fieldMetadata.vwt.initializeWithCopy(
        buffer,
        UnsafePointer<UnsafeRawPointer>($0._rawValue).pointee + offset
      )
    }
    
    result.append((label: label, value: unsafeBitCast(value, to: Any.self)))
  }
  
  return result
}
