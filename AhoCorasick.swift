//
//  AhoCorasick.swift
//  SwiftGPParser
//
//  Created by Stjepan Poljak on 29/01/2018.
//  Copyright © 2018 Stjepan Poljak. All rights reserved.
//

import Foundation

class ACVertex
{
    var edgeList:[CChar:ACVertex] = Dictionary()
    
    private var label:[CChar] = []
    private var id: Int?

    private var failure:ACVertex?
    private var parent:ACVertex?
    
    private var length:Int = 0
    
    var idForDataSave: Int? = nil
    
    init()
    {
        
    }
    
    init (withLength length: Int,
          parentVertex parent: ACVertex?,
          uniqueId id: Int?,
          andLabel label: [CChar])
    {
        self.label = label
        self.length = length
        self.id = id
        self.parent = parent
    }
    
    func getId () -> Int?
    {
        return self.id
    }
    
    func isRoot () -> Bool
    {
        if self.getParent() == nil
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    func getParent () -> ACVertex?
    {
        return self.parent
    }
    
    func getLength () -> Int
    {
        return self.length
    }
    
    func getFailure () -> ACVertex?
    {
        return self.failure
    }
    
    func setFailure (toVertex vertex: ACVertex)
    {
        self.failure = vertex
    }
    
    func append (with char: CChar,
                 label charThread: [CChar],
                 andId id: Int?, withLastDataID dataID: Int)
        -> (ACVertex,[CChar],Int)
    {
        var resultLabel = charThread
        resultLabel.append(char)
        
        let appendVertex = ACVertex(withLength: self.length + 1,
                                    parentVertex: self,
                                    uniqueId: id,
                                    andLabel:
            { ()->[CChar] in
                
                if id == nil
                {
                    return []
                }
                else
                {
                    return resultLabel
                }
        }())
        
        edgeList[char] = appendVertex
        appendVertex.idForDataSave = dataID + 1
        
        return (appendVertex,resultLabel,dataID + 1)
    }
    
    func setNext (with char: CChar,
                  label charThread: [CChar],
                  andId id: Int?, withLastDataID dataID: Int)
        -> (ACVertex, [CChar], Bool, Int)
    {
        let continueToNext:Bool =
        { ()-> Bool in
            if id != nil { return false }
            else { return true }
        }()
        
        guard let next = edgeList[char] else
        {
            let (newVertex,newLabel,newDataID) = self.append(with: char,
                                                   label: charThread,
                                                   andId: id,
                                                   withLastDataID: dataID)
            return (newVertex, newLabel, continueToNext, newDataID)
        }
        
        if (id != nil) { next.id = id }
        
        return (next,{ ()->[CChar] in
            var newLabel = next.label
            newLabel.append(char)
            return newLabel
        }(), continueToNext, dataID)
    }
}

class AhoCorasickDictionary
{
    private var dictionary:[[CChar]] = []
    internal var root:ACVertex?
    
    private var maxWordLength: Int = 0
    
    init()
    {
        
    }
    
    public func getWord (at index: Int?) -> [CChar]?
    {
        guard let index = index else
        {
            return nil
        }
        
        if (0 > index) || (index >= dictionary.count)
        {
            return nil
        }
        else
        {
            return dictionary[index]
        }
    }
    
    public func getWord (at index: Int?) -> String?
    {
        guard let index = index else
        {
            return nil
        }
        
        guard let word:[CChar] = getWord(at: index) else
        {
            return nil
        }
        
        return String(cString: word)
    }
    
    public func getWordCount () -> Int
    {
        return dictionary.count
    }
    
    fileprivate func findInDictionary (word: ArraySlice<CChar>,
                                       startingFrom start: Int,
                                       andNode startNode: ACVertex,
                                       usingEquatableCharFunction equatable:
                                    ((_ equate: CChar) -> CChar)?)
        -> (matches: [Int], lastNode: ACVertex, currentPosition: Int)
    {
        var currentNode:ACVertex = startNode
        var currentPosition:Int = start

        var results:[Int] = []
        
        let length = word.count + currentPosition
        
        repeat
        {
            if let nodeID = currentNode.getId()
            {
                results.append(nodeID)
            }

            if (currentPosition >= length)
            {
                return (results, currentNode, currentPosition - 1)
            }
            
            let currentChar = word[currentPosition]
            
            if let nextNode = currentNode.edgeList[equatable?(currentChar) ?? currentChar]
            {
                currentNode = nextNode
                currentPosition += 1
            }
            else
            {
                return (results, currentNode, currentPosition - 1)
            }
            
        } while (true)
    }
    
    public func findInDictionary (word: String,
                                  usingEquatableCharFunction equatable:
                                    ((_ equate: CChar) -> CChar)?,
                                  withEncoding encoding: String.Encoding)
                -> Int?
    {
        if self.root == nil
        {
            return nil
        }
        
        if let word = word.convertToCharArray(withEncoding: encoding)
        {
            if word.length == 0
            {
                return nil
            }
            else
            {
                return self.findInDictionary (word: word.charArray[0...(word.length-1)],
                                              startingFrom: 0,
                                              andNode: self.root!,
                                              usingEquatableCharFunction: equatable).matches.last ?? nil
            }
        }
        else
        {
            return nil
        }
    }
    
