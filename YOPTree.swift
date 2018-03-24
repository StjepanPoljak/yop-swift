//
//  YOPTree.swift
//  SwiftGPParser
//
//  Created by Stjepan Poljak on 06/02/2018.
//  Copyright © 2018 Stjepan Poljak. All rights reserved.
//

import Foundation

class YOPTree<Value,Tag:Equatable>: Tree<ValueWithTag<Value,Tag>>
{
    private let yopKernel: YOPKernel<Tag>
    
    init(withDirectives directives: [ParsingObject<Tag>],
         andEncoding encoding: String.Encoding)
    {
        yopKernel = YOPKernel<Tag>(withDirectives: directives, andEncoding: encoding)
        
        super.init()
        
        self.createRoot(with: nil)
    }

    func getValue(from node: Node<ValueWithTag<Value,Tag>>) -> Value?
    {
        return node.value?.getValue()
    }
    
    func generateTree(from string: String,
                      
                      usingEncoding encoding: String.Encoding,
                      
                      equatableCharFunction equatable:
                        ((_ char: CChar) -> CChar )?,
                      
                      onCompleteBlock combine:
        @escaping (_ node: Node<ValueWithTag<Value,Tag>>?) -> (value: Value?, loopControl: Bool),
                      
                      andConversion convert:
        @escaping ( (_ from: TextLine, _ and: YOPResult<Tag>) -> (value: Value?, tag: Tag?) ))
        
        -> (KernelErrorType?, Value?)
    {
        guard let chars = string.convertToCharArray(withEncoding: encoding) else
        {
            return (KernelErrorType.encodingError,nil)
        }
        
        var currentNode = self.root
        
        let loopControl: Bool = true
        
        var final:Value?
        
        let textSlice = chars.charArray[0...(chars.length - 1)]
        
        yopKernel.process(text: textSlice,
                          usingEquatableCharFunction: equatable,
                          andRecursiveSearch: false,
                          onObject:

        { (line, result) -> Bool in
            
            if currentNode == nil
            {
                self.failure(with: -1)
                return false
            }
            
            if result.isEndOfLine()
            {
                let _ = currentNode!.addChild(with: ValueWithTag(with: convert(line, result)))
                
                (final, _) = combine(currentNode)
                
                return false
            }
            
            guard let object = result.getObject() else
            {
                self.failure(with: -1)
                return false
            }
            
            let addedNode = currentNode!.addChild(with: ValueWithTag(with: convert(line, result)))
            
            switch object
            {
            case .object(_, _):
                
                break

            case .blockBrackets(_, _, _):
                
                guard let bracketState = result.getBracketState() else
                {
                    self.failure(with: -1)
                    return false
                }

                switch bracketState
                {
                case .open:
                    
                    if currentNode == nil
                    {
                        self.failure(with: -1)
                        return false
                    }
                    
                    currentNode = addedNode
                    
                case .closed:

                    let (combineValue, loopControl) = combine(currentNode)
                    
                    if !loopControl
                    {
                        return false
                    }

                    currentNode!.value?.setValue(new: combineValue)
                    
                    guard let parentNode = currentNode!.getParent() else
                    {
                        return false
                    }
                    
                    currentNode = parentNode

                }
            default:
                break
            }
            
            return loopControl
        })
        
        return (nil, final)
    }
    
    func failure(with code: Int32)
    {
        switch code
        {
        case -1:
            print("Internal bug or external meddling.")
        case 0:
            print("Conversion function produces non-unique keys for YOPTree.")
        case 1:
            print("Could not initialize YOPTree with current key-value connections.")
        default:
            print("Unknown error.")
        }
        
        exit(code)
    }
}

struct ValueWithTag<Value, Tag: Equatable>:Equatable
{
    static func ==(lhs: ValueWithTag<Value, Tag>,
                   rhs: ValueWithTag<Value, Tag>)
        -> Bool
    {
        return lhs.getTag() == rhs.getTag()
    }
    
    var value: Value?
    let tag: Tag?
    
    init(with tuple: (value: Value?, tag: Tag?))
    {
        self.value = tuple.value
        self.tag = tuple.tag
    }
    
    init(with value: Value?, and tag: Tag?)
    {
        self.value = value
        self.tag = tag
    }
    
    public func isEmpty () -> Bool
    {
        return (value == nil)
    }
    
    public func getValue () -> Value?
    {
        return value
    }
    
    public func getTag () -> Tag?
    {
        return tag
    }
    
    mutating public func setValue (new value: Value?)
    {
        self.value = value
    }
}

public class Stack<T>
{
    var stack:[T] = []
    
    public func push(_ newElement: T)
    {
        stack.append(newElement)
    }
    
    public func pop() -> T?
    {
        let last = stack.last
        
        if stack.count >= 1
        {
            stack.removeLast()
        }
        
        return last
    }
    
    public func isEmpty() -> Bool
    {
        return stack.isEmpty
    }
}

struct YOPStackItem<Value, Tag: Equatable>
{
    let node: Node<ValueWithTag<Value,Tag>>
    let tag: Int
    
    init (node: Node<ValueWithTag<Value,Tag>>, tag: Int)
    {
        self.node = node
        self.tag = tag
    }
}

extension YOPTree
{
    subscript (tags: [Tag]) -> [Node<ValueWithTag<Value,Tag>>]
    {
        var currentTag: Int = 0
        
        let yopStack = Stack<YOPStackItem<Value,Tag>>()

        if self.root == nil || tags.isEmpty { return [] }
        
        yopStack.push (YOPStackItem (node: self.root!, tag: currentTag))
        
        repeat
        {
            guard let currentItem = yopStack.pop() else { return [] }
            
            currentTag = currentItem.tag
            
            let results = (currentItem.node.children.filter { child in (child.value?.getTag() == tags[currentTag]) })
            
            if !results.isEmpty && (currentTag < tags.count)
            {
                currentTag += 1
                
                results.filter{ result in (!result.children.isEmpty) }
                       .reduce(into: (), { _ , each in yopStack.push(YOPStackItem(node: each, tag: currentTag)); return () })
            }
            
            if currentTag == tags.count { return results }
            
        } while(true)
    }

}
