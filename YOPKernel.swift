//
//  SwiftGPParser.swift
//  SwiftGPParser
//
//  Created by Stjepan Poljak on 30/01/2018.
//  Copyright © 2018 Stjepan Poljak. All rights reserved.
//

import Foundation

class YOPKernel<Tag>
{
    internal let kernel: AhoCorasickDictionary = AhoCorasickDictionary()
    private var kernelDictionary: [Int:ParsingObject<Tag>] = [:]
    
    internal var blockBracketDictionary: [Int:(state: Bracket, matching: Int)] = [:]
    internal var replaceableDictionary: [Int:[CChar]] = [:]
    
    init (withDirectives directives: [ParsingObject<Tag>], andEncoding encoding: String.Encoding)
    {
        kernel.setMaxWordLength(to: self.prepare(withDirectives: directives, andEncoding: encoding))
    }
    
    public func getObject (of index: Int) -> ParsingObject<Tag>?
    {
        return kernelDictionary[index]
    }
    
    private func prepareDictionary (withDirectives directives: [ParsingObject<Tag>], andEncoding encoding: String.Encoding) -> [String]
    {
        var kernelStringDictionary: [String] = []
        var kernelStringDictionaryCount: Int = 0
        
        for each in directives
        {
            var string: String = ""
            
            switch(each)
            {
            case .object(let keyword, _):
                string = keyword
                
            case .collapsiblePattern(let pattern):
                string = pattern
                
            case .removablePattern(let pattern):
                string = pattern
                
            case .replaceablePattern(let replace, let pattern):
                string = replace
                
                guard let conversion = pattern.convertToCharArray(withEncoding: encoding) else
                {
                    failure(with: 1, and: pattern)
                    
                    // will never be executed, but needed for syntax
                    return []
                }
                
                replaceableDictionary[kernelStringDictionaryCount] = conversion.charArray
                
            case .blockBrackets(let open, let closed, _):
                let openPlace: Int = kernelStringDictionaryCount
                let closedPlace: Int = kernelStringDictionaryCount + 1
                
                kernelStringDictionaryCount += 2
                
                kernelStringDictionary.append(open)
                blockBracketDictionary[openPlace] = (state: .open, matching: closedPlace)
                kernelDictionary[openPlace] = each
                
                kernelStringDictionary.append(closed)
                blockBracketDictionary[closedPlace] = (state: .closed, matching: openPlace)
                kernelDictionary[closedPlace] = each
            }
            
            switch (each)
            {
            case .blockBrackets(_, _, _):
                break
                
            default:
                kernelStringDictionary.append(string)
                kernelDictionary[kernelStringDictionaryCount] = each
                kernelStringDictionaryCount += 1
            }
        }
        
        return kernelStringDictionary
    }
    
    func prepare (withDirectives directives: [ParsingObject<Tag>], andEncoding encoding: String.Encoding) -> Int
    {
        let prepDict = prepareDictionary (withDirectives: directives, andEncoding: encoding)
        
        var maxLength = 0
        
        if !prepDict.isEmpty
        {
            maxLength = kernel.createDictionary(from: prepDict,
                                                withEncoding: encoding,
                                                andFailureFunction:
            { word in
                self.failure(with: 1, and: word)
            })
            
            kernel.prepareFailure()
        }
        
        return maxLength
    }
    
