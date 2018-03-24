//
//  ViewController.swift
//  SwiftGPParser
//
//  Created by Stjepan Poljak on 29/01/2018.
//  Copyright © 2018 Stjepan Poljak. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let testParserKernel: AhoCorasickDictionary = AhoCorasickDictionary()
        
        testParserKernel.createDictionary(from: ["hers","he","his","she"],
                                          withEncoding: .utf8,
                                          andFailureFunction:
            {
                word in print("Could not add word: \(word)")
                exit(-1)
            })
        
        testParserKernel.prepareFailure()
        
        let testString: String = "i am hers and She is his, if he allows she to be hers"
        
        print(
            """
            and residue: |\(
            String(cString: { ()->[CChar] in
            
            guard var result = testParserKernel.search(in: testString,
                                startingOn: 0,
                                andEndingOn: testString.count - 1,
                                usingEquatableCharFunction:
            { char in
                return testParserKernel.anyCase(of: char, with: .utf8)!
                return char
            },
                                andRecursiveSearch: false,
                                withEncoding: .utf8,
                                getPartialResult: true,
                                andOnMatchExecute:
            { results, partial in
                for each in results
                {
                    let word: String = testParserKernel.getWord(at: each.positionInDict)!
                    
                    print("found '\(word)' at: \(each.startPositionInText) ending on \(each.endPositionInText).")
                    
                    print("partial result: '\(Array(partial).getString())'")
                }
                return true
            }) else
            {
                return "EMPTY".convertToCharArray(withEncoding: .utf8)?.charArray ?? [0]
            }
            
            guard var resultPartial = result.partialResult else
            {
                return "ERROR".convertToCharArray(withEncoding: .utf8)?.charArray ?? [0]
            }
            
            resultPartial.append(0)
            
            return Array(resultPartial)
            
            }()))|\n
            """)

        if let res = testParserKernel.findInDictionary(word: "she", usingEquatableCharFunction: nil, withEncoding: .utf8)
        {
            print("found word on \(res)\n")
        }
        else
        {
            print("not found\n")
        }

        var currentKey:String?
        
        let treeTest2:YOPTree<String, Int> = YOPTree<String, Int>(withDirectives: [.blockBrackets(open: "(", closed: ")", tag: 0),
                                                                                   .object(keyword: "+", tag: 1)],
                                                                  andEncoding: .utf8)

        treeTest2.generateTree(from: { ()->String in
            
            var resultString:String = ""
            let preProcess:YOPKernel<Int> = YOPKernel<Int>(withDirectives: [.removablePattern(pattern: " "),.removablePattern(pattern: "\n")], andEncoding: .utf8)
            preProcess.process(text:"1 + 2 + (3 + 4 + (5 + 6) + 7 + (8 + 9 + 0))",
                               usingEquatableCharFunction: nil,
                               withEncoding: .utf8,
                               andRecursiveSearch: false,
                               onObject:
                { line, result in
                    
                    resultString.append(line.getString() ?? "")
                    return true
                    
            })
            return resultString
        }(), usingEncoding: .utf8,
             equatableCharFunction: nil,
             onCompleteBlock:
        { node in
            
            if node == nil
            {
                print("no node?")
                return (nil, false)
            }
            
            for each in node!.children
            {
                print("'\(each.value?.getValue() ?? "NIL")'")
            }
            
            let combineResult = node?.children.mergeIntoString(withStart: "[",
                                                               separator: "-",
                                                               andEnding: "]",
                                                               usingConversion: { node in return node.value?.getValue() })
            
            print("processed: \(combineResult ?? "NIL")\n")
            
            return (combineResult, true)
        }, andConversion: { line, result in (value: (line.isEmpty() ? nil : line.getString()), tag: (result.getTag()))})
        
        print("Found: \(parserTest[["dict","key"]].mergeIntoString(withStart: "\n-------\n",separator: "\n", andEnding: "\n-------\n", usingConversion: { node in return node.value?.getValue() }, andCustomPreFilter: { node in !(node.value?.getValue()?.isEmpty ?? true) }))")
        
        let (dataDict, hash) = testParserKernel.saveToData(with: 1)!
        
        var resultArray:[Int] = []
        
        testParserKernel.compile(find: dataDict, in: "i am hers and she is his, if he allows she to be hers".data(using: .utf8)!, using: hash, writeResultTo: &resultArray)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension Array
{
    func mergeIntoString (withStart start: String,
                          separator join: String,
                          andEnding end: String,
                          usingConversion conversion:
                    ( (Array.Element)->String? ) ) -> String
    {
        let result = self.map{ each in conversion(each) }
                         .filter{ each in (each != nil) }
        
            
        return result.enumerated()
                     .reduce(start,
            {(string, element) -> String in
                
                var reduceResult:String = string

                reduceResult.append(element.element ?? "")
                
                (element.offset < result.count - 1) ? reduceResult.append(join) : reduceResult.append(end)
                
                return reduceResult
            })
    }
    
    func mergeIntoString (withStart start: String,
                          separator join: String,
                          andEnding end: String,
                          usingConversion conversion:
                        ( (Array.Element)->String? ),
                          andCustomPreFilter filter:
                        ( (Array.Element)->Bool) )
        -> String
    {
        let result = self.filter { each in filter(each) }
                         .map { each in conversion(each) }
                         .filter { each in (each != nil) }
        
        return result.enumerated ()
                     .reduce (start,
            {(string, element) -> String in
                
                var reduceResult:String = string
                
                reduceResult.append(element.element ?? "")
                
                (element.offset < result.count - 1) ? reduceResult.append(join) : reduceResult.append(end)
                
                return reduceResult
            })
    }
}
