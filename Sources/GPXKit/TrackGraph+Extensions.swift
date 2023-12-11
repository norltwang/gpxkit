//
//  File.swift
//  
//
//  Created by norltwang-mac on 2023/12/11.
//

import Foundation
import CoreLocation

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

public struct ElevationChartData {
//    private var origin: [DistanceHeight]
    public var simplified: [DistanceHeight]
    public var domains: (distance: [Double], elevation: [Double])
    private func findMultipleDH(every step: Double,in heightMap: [DistanceHeight]) -> [DistanceHeight] {
        var result = [DistanceHeight]()
        
        // Keep track of the closest element for each multiple of distance
        var closestedElements: [Double: DistanceHeight] = [: ]
        for (index,dh) in heightMap.enumerated() {
           
            let closestMultiple = (dh.distance / step).rounded() * step
            
            // Check if the current value is closer than the previously found closest element
            if let currentClosest = closestedElements[closestMultiple] {
                if abs(dh.distance - closestMultiple) < abs(currentClosest.distance - closestMultiple) {
                    closestedElements[closestMultiple] = dh
                    let newDH = DistanceHeight(distance: dh.distance, elevation: dh.elevation, index: index)
                    result.append(newDH)
                }
            } else {
                closestedElements[closestMultiple] = dh
                let newDH = DistanceHeight(distance: dh.distance, elevation: dh.elevation, index: index)
                result.append(newDH)
            }
        }
        return result
        
    }
    private func findMinMax(in heightMap: [DistanceHeight]) -> [DistanceHeight] {
        guard let minMax = heightMap.eleMinMax else { return [ ] }
        return [minMax.min,minMax.max]
    }
    private func findDH(near target: Double,in heightMap: [DistanceHeight]) -> DistanceHeight? {
        guard !simplified.isEmpty else { return nil } // Return nil for an empty array
        
        var left = 0
        var right = heightMap.count - 1
        
        while left <= right {
            let mid = left + (right - left) / 2
            let midValue = heightMap[mid].distance

            if midValue == target {
                return heightMap[mid]  // Found an exact match
            } else if midValue < target {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }
        
        // At this point, left is the index of the smallest element that is greater than the target,
        // and right is the index of the largest element that is less than the target.

        if left < heightMap.count, right >= 0 {
            // Check which element is closer to the target
            let leftDifference = abs(target - heightMap[left].distance)
            let rightDifference = abs(target - heightMap[right].distance)

            if leftDifference < rightDifference {
                return heightMap[left]
            } else {
                return heightMap[right]
            }
        } else if left < heightMap.count {
            return heightMap[left]
        } else if right >= 0 {
            return heightMap[right]
        } else {
            return nil  // The array is empty
        }
         
    }
    public func findDH(near target: Double) -> DistanceHeight? {
        return findDH(near: target, in: simplified)
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
    
     
    public init(origin: [DistanceHeight],step: Double = 50) {
        self.simplified = []
        self.domains = origin.domains
        self.simplified = (self.findMultipleDH(every: step, in: origin) + findMinMax(in: origin)).sorted(by: { $0.distance < $1.distance })
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
    
    fileprivate var domains: (distance: [Double], elevation: [Double]) {
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
