//
//  File.swift
//  
//
//  Created by norltwang-mac on 2023/12/11.
//

import Foundation
import CoreLocation
import Algorithms
//MARK: - TrackGraph
extension TrackGraph {
    ///  The GCJ-02  Coordinates of this track
    public var transformedPoints: [CLLocationCoordinate2D] {
        self.coreLocationCoordinates.map {
            let (gcjLat,gcjLon) = LocationTransform.wgs2gcj(wgsLat: $0.latitude, wgsLng: $0.longitude)
            return .init(latitude: gcjLat, longitude: gcjLon)
        }
    }
}


//MARK: - ChartData
public typealias HeightMap = [DistanceHeight]
/// This class works with origin heightMap Data from a GPXTrack,and simplify data with a stepper.
public struct ElevationDataSimplifyManager {
    
    public var simplified: HeightMap
    public init(origin: HeightMap,stepper step: Double) {
        self.simplified = []
        self.simplified = (findMultipleDHs(every: step, in: origin) + findMinMax(in: origin)).sorted(by: { $0.distance < $1.distance })
    }
    
    ///This method search through all datas,and find datas near stepper.
    ///time complex: o(n)
    private func findMultipleDHs(every target: Double,in heightMap: HeightMap) -> HeightMap {
        
        guard !heightMap.isEmpty else { return [] }
        
        let result = heightMap.enumerated()
            .map { return ($0.offset,$0.element) } //: -> o(n)
            .map{
                return ($0.0,($0.1.distance / target).rounded(.towardZero),$0.1.distance.truncatingRemainder(dividingBy: target))
            }
            .chunked(by: { $0.1 == $1.1 })//: -> o(n)
            .map { Array($0) }
        
        var tmps: [(Int,(Double),Double)] = result.compactMap { $0.first } //: -> o(n)
        
        let drop = result.dropFirst()
        let new = zip(result, drop) //: -> o(n)
        
    //    for item in new.enumerated() {
    //        print(item.offset,item.element)
    //        print("\n")
    //    }
        
        new.enumerated().forEach {
            let index = $0.offset
            let element = $0.element
            let q2 = element.1.first.map { $0.1 }!
            let q1 = element.0.first.map { $0.1 }!
            if q2 - q1 == 1,
               let r2 = element.1.first?.2,
               let r1 = element.0.last?.2,
               abs(target - r1) < r2,
               let changed = element.0.last {
                tmps[index + 1] = changed
            }
        } //: -> o(n)

        return tmps.map { heightMap[$0.0] }
    }
    
    private func findMinMax(in heightMap: HeightMap) -> HeightMap {
        guard let minMax = heightMap.eleMinMax else { return [ ] }
        return [minMax.min,minMax.max]
    }
    
    public static func simplifiedData(from origin: HeightMap,with stepper: Double) async -> HeightMap {
        let manager = ElevationDataSimplifyManager(origin: origin, stepper: stepper)
        return manager.simplified
    }
    
}

//MARK: - For Elevation Chart
extension Array where Element == DistanceHeight {
    
    public var eleMinMax: (min: DistanceHeight,max: DistanceHeight)? {
        let minMax = self.enumerated()
            .map { ($0.offset,$0.element) }
            .minAndMax { $0.1.elevation < $1.1.elevation }
            .map { (min,max) in
                let minElevation = DistanceHeight(distance: min.1.distance, elevation: min.1.elevation, index: min.0)
                let maxElevation = DistanceHeight(distance: max.1.distance, elevation: max.1.elevation, index: max.0)
                return (minElevation,maxElevation)
            }
        return minMax
    }
    
    public var domains: (distance: [Double], elevation: [Double]) {
        return (dis_domain,ele_domain)
    }
    
    private var dis_domain: [Double] {
        let distances = self.map { $0.distance }
        guard let start = distances.first,let end = distances.last else { return [] }
        return [start,end]
    }
    
    private var ele_domain: [Double] {
        guard let low = eleMinMax?.min,let up = eleMinMax?.max else { return [] }
        return [low.elevation > 0 ? 0 : low.elevation, up.elevation]
    }
    
}
//MARK: - Find DH with a distance
extension Array where Element == DistanceHeight {
    
    //TODO: - 等待用 Algorithms 重写
    public func findDH(near target: Double) -> DistanceHeight? {
        guard !self.isEmpty else { return nil } // Return nil for an empty array
        
        var left = 0
        var right = self.count - 1
        
        while left <= right {
            let mid = left + (right - left) / 2
            let midValue = self[mid].distance

            if midValue == target {
                return self[mid]  // Found an exact match
            } else if midValue < target {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        
        // At this point, left is the index of the smallest element that is greater than the target,
        // and right is the index of the largest element that is less than the target.

        if left < self.count, right >= 0 {
            // Check which element is closer to the target
            let leftDifference = abs(target - self[left].distance)
            let rightDifference = abs(target - self[right].distance)

            if leftDifference < rightDifference {
                return self[left]
            } else {
                return self[right]
            }
        } else if left < self.count {
            return self[left]
        } else if right >= 0 {
            return self[right]
        } else {
            return nil  // The array is empty
        }
    }
    
    public func findIndex(near target: Double) -> Int? {
        guard let dh = self.findDH(near: target) else { return nil }
        return dh.index
    }
    
    public func findRange(with targetRange: Range<Double>) -> ClosedRange<Int>? {
        guard let lower = self.findDH(near: targetRange.lowerBound) ,
              let upper = self.findDH(near: targetRange.upperBound) else { return nil }
        guard let lowerIndex = lower.index,let upperIndex = upper.index,lowerIndex < upperIndex else { return nil }
        return (lowerIndex...upperIndex)
    }
}

//MARK: - Find Ascent and Descent
extension Array where Element == DistanceHeight {
    public func distances(of range: ClosedRange<Int>) -> Double {
        let start = self[range.lowerBound]
        let end = self[range.upperBound]
        return end.distance - start.distance
    }
    
    public func descending(of index: Int) -> Double {
        let zipped = zip(Array(self[0...index]), Array(self[0...index].dropFirst()))
        return ascending(zipped)
    }
    
    public func ascending(of index: Int) -> Double {
        let zipped = zip(Array(self[0...index]), Array(self[0...index].dropFirst()))
        return descending(zipped)
    }

    public func descending(of range: ClosedRange<Int>) -> Double {
        let array = Array(self[range])
        let zipped = zip(array,Array(array.dropFirst()))
        return descending(zipped)
    }

    public func ascending(of range: ClosedRange<Int>) -> Double {
        let array = Array(self[range])
        let zipped = zip(array,Array(array.dropFirst()))
        return ascending(zipped)
    }

    private func descending(_ zipped: Zip2Sequence<Self,Self>) -> Double {
        return zipped.reduce(0) { elevation, pair in
            let delta = pair.1.elevation - pair.0.elevation
            if delta < 0 { return elevation + abs(delta)}
            return elevation
        }
    }

    private func ascending(_ zipped: Zip2Sequence<Self,Self>) -> Double {
        return zipped.reduce(0) { elevation, pair in
            let delta = pair.1.elevation - pair.0.elevation
            if delta > 0 { return elevation + delta }
            return elevation
        }
    }

}