    func process (text: ArraySlice<CChar>,
                  usingEquatableCharFunction equatable:
        ((_ equate: CChar) -> CChar)?,
                  andRecursiveSearch recursive: Bool,
                  onObject processLine:
        ((_ lineOfText: TextLine, _ matchResult: YOPResult<Tag>) -> Bool)?)
    {
        var currentLine: TextLine = TextLine()
        
        var loopControl: Bool = true
        
        // for collapsible patterns
        var previous: YOPResult<Tag>?

        if !kernelDictionary.isEmpty
        {
            let residue = kernel.search(in: text, usingEquatableCharFunction: equatable,
                                        andRecursiveSearch: recursive, getPartialResult: true,
                                        andOnMatchExecute:
                { results, partial in

                    // we got a match
                    
                    guard let lastResult = results.last else
                    {
                        failure(with: -1)
                        return false
                    }
                    
                    let result = YOPResult<Tag>(from: lastResult, with: self)
                    
                    guard let resultPositionInDict = result.positionInDict else
                    {
                        failure(with: 4)
                        return false
                    }
                    
                    guard let prePDirective = kernelDictionary[resultPositionInDict] else
                    {
                        failure(with: 2)
                        return false
                    }
                    
                    if !partial.isEmpty
                    {
                        currentLine.append(contentsOf: partial)
                    }
                    
                    switch prePDirective
                    {
                    case .object(_), .blockBrackets(_, _, _):
                        
                        loopControl = processLine?(currentLine, result) ?? true
                        
                        currentLine.emptyContents()
                        
                    case .removablePattern(pattern: _):
                        
                        return true
                        
                    case .replaceablePattern(_, _):
                        
                        guard let replaceable = result.getMatchingReplacePattern() else
                        {
                            failure(with: 2)
                            return false
                        }
                        currentLine.append(contentsOf: replaceable)
                        
                        return true
                        
                    case .collapsiblePattern(pattern: _):
                        
                        if previous == nil
                        {
                            guard let pattern: [CChar] = kernel.getWord(at: result.positionInDict) else
                            {
                                failure(with: -1)
                                return false
                            }
                            currentLine.append(contentsOf: pattern)
                            
                            previous = result
                        }
                        else
                        {
                            guard let previousPositionInDict = previous!.positionInDict else
                            {
                                failure(with: 4)
                                return false
                            }
                            
                            guard let previousPattern = kernelDictionary[previousPositionInDict] else
                            {
                                failure(with: 2)
                                return false
                            }
                            
                            switch previousPattern
                            {
                            case .collapsiblePattern (_):
                                if previous! != result
                                {
                                    previous = nil
                                }
                                else
                                {
                                    if (previous!.endPositionInText + 1) == (result.startPositionInText)
                                    {
                                        previous = result
                                    }
                                    else
                                    {
                                        previous = nil
                                        
                                        guard let pattern: [CChar] = kernel.getWord(at: result.positionInDict) else
                                        {
                                            failure(with: -1)
                                            return false
                                        }
                                        currentLine.append(contentsOf: pattern)
                                    }
                                }
                                
                            default:
                                previous = nil
                            }
                        }
                        break
                    }
                    
                    return loopControl
            })
            
            // search completed
            
            if let residue = residue
            {
                if let partialResult = residue.partialResult
                {
                    currentLine.append(contentsOf: partialResult)
                }
                
                loopControl = processLine?(currentLine, { () -> YOPResult<Tag> in
                    let newResult = YOPResult<Tag>(positionInDict: nil,
                                                   startPositionInText: text.count,
                                                   endPositionInText: text.count,
                                                   wordLength: 0,
                                                   parentKernel: self)
                    return newResult
                }()) ?? true
            }
        }
        else
        {
            // empty kernel dictionary
            
            self.failure(with: 2)
            
            return
        }
        
        return
        
    }
    
    private func failure (with code: Int32)
    {
        failure(with: code, and: "")
    }
    
    private func failure (with code: Int32, and message: String)
    {
        switch (code)
        {
        case -1:
            print("Internal bug or external meddling.")
        case 0:
            print("Directives could not be loaded.")
        case 1:
            print("Error encoding word: \(message) to dictionary.")
        case 2:
            print("Parser not prepared. Use prepare method to prepare parser.")
        case 3:
            print("Text could not be encoded.")
        case 4:
            print("Unexpected EOL object.")
        default:
            print("Unknown error code.")
        }
        
        exit(code)
    }
}

enum KernelErrorType
{
    case unclosedBlock
    case extraBlockBracketsClose(on: Int)
    case encodingError
    case unknown
}

enum Bracket
{
    case open
    case closed
}

struct TextLine
{
    private var line:ArraySlice<CChar> = []
    
    func isEmpty () -> Bool
    {
        return (line.count <= 0)
    }
    
    func getCString () -> [CChar]
    {
        return Array(line)
    }
    
    func getString () -> String?
    {
        return Array(line).getString()
    }
    
    func getLineLength () -> Int
    {
        return line.count
    }
    
    mutating func append (char: CChar)
    {
        line.append(char)
    }
    
    mutating func append (contentsOf contents: ArraySlice<CChar>)
    {
        line.append(contentsOf: contents)
    }
    
    mutating func append (contentsOf contents: [CChar])
    {
        line.append(contentsOf: contents)
    }
    
    mutating func emptyContents ()
    {
        line = []
    }
}

enum ParsingObject<Tag>
{
    case blockBrackets (open: String, closed: String, tag: Tag)
    case object (keyword: String, tag: Tag)
    case removablePattern (pattern: String)
    case collapsiblePattern (pattern: String)
    case replaceablePattern (replace: String, with: String)
}

