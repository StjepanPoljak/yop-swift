//
//  InfiniteOrderedQueue.swift
//  XMLRSSFeed
//
//  Created by Stjepan Poljak on 07/12/2017.
//  Copyright © 2017 Stjepan Poljak. All rights reserved.
//

import Foundation

struct InfiniteOrderedQueue
{
    private var intervalArray: [interval] = []
    
    init ()
    {
        intervalArray = [interval.range(from: .number(0), to: .positiveInfinity)]
    }
    
    init (universe range: interval)
    {
        intervalArray = [range]
    }
    
    mutating func dequeue () -> Int
    {
        if intervalArray.count == 0
        {
            return -1
        }
        else
        {
            switch(intervalArray[0])
            {
            case .single(at: let num):
                intervalArray.remove(at: 0)
                return num
                
            case .range(from: let start, to: let end):
                switch(start)
                {
                case .negativeInfinity:
                    
                    intervalArray[0] = interval.range(from: .number(1), to: end)
                    return 1
                    
                case .number(let min):
                    let (range1, range2) = dealWithRangeCase(min, in: intervalArray[0])
                    
                    if (range1 == nil) && (range2 == nil)
                    {
                        return -1
                    }
                    else if (range1 == nil)
                    {
                        intervalArray[0] = range2!
                        return min
                    }
                    else if (range2 == nil)
                    {
                        intervalArray[0] = range1!
                        return min
                    }
                    else
                    {
                        intervalArray[0] = range2!
                        intervalArray.insert(range1!, at: 0)
                    }
                default:
                    return -1
                }
            }
        }
        
        return -1
    }
    
    mutating func remove (_ index: Int)
    {
        if intervalArray.count == 0
        {
            return
        }
        else
        {
            let position = binaryFindPlace(for: index)
            
            if position == -1
            {
                return
            }
            
            switch (intervalArray[position])
            {
            case .single(at: _):
                intervalArray.remove(at: position)
            default:
                let (range1, range2) = dealWithRangeCase(index, in: intervalArray[position])
                if (range1 == nil) && (range2 == nil)
                {
                    return
                }
                else if (range1 == nil)
                {
                    intervalArray[position] = range2!
                }
                else if (range2 == nil)
                {
                    intervalArray[position] = range1!
                }
                else
                {
                    intervalArray[position] = range2!
                    intervalArray.insert(range1!, at: position)
                }
            }
        }
    }
    
