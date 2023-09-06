import Foundation
import PBXProj

extension Generator {
    struct WriteAutomaticSchemes {
        private let createAutomaticScheme: CreateAutomaticScheme
        private let write: Write

        private let callable: Callable

        /// - Parameters:
        ///   - callable: The function that will be called in
        ///     `callAsFunction()`.
        init(
            createAutomaticScheme: CreateAutomaticScheme,
            write: Write,
            callable: @escaping Callable = Self.defaultCallable
        ) {
            self.createAutomaticScheme = createAutomaticScheme
            self.write = write

            self.callable = callable
        }

        /// Creates and writes automatically generated `.xcscheme`s to disk.
        func callAsFunction(
            defaultXcodeConfiguration: String,
            extensionHostIDs: [TargetID: [TargetID]],
            identifiedTargets: [IdentifiedTarget],
            referencedContainer: String,
            to xcshemesOutputDirectory: URL
        ) async throws {
            try await callable(
                /*defaultXcodeConfiguration:*/ defaultXcodeConfiguration,
                /*extensionHostIDs:*/ extensionHostIDs,
                /*identifiedTargets:*/ identifiedTargets,
                /*referencedContainer:*/ referencedContainer,
                /*xcshemesOutputDirectory:*/ xcshemesOutputDirectory,
                /*createAutomaticScheme:*/ createAutomaticScheme,
                /*write:*/ write
            )
        }
    }
}

// MARK: - WriteAutomaticSchemes.Callable

extension Generator.WriteAutomaticSchemes {
    typealias Callable = (
        _ defaultXcodeConfiguration: String,
        _ extensionHostIDs: [TargetID: [TargetID]],
        _ identifiedTargets: [IdentifiedTarget],
        _ referencedContainer: String,
        _ xcshemesOutputDirectory: URL,
        _ createAutomaticScheme: Generator.CreateAutomaticScheme,
        _ write: Write
    ) async throws -> Void

    static func defaultCallable(
        defaultXcodeConfiguration: String,
        extensionHostIDs: [TargetID: [TargetID]],
        identifiedTargets: [IdentifiedTarget],
        referencedContainer: String,
        xcshemesOutputDirectory: URL,
        createAutomaticScheme: Generator.CreateAutomaticScheme,
        write: Write
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            let identifiedTargetKeys: [TargetID: ConsolidatedTarget.Key]
            let identifiedTargetsByKey:
                [ConsolidatedTarget.Key: IdentifiedTarget]
            if extensionHostIDs.isEmpty {
                identifiedTargetKeys = [:]
                identifiedTargetsByKey = [:]
            } else {
                identifiedTargetKeys = Dictionary(
                    uniqueKeysWithValues: identifiedTargets.flatMap { target in
                        return target.key.sortedIds.map { ($0, target.key) }
                    }
                )
                identifiedTargetsByKey = Dictionary(
                    uniqueKeysWithValues: identifiedTargets.map { target in
                        return (target.key, target)
                    }
                )
            }

            for target in identifiedTargets {
                guard target.productType.shouldCreateScheme else {
                    continue
                }

                let extensionHostKeys: Set<ConsolidatedTarget.Key>
                if extensionHostIDs.isEmpty {
                    extensionHostKeys = []
                } else {
                    extensionHostKeys = Set(
                        try target.key.sortedIds
                            .flatMap { id in
                                return try extensionHostIDs[id, default: []]
                                    .map { id in
                                        return try identifiedTargetKeys.value(
                                            for: id,
                                            context: "Extension host target ID"
                                        )
                                    }
                            }
                    )
                }

                if extensionHostKeys.isEmpty {
                    group.addTask {
                        let (name, scheme) = try createAutomaticScheme(
                            defaultXcodeConfiguration:
                                defaultXcodeConfiguration,
                            extensionHost: nil,
                            referencedContainer: referencedContainer,
                            target: target
                        )

                        try write(
                            scheme,
                            to: xcshemesOutputDirectory
                                .appending(path: "\(name).xcscheme")
                        )
                    }
                } else {
                    for key in extensionHostKeys {
                        group.addTask {
                            let (name, scheme) = try createAutomaticScheme(
                                defaultXcodeConfiguration:
                                    defaultXcodeConfiguration,
                                extensionHost: try identifiedTargetsByKey.value(
                                    for: key,
                                    context:
                                        "Extension host consolidated target key"
                                ),
                                referencedContainer: referencedContainer,
                                target: target
                            )

                            try write(
                                scheme,
                                to: xcshemesOutputDirectory
                                    .appending(path: "\(name).xcscheme")
                            )
                        }
                    }
                }
            }

            try await group.waitForAll()
        }
    }
}

private extension PBXProductType {
    var shouldCreateScheme: Bool {
        switch self {
        case .messagesApplication, .watch2AppContainer, .watch2Extension:
            return false
        default:
            return true
        }
    }
}