extension YOPKernel
{
    func process (text: String, usingEquatableCharFunction equatable:
        ((_ equate: CChar) -> CChar)?,
                  withEncoding encoding: String.Encoding,
                  andRecursiveSearch recursive: Bool,
                  onObject processLine:
        ((_ lineOfText: TextLine, _ matchResult: YOPResult<Tag>) -> Bool)?,
                  onBlockClose processBlockClose:
        @escaping ((_ unparsedText: TextLine, _ matchResult: YOPResult<Tag>, _ startedFrom: Int, _ andEndedOn: Int) -> Bool))
        -> KernelErrorType?
    {
        guard let text = text.convertToCharArray(withEncoding: encoding) else
        {
            return KernelErrorType.encodingError
        }
        
        return self.process(text: text.charArray[0...text.length],
                            usingEquatableCharFunction: equatable,
                            andRecursiveSearch: recursive,
                            onObject: processLine,
                            onBlockClose: processBlockClose)
    }
    
    func process (text: ArraySlice<CChar>,
                  usingEquatableCharFunction equatable:
        ((_ equate: CChar) -> CChar)?,
                  andRecursiveSearch recursive: Bool,
                  onObject processLine:
        ((_ lineOfText: TextLine, _ matchResult: YOPResult<Tag>) -> Bool)?,
                  onBlockClose processBlockClose:
        @escaping ((_ unparsedText: TextLine, _ matchResult: YOPResult<Tag>,
        _ startedFrom: Int, _ andEndedOn: Int) -> Bool))
        -> KernelErrorType?
    {
        
        var openBrackets: YOPResult<Tag>? = nil
        var loopControl: Bool = true
        var lastError: KernelErrorType?
        
        var unParsedLine: TextLine = TextLine()
        
        self.process(text: text,
                     usingEquatableCharFunction: equatable,
                     andRecursiveSearch: recursive,
                     onObject:
            { (line, result) -> Bool in
                
                if result.isEndOfLine()
                {
                    return processLine?(line, result) == true
                }
                
                guard let object = result.getObject() else
                {
                    self.failure(with: -1)
                    return processLine?(line, result) ?? true
                }
                
                if openBrackets != nil
                {
                    unParsedLine.append(contentsOf: line.getCString())
                }
                
                switch object
                {
                case .blockBrackets(_, _, _):
                    
                    guard let bracketState = result.getBracketState() else
                    {
                        self.failure(with: -1)
                        return false
                    }
                    
                    switch bracketState
                    {
                    case .open:
                        
                        if openBrackets == nil
                        {
                            openBrackets = result
                            
                            return processLine?(line, result) ?? true
                        }
                        
                    case .closed:
                        
                        if openBrackets == nil
                        {
                            lastError = KernelErrorType.extraBlockBracketsClose(on: result.startPositionInText)
                            return false
                        }
                        
                        guard let bracketClosed = self.isBracketsAndSameType(lhs: openBrackets!, rhs: result) else
                        {
                            self.failure(with: -1)
                            return false
                        }
                        
                        if bracketClosed
                        {
                            loopControl = processBlockClose(unParsedLine, result,
                                                            openBrackets!.endPositionInText + 1,
                                                            result.startPositionInText - 1)
                            openBrackets = nil
                            
                            unParsedLine.emptyContents()
                            
                            return loopControl
                        }
                    }
                default:
                    if openBrackets == nil
                    {
                        return processLine?(line,result) ?? true
                    }
                }
                
                if openBrackets != nil
                {
                    unParsedLine.append(contentsOf: result.parentKernel?.getWord(fromResult: result) ?? [])
                }

                return loopControl
        })
        
        return lastError
    }
    
    func process(text: String,
                 usingEquatableCharFunction equatable:
        ((_ equate: CChar) -> CChar)?,
                 withEncoding encoding: String.Encoding,
                 andRecursiveSearch recursive: Bool,
                 onObject processLine:
        ((_ lineOfText: TextLine, _ matchResult: YOPResult<Tag>) -> Bool)?)
    {
        guard let text = text.convertToCharArray(withEncoding: encoding) else
        {
            failure(with: 3)
            return
        }
        
        self.process(text: text.charArray[0...(text.length - 1)],
                     usingEquatableCharFunction: equatable,
                     andRecursiveSearch: recursive,
                     onObject: processLine)
    }

}
