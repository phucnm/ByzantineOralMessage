//
//  main.swift
//  ByzantineOM
//
//  Created by TonyNguyen on 11/11/18.
//  Copyright © 2018 TonyNguyen. All rights reserved.
//

import Foundation

enum Message: Int {
    case attack
    case retreat
}

// All the paths can be considered as a complete graph.
struct Node {

    /// The message that the node received from other lieutenants.
    var input: Message

    /// The message that is the decision of the node by computing majority.
    var output: Message
}

class General {

    //According to the assignment description, the commander has id of 0
    let id: Int
    let isTraitor: Bool
    let nGenerals: Int
    let nTraitors: Int
    let oc: Message

    private var nodes: [String: Node] = [String: Node]()

    static var childrenPath: [String: [String]] = [String: [String]]()
    static var pathsByRound: [Int: [Int: [String]]] = [Int: [Int: [String]]]()

    /// This function recursively build a tree of possible paths.
    /// childrenPath contains a dictionary(map) where the key is the current path of the node
    /// and the value is the array of all child paths of the path.
    ///
    /// - Parameters:
    ///   - nTraitor: number of traitors/round
    ///   - nGenerals: number of generals
    ///   - ids: an array of booleans indicates which lieutenants to go next (equal to true)
    ///   - parent: id of the parent node
    ///   - path: current path
    ///   - round: current round
    static func generateChildren(
        nTraitors: Int,
        nGenerals: Int,
        ids: [Bool],
        parent: Int = 0,
        path: String = "",
        round: Int = 0
        ) {
        // Build a new chain from this node
        let chain = path.appending(String(parent))

        // Here's the syntax of Swift4.2 where I can safely get an entry in a dictionary without checking
        // whether if a pair (key, value) is initialized or not
        pathsByRound[round, default: [Int: [String]]()][parent, default: [String]()].append(chain)

        // I simply mark myself to `false` to avoid creating a cycle chain
        var ids = ids
        ids[parent] = false

        // I know when to stop. If we have n traitors we'll have n+1 rounds
        if round < nTraitors {
            for (i, id) in ids.enumerated() where id == true {
                generateChildren(nTraitors: nTraitors,
                                 nGenerals: nGenerals,
                                 ids: ids,
                                 parent: i,
                                 path: chain,
                                 round: round + 1
                )
                childrenPath[chain, default: [String]()].append(chain.appending(String(i)))
            }
        }
    }

    init(id: Int, isTraitor: Bool, nGenerals: Int, nTraitors: Int, oc: Message) {
        self.id = id
        self.isTraitor = isTraitor
        self.nGenerals = nGenerals
        self.nTraitors = nTraitors
        self.oc = oc
        nodes[""] = Node(input: oc, output: .retreat)
    }

    private func newMessage(for message: Message, sendTo id: Int) -> Message {
        if isTraitor && id % 2 == 0 {
            return message == .attack ? .retreat : .attack
        }
        return message
    }

    func sendMessage(inRound round: Int, to generals: [General]) {
        guard let paths = General.pathsByRound[round]?[id] else {
            return
        }
        for (idx, path) in paths.enumerated() {
            let sourcePath = String(path.dropLast())
            guard let sourceNode = nodes[sourcePath] else {
                return
            }
            for i in 1..<nGenerals {
                if let pathToThisGeneral = General.pathsByRound[round]?[id]?[idx] {
                    // Default to retreat
                    let node = Node(input: newMessage(for: sourceNode.input, sendTo: i), output: .retreat)
                    generals[i].receiveMessage(from: pathToThisGeneral, node: node)
                }
            }
        }
    }

    func receiveMessage(from path: String, node: Node) {
        nodes[path] = node
    }

    func vote() -> Message {
        // Start from the leaves of the tree
        for i in 1..<nGenerals {
            if let paths = General.pathsByRound[nTraitors]?[i] {
                for path in paths {
                    if var node = nodes[path] {
                        node.output = node.input
                        nodes[path] = node
                    }
                }
            }
        }
        //Working up the tree to calculate the majority at each round
        for round in (0..<nTraitors).reversed() {
            for i in 0..<nGenerals {
                if let paths = General.pathsByRound[round]?[i] {
                    for path in paths {
                        if var node = nodes[path] {
                            node.output = majority(path: path)
                            nodes[path] = node
                        }
                    }
                }
            }
        }
        guard let root = General.pathsByRound[0]?[0]?.first,
        let rootNode = nodes[root] else { return .retreat }
        return rootNode.output
    }

    private func majority(path: String) -> Message {
        guard let childPaths = General.childrenPath[path] else { return .retreat }
        let nodes = childPaths.compactMap { self.nodes[$0] }
        let attackCount = nodes.filter { $0.output == .attack }.count
        return attackCount > childPaths.count / 2 ? .attack : .retreat
    }
}

let nTraitors = 2
let nGenerals = 7
let ids = Array(repeating: true, count: nGenerals)
let traitorIndexes = [5, 6]
let oc = Message.attack

General.generateChildren(nTraitors: nTraitors, nGenerals: nGenerals, ids: ids)
var generals = [General]()
(0..<nGenerals).forEach { (i) in
    generals.append(
        General(
            id: i,
            isTraitor: traitorIndexes.contains(i),
            nGenerals: nGenerals,
            nTraitors: nTraitors,
            oc: oc
        )
    )
}
for i in 0...nTraitors {
    for j in 0..<nGenerals {
        generals[j].sendMessage(inRound: i, to: generals)
    }
}

// Printing the results
for (idx, general) in generals.enumerated() {
    if idx == 0 {
        //commander
        print("General \(idx): \(general.oc)")
    } else {
        print("General \(idx): \(general.vote())")
    }
}
