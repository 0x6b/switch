import Foundation

protocol WindowActioning {
    func activate(_ entry: WindowEntry)
    func close(_ entry: WindowEntry)
    func quit(_ entry: WindowEntry)
    func hide(_ entry: WindowEntry)
    func minimize(_ entry: WindowEntry)
}
