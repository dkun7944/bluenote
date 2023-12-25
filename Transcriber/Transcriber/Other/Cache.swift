//
//  ProjectCache.swift
//  Transcriber
//
//  Created by Daniel Kuntz on 11/25/21.
//

import Foundation

protocol Cacheable: Codable, AnyObject {
    func getFilename() -> String
    func cache()
}

class ItemCache<T: Cacheable> {
    func getAllItems() -> [T] {
        var items: [T] = []

        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                    in: .userDomainMask,
                                                                    appropriateFor: nil,
                                                                    create: true)

            let enumerator = FileManager.default.enumerator(atPath: documentsDirectory.path)
            let filePaths = enumerator?.allObjects as! [String]
            let stravaActivityFilePaths = filePaths.filter { $0.contains(".json") }

            for path in stravaActivityFilePaths {
                let url = documentsDirectory.appendingPathComponent(path)

                do {
                    let item = try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
                    items.append(item)
                } catch {
                    print(error)
                }
            }
        } catch {
            print(error)
        }

        return items
    }

    func cacheItem(_ item: T) {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                    in: .userDomainMask,
                                                                    appropriateFor: nil,
                                                                    create: true)
            let cacheFileName = "\(item.getFilename())"
            let fileUrl: URL = documentsDirectory.appendingPathComponent(cacheFileName)
            try JSONEncoder().encode(item).write(to: fileUrl)
        } catch {
            print(error)
        }
    }

    func deleteItem(_ item: T) {
        do {
            let documentsDirectory = try FileManager.default.url(for: .documentDirectory,
                                                                 in: .userDomainMask,
                                                                 appropriateFor: nil,
                                                                 create: true)
            let cacheFileName = "\(item.getFilename())"
            let fileUrl: URL = documentsDirectory.appendingPathComponent(cacheFileName)
            try FileManager.default.removeItem(at: fileUrl)
        } catch {
            print(error)
        }
    }
}

class Cache {
    static let projects = ItemCache<Project>()
}