    public func createDictionary (from words: [String],
                                  withEncoding encoding: String.Encoding,
                                  andFailureFunction failure: ((_ word: String) -> Void)?) -> Int
    {
        var maxLength:Int = 0
        var lastID = 0
        var length:Int = 0
        
        for each in words
        {
            (length, lastID) = self.addWord(word: each,
                                            withEncoding: encoding, andFailureFunction: failure, with: lastID)
            
            maxLength = (length > maxLength) ? length : maxLength
        }
        
        return maxLength
    }
    
    private func addWord (word: String, withEncoding encoding: String.Encoding,
                          andFailureFunction failure: ((_ word: String) -> Void)?,
                          with lastDataID: Int) -> (Int,Int)
    {
        if word == ""
        {
            failure?(word)
            return (0,lastDataID)
        }
        
        if let word = word.convertToCharArray(withEncoding: encoding)
        {
            if self.root == nil
            {
                root = ACVertex(withLength: 0, parentVertex: nil,
                                uniqueId: nil, andLabel: [])
                self.root!.idForDataSave = lastDataID
            }
            
            var currentNode = self.root!
            var positionInWord = 0
            var currentChar:CChar = word.charArray[0]

            var currentLabel:[CChar] = []
            var continueLoop = true
            var newDataID: Int = lastDataID
            
            repeat
            {
                (currentNode,currentLabel,continueLoop,newDataID) =
                    currentNode.setNext (with: currentChar,
                                         label: currentLabel,
                                         andId:
                    { ()->Int? in
                        if positionInWord >= word.length - 1
                        {
                            self.dictionary.append(word.charArray)
                            return (dictionary.count - 1)
                        }
                        else
                        {
                            positionInWord += 1
                            currentChar = word.charArray[positionInWord]
                            return nil
                        }
                    }(), withLastDataID: newDataID)
            } while (continueLoop)
            
            return (word.length, newDataID)
        }
        else
        {
            failure?(word)
        }
        
        return (0,lastDataID)
    }
}

extension AhoCorasickDictionary
{
    internal func traverseBFS (andForEachNode executeNodeFunction:
            ((_ currentNode: ACVertex, _ parentChar: CChar?) -> Void))
    {
        if self.root == nil
        {
            return
        }
        
        executeNodeFunction (self.root!, nil)
        
        for each in self.root!.edgeList
        {
            continueFrom (currentVertex: each.value,
                          withParentChar: each.key,
                          andExecute: executeNodeFunction)
        }

    }
    
    private func continueFrom (currentVertex vertex: ACVertex,
                               withParentChar parentChar: CChar,
                               andExecute nodeFunction:
                    ((_ currentNode: ACVertex, _ parentChar: CChar?) -> Void))
    {
        nodeFunction(vertex, parentChar)
        
        for each in vertex.edgeList
        {

            continueFrom(currentVertex: each.value,
                         withParentChar: each.key,
                         andExecute: nodeFunction)
        }

    }
    
    private func prepareFailure (for vertex: ACVertex, with parentChar: CChar)
    {
        var possibleFailVertex = vertex.getParent()!.getFailure()
        
        repeat
        {
            if possibleFailVertex == nil
            {
                failure(with: 0)
                return
            }

            if (vertex.getParent()!.isRoot())
            {
                vertex.setFailure(toVertex: self.root!)
                break
            }
            
            if possibleFailVertex!.edgeList[parentChar] != nil
            {
                vertex.setFailure(toVertex: possibleFailVertex!.edgeList[parentChar]!)
                break
            }

            possibleFailVertex = possibleFailVertex?.getFailure()
            
            if possibleFailVertex!.isRoot() { vertex.setFailure(toVertex: self.root!); break }

        } while (true)
    }
    
    func prepareFailure ()
    {
        traverseBFS(andForEachNode:
            {
                currentNode, parentChar in

                if let parentChar = parentChar
                {
                    prepareFailure (for: currentNode, with: parentChar)
                }
                else
                {
                    self.root?.setFailure(toVertex: self.root!)
                }
            })
        

    }
    
    func search (in text: String,
                 startingOn startPosition: Int,
                 andEndingOn endPosition: Int,
                 usingEquatableCharFunction equatable:
                ((_ equate: CChar) -> CChar)?,
                 andRecursiveSearch recursion: Bool,
                 withEncoding encoding: String.Encoding,
                 getPartialResult partial: Bool,
                 andOnMatchExecute matchFunction:
        ((_ findResult: [ACResult], _ partialResult: ArraySlice<CChar>) -> Bool))
        -> ACResult?
    {
        guard let text = text.convertToCharArray(withEncoding: encoding) else
        {
            return nil
        }

        return search(in: text.charArray[startPosition...endPosition],
                      usingEquatableCharFunction: equatable,
                      andRecursiveSearch: recursion,
                      getPartialResult: partial,
                      andOnMatchExecute: matchFunction)
    }

    func setMaxWordLength (to length: Int)
    {
        self.maxWordLength = length
    }
    