    func dealWithRangeCase (_ index: Int, in range: interval) -> (interval?, interval?)
    {
        switch (range)
        {
        case .range(from: let start, to: let end):
            switch (start)
            {
            case .negativeInfinity:
                switch (end)
                {
                case .positiveInfinity:
                    // e.g. remove 3 in (-inf, +inf) results in (-inf, 2) U (4, +inf)
                    return (interval.range(from: .negativeInfinity, to: .number(index - 1)),
                            interval.range(from: .number(index + 1), to: .positiveInfinity))
                case .number(let upperBound):
                    if index == upperBound
                    {
                        // e.g. remove 3 in (-inf, 3) results in (-inf, 2)
                        return (interval.range(from: .negativeInfinity, to: .number(index - 1)), nil)
                    }
                    else if (index + 1) == upperBound
                    {
                        // e.g. remove 3 in (-inf, 4) results in (-inf, 2) U {4}
                        return (interval.range(from: .negativeInfinity, to: .number(index - 1)),
                                interval.single(at: upperBound))
                    }
                    else if index < upperBound
                    {
                        // e.g. remove 3 in (-inf, 7) results in (-inf, 2) U (4, 7)
                        return (interval.range(from: .negativeInfinity, to: .number(index - 1)),
                                interval.range(from: .number(index + 1), to: .number(upperBound)))
                    }
                    else
                    {
                        // removing index outside of range
                        return (range, nil)
                    }
                default:
                    //impossible case - double negative infinity
                    return (nil, nil)
                }
            case .number(let lowerBound):
                switch (end)
                {
                case .number(let upperBound):
                    if index == lowerBound
                    {
                        if (index + 1) == upperBound
                        {
                            // for example remove 3 in (3, 4) results in {4}
                            return (nil, interval.single(at: upperBound))
                        }
                        else if index < upperBound
                        {
                            // for example, remove 3 in (3,7) results in (4,7)
                            return (nil, interval.range(from: hyperInt.number(index + 1), to: .number(upperBound)))
                        }
                        else if index == upperBound
                        {
                            //should not happen, because range should not be a single number!
                            return (nil, nil)
                        }
                        else
                        {
                            // index is outside of range
                            return (nil, range)
                        }
                    }
                    else if index > lowerBound
                    {
                        if index + 1 == upperBound
                        {
                            if index - 1 == lowerBound
                            {
                                // for example, remove 3 in (2,4) results in {2} U {4}
                                return (interval.single(at: lowerBound),
                                        interval.single(at: upperBound))
                            }
                            else if (index - 1) > lowerBound
                            {
                                // e.g. remove 3 in (1,4) results in (1,2) U {4}
                                return (interval.range(from: .number(lowerBound), to: .number(index - 1)),
                                        interval.single(at: upperBound))
                            }
                            else
                            {
                                // impossible case
                                return (nil, nil)
                            }
                        }
                        else if index == upperBound
                        {
                            if index - 1 == lowerBound
                            {
                                // for example, remove 3 in (2, 3) results in {2}
                                return (interval.single(at: lowerBound), nil)
                            }
                            else if (index - 1) > lowerBound
                            {
                                // for example, remove 3 in (1, 3) results in (1,2)
                                return (interval.range(from: .number(lowerBound), to: .number(index - 1)), nil)
                            }
                            else if index == lowerBound
                            {
                                // handled in previous if - should never happen!
                                return (nil, nil)
                            }
                            else
                            {
                                // impossible case
                                return (nil, nil)
                            }
                        }
                        else if index < upperBound
                        {
                            if (index - 1) == lowerBound
                            {
                                // for example, remove 3 in (2, 7) results in {2} U (4, 7)
                                return (interval.single(at: lowerBound),
                                        interval.range(from: hyperInt.number(index + 1), to: hyperInt.number(upperBound)))
                            }
                            else
                            {
                                // for example, remove 3 in (0, 7) results in (0, 2) U (4, 7)
                                return (interval.range(from: hyperInt.number(lowerBound), to: hyperInt.number(index - 1)),
                                        interval.range(from: hyperInt.number(index + 1), to: hyperInt.number(upperBound)))
                            }
                        }
                        else if index > upperBound
                        {
                            // index higher than upper bound
                            return (range, nil)
                        }
                    }
                    else
                    {
                        // index is lower than lower bound
                        return (nil, range)
                    }
                case .positiveInfinity:
                    if index == lowerBound
                    {
                        // e.g. remove 3 in (3, +inf) results in (4, +inf)
                        return (nil, interval.range(from: .number(index + 1), to: .positiveInfinity))
                    }
                    else if (index - 1) == lowerBound
                    {
                        // e.g. remove 3 in (2, +inf) results in {2} U (4, +inf)
                        return (interval.single(at: index - 1),
                                interval.range(from: .number(index + 1), to: .positiveInfinity))
                    }
                    else if (index - 1) > lowerBound
                    {
                        // e.g. remove 3 in (1, +inf) results in (1, 2) U (4, +inf)
                        return (interval.range(from: .number(lowerBound), to: .number(index - 1)),
                                interval.range(from: .number(index + 1), to: .positiveInfinity))
                    }
                    else
                    {
                        // index outside of range
                        return (nil, range)
                    }
                default:
                    // impossible case - number to negative infinity cannot happen
                    return (nil, nil)
                }
            default:
                // impossible case - positive infinity to number or negative infinity cannot happen
                return (nil,nil)
            }
        default:
            // assumed range, not single
            return (nil,nil)
        }
        
        // should never be executed
        return (nil, nil)
    }
    
