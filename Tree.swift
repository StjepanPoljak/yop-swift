//
//  Tree.swift
//  SwiftGPParser
//
//  Created by Stjepan Poljak on 31/01/2018.
//  Copyright © 2018 Stjepan Poljak. All rights reserved.
//

import Foundation

class Node<V>
{
    private var parent: Node<V>?
    internal var children: [Node<V>] = []
    
    var value:V?
    
    init(with value: V?)
    {
        self.value = value
    }
    
    func addChild (node: Node<V>)
    {
        node.parent = self
        self.children.append(node)
    }
    
    func addChild (with value: V?) -> Node<V>?
    {
        let newNode = Node(with: value)
        addChild(node: newNode)
        
        return newNode
    }
    
    func getParent () -> Node<V>?
    {
        return self.parent
    }
    
    func isRoot () -> Bool
    {
        if self.parent == nil
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    public func hasValue() -> Bool
    {
        return !(self.value == nil)
    }
    
    func isLeaf () -> Bool
    {
        return children.isEmpty
    }
    
    func traverseBF (andOnEachNode execute: ((_ node: Node<V>) -> Void ))
    {
        for child in self.children
        {
            execute(child)
        }
        
        for child in self.children
        {
            child.traverseBF(andOnEachNode: execute)
        }
    }

    func traverseDF (andOnEachNode execute: ((_ node: Node<V>) -> Void ))
    {
        for child in self.children
        {
            execute(child)
            
            child.traverseDF(andOnEachNode: execute)
        }
    }
    
}

class Tree<V>
{
    var root:Node<V>?

    func createRoot(with value: V?)
    {
        root = Node<V>(with: value)
    }
    
    func getRoot() -> Node<V>?
    {
        return self.root
    }
    
    func traverseBF (andOnEachNode execute: ((_ node: Node<V>) -> Void ))
    {
        if self.root != nil { execute(self.root!) }
        
        self.root?.traverseBF(andOnEachNode: execute)
    }
    
    func traverseDF (andOnEachNode execute: ((_ node: Node<V>) -> Void ))
    {
        if self.root != nil { execute(self.root!) }
        
        self.root?.traverseDF(andOnEachNode: execute)
    }
}
