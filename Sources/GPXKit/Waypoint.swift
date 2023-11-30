import Foundation

/// Value type describing a single Waypoint defined  within a `GPXTrack`. A `Waypoint` has a location consisting of latitude, longitude and some metadata,
/// e.g. name and waypointDescription.
public struct Waypoint: Hashable, Sendable, Codable  {
    /// The coordinate (latitude, longitude and elevation in meters)
    public var coordinate: Coordinate
    /// Optional date for a given point.
    public var date: Date?
    /// Optional name of the waypoint
    public var name: String?
    /// Optional comment for the waypoint
    public var comment: String?
    /// Optional description of the waypoint
    public var waypointDescription: String?

    /// Initializer
    /// You don't need to construct this value by yourself, as it is done by GXPKits track parsing logic.
    /// - Parameters:
    ///   - coordinate: Location of the waypoint, required
    ///   - date: Optional date
    ///   - name: Name of the waypoint
    ///   - comment: A short comment
    ///   - waypointDescription: A longer waypointDescription
    public init(coordinate: Coordinate, date: Date? = nil, name: String? = nil, comment: String? = nil, description: String? = nil) {
        self.coordinate = coordinate
        self.date = date
        self.name = name
        self.comment = comment
        self.waypointDescription = description
    }
}
