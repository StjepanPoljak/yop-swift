//
//  ACResult.swift
//  SwiftGPParser
//
//  Created by Stjepan Poljak on 06/02/2018.
//  Copyright © 2018 Stjepan Poljak. All rights reserved.
//

import Foundation

class ACResult: Equatable
{
    static func ==(lhs: ACResult, rhs: ACResult) -> Bool
    {
        return (lhs.positionInDict == rhs.positionInDict)
    }
    
    public let positionInDict: Int?
    public let startPositionInText: Int
    public let endPositionInText: Int
    
    var partialResult: ArraySlice<CChar>?
    
    init (positionInDict dictLoc: Int?,
          startPositionInText startTextLoc: Int,
          endPositionInText endTextLoc: Int)
    {
        self.positionInDict = dictLoc
        self.startPositionInText = startTextLoc
        self.endPositionInText = endTextLoc
    }
    
    public func isEndOfLine () -> Bool
    {
        return (positionInDict == nil)
    }
    
    public func getPartial () -> ArraySlice<CChar>?
    {
        return partialResult
    }
    
    public func getPartial () -> String?
    {
        return Array(partialResult!).getString()
    }
}

class YOPResult<Tag>: ACResult
{
    var parentKernel: YOPKernel<Tag>?

    init (positionInDict dictLoc: Int?,
          startPositionInText startTextLoc: Int,
          endPositionInText endTextLoc: Int,
          wordLength length: Int,
          parentKernel yopKernel: YOPKernel<Tag>)
    {
        super.init(positionInDict: dictLoc,
                   startPositionInText: startTextLoc,
                   endPositionInText: endTextLoc)
        self.parentKernel = yopKernel
    }
    
    init (from acResult: ACResult, with yopKernel: YOPKernel<Tag>)
    {
        super.init(positionInDict: acResult.positionInDict,
                   startPositionInText: acResult.startPositionInText,
                   endPositionInText: acResult.endPositionInText)
        self.parentKernel = yopKernel
    }
    
    public func getObject () -> ParsingObject<Tag>?
    {
        guard let yopKernel = parentKernel else
        {
            return nil
        }
        
        guard let positionInDict = self.positionInDict else
        {
            return nil
        }
        
        return yopKernel.getObject(of: positionInDict)
    }
    
    public func getObjectKeywordAndTag () -> (keyword: String, tag: Tag)?
    {
        guard let object = self.getObject() else
        {
            return nil
        }
        
        switch object
        {
        case .object(let keyword, let tag):
            return (keyword: keyword, tag: tag)
            
        default:
            return nil
        }
    }
    
    public func getWord () -> [CChar]?
    {
        guard let yopKernel = parentKernel else
        {
            return nil
        }
        
        guard let positionInDict = self.positionInDict else
        {
            return nil
        }
        
        return yopKernel.getWord(at: positionInDict)
    }

    public func getWord () -> String?
    {
        return self.getWord()?.getString()
    }
    
    public func getTag () -> Tag?
    {
        guard let object = self.getObject() else
        {
            return nil
        }
        
        switch object
        {
        case .object(_, let tag):
            return tag
            
        case .blockBrackets(_, _, let tag):
            return tag
            
        default:
            return nil
        }
    }
    
    public func getBracketState () -> Bracket?
    {
        guard let yopKernel = parentKernel else
        {
            return nil
        }
        
        guard let positionInDict = self.positionInDict else
        {
            return nil
        }
        
        return yopKernel.getBracketType(from: positionInDict)
        
    }
    
    public func isOpenBrackets () -> Bool
    {
        return (getBracketState() == .open)
    }
    
    public func getMatchingReplacePattern () -> [CChar]?
    {
        guard let yopKernel = parentKernel else
        {
            return nil
        }
        
        guard let positionInDict = self.positionInDict else
        {
            return nil
        }
        
        return yopKernel.getReplacePattern(from: positionInDict)
    }    
}

extension YOPKernel
{
    public func getBracketType (from index: Int) -> Bracket?
    {
        return blockBracketDictionary[index]?.state
    }
    
    public func getReplacePattern (from positionInDict: Int) -> [CChar]?
    {
        return replaceableDictionary[positionInDict]
    }
    
    public func getWord (fromResult result: ACResult) -> [CChar]?
    {
        return kernel.getWord(at: result.positionInDict)
    }
    
    public func getWord (fromResult result: ACResult) -> String?
    {
        return kernel.getWord(at: result.positionInDict)
    }
    
    public func getWord (at index: Int) -> [CChar]?
    {
        return kernel.getWord(at: index)
    }
    
    public func getWord (at index: Int) -> String?
    {
        return kernel.getWord(at: index)
    }
    
    public func isBracketsAndSameType (lhs: ACResult, rhs: ACResult) -> Bool?
    {
        guard let lhsPositionInDict = lhs.positionInDict else
        {
            return nil
        }
        
        guard let rhsPositionInDict = rhs.positionInDict else
        {
            return nil
        }
        
        guard let lhsD = blockBracketDictionary[lhsPositionInDict] else
        {
            return nil
        }
        
        guard let rhsD = blockBracketDictionary[rhsPositionInDict] else
        {
            return nil
        }
        
        if (lhsD.matching == rhs.positionInDict)
            && (lhs.positionInDict == rhsD.matching)
        {
            return true
        }
        else
        {
            return false
        }
    }

}
