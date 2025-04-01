//
//  HelperGestures.swift
//  Behavolve
//
//  Created by Michaël ATTAL on 30/01/2025.
//

import RealityKit

enum HelperGestures {
    static func findTarget(_ target: Entity, from child: Entity) -> Entity? {
        var parent = child.parent
        var finded = false

        while finded == false {
            if let currentParent = parent {
                if currentParent == target {
                    finded = true
                } else {
                    parent = parent?.parent
                }
            } else {
                print("ERROR: Entity target not found.")
                return nil
            }
        }

        if finded == false {
            print("ERROR: Entity target not found.")
        }

        return parent
    }
}
