//
//  ACSerialization.swift
//  SwiftGPParser
//
//  Created by Stjepan Poljak on 12/02/2018.
//  Copyright © 2018 Stjepan Poljak. All rights reserved.
//

import Foundation

struct ACSerialObject
{
    fileprivate let length: UInt8
    let failurePointer: UInt8
    let numberOfChildren: UInt8
    let id: UInt8
    let charSize: UInt8
    
    let childList:[(Int,UInt8)]
}

struct ACSerialDataManager
{
    var rawData:[UInt8] = []
    
    subscript(index: Int) -> UInt8
    {
        return rawData[index]
    }
    
    mutating func serialize (_ acDict: AhoCorasickDictionary, withCharSize charLength: Int) -> [Int:Int]
    {
        var preSerialize:[ACSerialObject] = []
        
        if acDict.root == nil { return [:] }
        
        var pointerPosition:Int = 0
        var resultDict:[Int:Int] = [:]
        
        acDict.traverseBFS(andForEachNode:

            { node, parentChar in
                
                resultDict[node.idForDataSave!] = pointerPosition
                
                let length:Int = 5 + (node.edgeList.count * (charLength + 1))
                
                preSerialize.append(ACSerialObject(length: UInt8(length),
                                                   failurePointer: UInt8(node.getFailure()!.idForDataSave!),
                                                   numberOfChildren: UInt8(node.edgeList.count),
                                                   id: UInt8(node.getId() ?? 255), charSize: UInt8(charLength),
                                                   childList: node.edgeList.map
                                                    { pack -> (Int,UInt8) in
                                                        (Int(pack.key), UInt8(pack.value.idForDataSave!))
                                                    }))
                pointerPosition += length
                
            })
        
        self.rawData = preSerialize.reduce([]) { (acc, serial) -> [UInt8] in
            
            var rawStruct:[UInt8] = acc

            rawStruct.append(contentsOf: [serial.length, serial.failurePointer, serial.numberOfChildren, serial.charSize, serial.id])
            
            for child in serial.childList
            {
                rawStruct.append(contentsOf: child.0.putInside(with: charLength))
                rawStruct.append(child.1)
            }
            
            return rawStruct
        }
        
        return resultDict
    }
    
    func export () -> Data?
    {
        return nil
    }
    
    func getACSerialObject (from index: Int) -> ACSerialObject?
    {
        // [self] = length
        
        // [self + 1] = pointer to failure vertex
        // [self + 2] = number of children
        // [self + 3] = charLength in bytes (.utf8 == 1)
        // [self + 4] = id
        
        // [self + 5 + i*(charLength + 1)] = i-th child
        
        let length = self[index]
        let failure = self[index + 1]
        let childrenNum = self[index + 2]
        let charLength = self[index + 3]
        let id = self[index + 4]

        var children:[(Int,UInt8)] = []
        
        for i in 0..<childrenNum
        {
            let childSize = (charLength + 1)
            let childAddress = index + Int(5 + i * childSize)
            
            let childChar = self.pokeOut(elementOfSize: Int(charLength), at: childAddress)
            let childPos = self[index + Int(5 + i * childSize + charLength)]
            
            children.append((childChar,childPos))

        }
        
        return ACSerialObject(length: length,
                              failurePointer: failure,
                              numberOfChildren: childrenNum,
                              id: id, charSize: charLength,
                              childList: children)
    }
    
    mutating func shove (value: Int, withSize size: Int, to index: Int) -> Bool
    {
        var shoveThis = value.putInside(with: size)
        
        for each in index..<(index + size)
        {
            self.rawData[each] = shoveThis[each - index]
        }
        
        return true
    }
    
    func pokeOut (elementOfSize size: Int, at index: Int) -> Int
    {
        var result:Int = 0
        
        for each in index..<(index + size)
        {
            result = result + Int(self[each])
        }
        
        return result
    }
    
}



extension AhoCorasickDictionary
{

    public func compile (find dataDict: Data, in dataText: Data, using hash: [Int:Int], writeResultTo array: inout Array<Int>)
    {
        // [self] = length
        // [self + 1] = pointer to failure vertex
        // [self + 2] = number of children
        // [self + 3] = charLength in bytes (.utf8 == 1) -> remove and put in header in hash
        // [self + 4] = id
        
        // [self + 5 + i*(charLength + 1)] = i-th child
        
        //var results:[Int:Int] = [:]
        
        let textSize = dataText.count
        
        dataText.withUnsafeBytes(
            {
                (textByte: UnsafePointer<UInt8>) -> Void in
                
                dataDict.withUnsafeBytes(
                    {
                        (dictByte: UnsafePointer<UInt8>) -> Void in
                        
                        var currentInText:Int = 0
                        
                        var currentInDict:Int = 0
                        
                        var failureVertex:Int
                        var numOfChildren:Int
                        let charLength:Int = Int(dictByte.advanced(by: (currentInDict + 3) ).pointee)
                        
                        var gotoChild:Int = -1
                        var currentChild:Int
                        var match:Bool
                        
                        var matchNum:Int = 0
  
                        var checkCharPosInText:Int = 0
                        var checkCharPosInDict:Int = 0
                        
                        var currentChar:Int = 0

                        repeat
                        {
                            if currentInText*charLength >= textSize { break }
                            
                            repeat
                            {
                                numOfChildren = Int((dictByte + currentInDict + 2).pointee)
                                
                                // are there more children?
                                
                                if numOfChildren == 0
                                {
                                    if (dictByte + currentInDict + 4).pointee != 255 { array.append(currentInText) }
                                    
                                    currentInText += charLength * (matchNum - 1); currentInDict = 0; matchNum = 0;
                                    
                                    break
                                }
                                
                                match = true
                                
                                // we check each child of current node for a match
                                
                                currentChild = 0
                                
                                repeat
                                {
                                    match = true
                                    
                                    checkCharPosInText = currentInText + matchNum
                                    checkCharPosInDict = currentInDict + 5 + currentChild * (charLength + 1)
                                    
                                    // we check if characters match - loop is needed, as, for example, .utf16 stores chars in two bytes
                                    
                                    currentChar = 0
                                    
                                    repeat
                                    {
                                        if (textByte + checkCharPosInText + currentChar).pointee != (dictByte + checkCharPosInDict + currentChar).pointee
                                        { match = false; break }
                                        
                                        currentChar += 1
                                        
                                        if currentChar == charLength { break }
                                        
                                    } while(true)
                                    
                                    // if there is a match, we take note of pointer to the found child and break the loop
                                    if match
                                    { gotoChild = Int((dictByte + checkCharPosInDict + charLength).pointee) ; break }
                                    
                                    currentChild += 1
                                    
                                    if currentChild == numOfChildren { break }
                                    
                                } while(true)
                                
                                // if there is a match, take a goto function, else, take a failure function
                                if match
                                {
                                    currentInDict = hash[gotoChild]!
                                    
                                    matchNum += 1
                                }
                                else
                                {
                                    // find failure vertex...
                                    failureVertex = hash[Int((dictByte + currentInDict + 1 ).pointee)]!
                                    
                                    // is it root?
                                    if failureVertex == 0
                                    { currentInDict = 0; matchNum = 0; break }
                                }
                                
                            } while (true)
                            
                            currentInText += charLength
                            
                        } while (true)
                        
                })
        })
        
        //return results
    }
}