    func compareinterval (check index: Int, at position: Int) -> hyperCompare
    {
        switch(intervalArray[position])
        {
        case .range(from: let start, to: let end):
            switch(end)
            {
            case .positiveInfinity:
                switch(start)
                {
                case .negativeInfinity:
                    return hyperCompare.contained
                case .number(let lowerBound):
                    if index >= lowerBound
                    {
                        return hyperCompare.contained
                    }
                    else
                    {
                        return hyperCompare.smaller
                    }
                default:
                    return hyperCompare.impossible
                }
            case .number(let upperBound):
                switch(start)
                {
                case .negativeInfinity:
                    if (index <= upperBound)
                    {
                        return hyperCompare.contained
                    }
                    else
                    {
                        return hyperCompare.larger
                    }
                case .number(let lowerBound):
                    if (index >= lowerBound) && (index <= upperBound)
                    {
                        return hyperCompare.contained
                    }
                    else
                    {
                        if index < lowerBound
                        {
                            return hyperCompare.smaller
                        }
                        else
                        {
                            return hyperCompare.larger
                        }
                    }
                default:
                    // positive infinity at lower bound
                    return hyperCompare.impossible
                }
            default:
                //negative infinity at upper bound
                return hyperCompare.impossible
            }
        case .single(at: let singleInt):
            if index == singleInt
            {
                return hyperCompare.equal
            }
            else
            {
                if index > singleInt
                {
                    return hyperCompare.larger
                }
                else
                {
                    return hyperCompare.smaller
                }
            }
        }
    }
    
    func printRange (_ range: interval) -> String
    {
        var first = ""
        var second = ""
        
        switch (range)
        {
        case .range(from: let start, to: let end):
            switch (start)
            {
            case .negativeInfinity:
                first = "-inf"
            case .number(let num):
                first = String(num)
            default:
                return ""
            }
            switch (end)
            {
            case .positiveInfinity:
                second = "+inf"
            case .number(let num):
                second = String(num)
            default:
                return ""
            }
        case .single(at: let num):
            return "{" + String(num) + "}"
        }
        
        return "(" + first + ", " + second + ")"
    }
    
    func binaryFindPlace (for index: Int) -> Int
    {
        var first:Int = 0
        var last:Int = intervalArray.count - 1
        var current: Int = -1
        
        repeat
        {
            if (first == last)
            {
                switch (compareinterval(check: index, at: first))
                {
                case .contained:
                    return first
                case .equal:
                    return first
                default:
                    return -1
                }
            }
            
            if ((first + last) % 2) == 1
            {
                let comparison = compareinterval(check: index, at: last)
                
                if (comparison == hyperCompare.contained) ||
                    (comparison == hyperCompare.equal)
                {
                    return last
                }
                else if comparison == hyperCompare.smaller
                {
                    last = last - 1
                    continue
                }
                else
                {
                    //last should always be range to positive infinity,
                    //therefore always contained, equal or smaller
                    return -1
                }
            }
            
            current = (first + last) / 2
            
            let comparison = compareinterval(check: index, at: current)
            
            if (comparison == hyperCompare.contained) ||
                (comparison == hyperCompare.equal)
            {
                return current
            }
            else if comparison == hyperCompare.smaller
            {
                last = current
                continue
            }
            else if comparison == hyperCompare.larger
            {
                first = current
                continue
            }
            else
            {
                return -1
            }
            
        } while (true)
    }
    
    func printIntervalArray () -> String
    {
        var result = ""
        
        if intervalArray.count == 0
        {
            return "empty"
        }
        
        for each in intervalArray
        {
            result.append(printRange(each))
            result.append("\n")
        }
        
        return result
    }
    
    mutating func test ()
    {
        for _ in 0..<200
        {
            let a = 0
            let b = 500
            let number = arc4random_uniform(UInt32(b - a + 1))
            //print("Adding: \(number)")
            remove(Int(number))
        }

        print("length: \(intervalArray.count)")
        print(printIntervalArray())
        
        for _ in 0..<150
        {
            dequeue()
        }
        
        print("length: \(intervalArray.count)")
        print(printIntervalArray())
    }
}

enum interval
{
    case range (from: hyperInt, to: hyperInt)
    case single (at: Int)
}

enum hyperCompare
{
    case larger
    case smaller
    case contained
    case equal
    case impossible
}

enum hyperInt
{
    case negativeInfinity
    case number (Int)
    case positiveInfinity
}
