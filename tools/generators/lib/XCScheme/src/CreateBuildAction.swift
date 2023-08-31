public struct CreateBuildAction {
    private let callable: Callable

    /// - Parameters:
    ///   - callable: The function that will be called in
    ///     `callAsFunction()`.
    public init(callable: @escaping Callable = Self.defaultCallable) {
        self.callable = callable
    }

    /// Creates a `BuildAction` element of an Xcode scheme.
    public func callAsFunction(
        entries: [BuildActionEntry],
        postActions: [ExecutionAction],
        preActions: [ExecutionAction]
    ) -> String {
        return callable(
            /*entries:*/ entries,
            /*postActions:*/ postActions,
            /*preActions:*/ preActions
        )
    }
}

public struct BuildActionEntry: Equatable {
    public struct BuildFor: Equatable {
        public let testing: Bool
        public let running: Bool
        public let profiling: Bool
        public let archiving: Bool
        public let analyzing: Bool

        public init(
            testing: Bool,
            running: Bool,
            profiling: Bool,
            archiving: Bool,
            analyzing: Bool
        ) {
            self.testing = testing
            self.running = running
            self.profiling = profiling
            self.archiving = archiving
            self.analyzing = analyzing
        }
    }

    public let buildableReference: BuildableReference
    public let buildFor: BuildFor

    public init(
        buildableReference: BuildableReference,
        buildFor: BuildFor
    ) {
        self.buildableReference = buildableReference
        self.buildFor = buildFor
    }
}

// MARK: - CreateBuildAction.Callable

extension CreateBuildAction {
    public typealias Callable = (
        _ entries: [BuildActionEntry],
        _ postActions: [ExecutionAction],
        _ preActions: [ExecutionAction]
    ) -> String

    public static func defaultCallable(
        entries: [BuildActionEntry],
        postActions: [ExecutionAction],
        preActions: [ExecutionAction]
    ) -> String {
        // 3 spaces for indentation is intentional
        return #"""
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "NO">
\#(preActions.preActionsString)\#
\#(postActions.postActionsString)\#
      <BuildActionEntries>
\#(entries.map(createBuildEntryElement).joined(separator: "\n"))
      </BuildActionEntries>
   </BuildAction>
"""#
    }
}

private func createBuildEntryElement(_ entry: BuildActionEntry) -> String {
    let buildFor = entry.buildFor
    let reference = entry.buildableReference

    // 3 spaces for indentation is intentional
    return #"""
         <BuildActionEntry
            buildForTesting = "\#(buildFor.testing.xmlString)"
            buildForRunning = "\#(buildFor.running.xmlString)"
            buildForProfiling = "\#(buildFor.profiling.xmlString)"
            buildForArchiving = "\#(buildFor.archiving.xmlString)"
            buildForAnalyzing = "\#(buildFor.analyzing.xmlString)">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "\#(reference.blueprintIdentifier)"
               BuildableName = "\#(reference.buildableName)"
               BlueprintName = "\#(reference.blueprintName)"
               ReferencedContainer = "\#(reference.referencedContainer)">
            </BuildableReference>
         </BuildActionEntry>
"""#
}