    func search (in text: ArraySlice<CChar>,
                 usingEquatableCharFunction equatable:
                ((_ equate: CChar) -> CChar)?,
                 andRecursiveSearch recursive: Bool,
                 getPartialResult partial: Bool,
                 andOnMatchExecute matchFunction:
        ((_ findResult: [ACResult], _ partialResult: ArraySlice<CChar>) -> Bool))
        -> ACResult?
    {
        let startPosition = text.startIndex
        let endPosition = text.endIndex - 1
        
        if self.root == nil
        {
            return nil
        }
        
        var currentNode: ACVertex = self.root!
        
        var loopControl: Bool = true

        var lastPosition:Int = 0
        var position:Int = startPosition
        
        repeat
        {
            // speeds the algorithm almost double!
            if position < endPosition { if self.root!.edgeList[text[position]] == nil { position += 1; continue } }
            
            repeat
            {
                let arraySliceEnd = ((maxWordLength > 0) && (position + maxWordLength <= endPosition)
                                    ? (position + maxWordLength) : endPosition)
                
                let result = findInDictionary (word: text[position...arraySliceEnd],
                                               startingFrom: position,
                                               andNode: currentNode,
                                               usingEquatableCharFunction: equatable)
                if !result.matches.isEmpty
                {
                    let partialResult = (lastPosition <= (position - 1)) ? text[lastPosition...(position - 1)] : []
                    
                    loopControl = matchFunction([ACResult(positionInDict: result.matches.last,
                                                          startPositionInText: position,
                                                          endPositionInText: result.currentPosition)],
                                                partialResult)
                    
                    lastPosition = result.currentPosition + 1
                    
                    position = result.currentPosition
                    
                    break
                }

                if result.lastNode.getFailure()!.isRoot()
                {
                    break
                }
                else
                {
                    currentNode = result.lastNode.getFailure()!
                }
            }
            while (loopControl)
            
            position += 1
            
            if !loopControl || (position >= endPosition) { break }
            
        } while(true)
        
        return{
            ()->ACResult? in
            
            let returnResult = ACResult(positionInDict: nil,
                                        startPositionInText: endPosition,
                                        endPositionInText: endPosition)
            
            returnResult.partialResult = (lastPosition <= endPosition) ? text[lastPosition...endPosition] : []
            
            return returnResult
        }()
    }
}

extension AhoCorasickDictionary
{
    private func failure (with code: Int32)
    {
        switch (code)
        {
        case 0:
            print("Internal bug or external meddling.")
        case 1:
            print("Dictionary not prepared.")
        case 2:
            print("Found a loop - dictionary preparation bug.")
        default:
            print("Unknown error code.")
        }
        
        exit(code)
    }
}

extension AhoCorasickDictionary
{
    // maybe make a protocol in the future
    
    public func anyCase (of char: CChar, with encoding: String.Encoding) -> CChar?
    {
        let lowerCase = "abcdefghijklmnopqrstuvwxyz"
        let upperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        
        guard let lowerCaseEncoded = lowerCase.cString(using: encoding) else
        {
            return char
        }
        
        guard let upperCaseEncoded = upperCase.cString(using: encoding) else
        {
            return char
        }
        
        for each in 0..<lowerCaseEncoded.count
        {
            if upperCaseEncoded[each] == char
            {
                return lowerCaseEncoded[each]
            }
        }
        
        return char
    }
}

extension Array where Element == CChar
{
    public func getString () -> String
    {
        guard let lastChar = self.last else
        {
            return ""
        }
        
        var result = self
        
        if lastChar != 0
        {
            result.append(0)
        }
        
        return String(cString: result)
    }
}

extension String
{
    public func convertToCharArray (withEncoding encoding: String.Encoding)
        -> (charArray: [CChar], length: Int)?
    {
        if self == ""
        {
            return nil
        }
        
        guard var string = self.cString(using: encoding) else
        {
            return nil
        }
        
        return{
            ()->([CChar],Int) in
            
            var wordCount = string.count
            
            if (string[wordCount - 1] == 0)
            {
                wordCount -= 1
                
                string.remove(at: wordCount)
                
                return (string, wordCount)
            }
            
            return (string, wordCount)
            }()
    }
}

extension AhoCorasickDictionary
{
    func saveToData (with charSize: Int) -> (Data, [Int:Int])?
    {
        var serializationManager:ACSerialDataManager = ACSerialDataManager()
        let hash = serializationManager.serialize(self, withCharSize: charSize)
        
        if hash.isEmpty { return nil }
        
//        print(serializationManager.rawData)
//        print(hash)
        
        return (Data(bytes: serializationManager.rawData),hash)
    }
}

extension Int
{
    func putInside (with num: Int) -> [UInt8]
    {
        var residue = self
        var result:[UInt8] = []
        
        for each in 0..<num
        {
            if residue > 255
            {
                result.append(255)
                residue = residue - 255
            }
            else
            {
                if residue > 0
                {
                    result.append(UInt8(residue))
                    residue = residue - 255
                }
                else
                {
                    result.append(0)
                }
            }
        }
        
        return result
    }
}
