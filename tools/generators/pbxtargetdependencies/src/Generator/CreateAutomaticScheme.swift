import PBXProj
import XCScheme

extension Generator {
    struct CreateAutomaticScheme {
        private let createScheme: CreateScheme

        private let callable: Callable

        /// - Parameters:
        ///   - callable: The function that will be called in
        ///     `callAsFunction()`.
        init(
            createScheme: CreateScheme,
            callable: @escaping Callable = Self.defaultCallable
        ) {
            self.createScheme = createScheme

            self.callable = callable
        }

        /// Creates the XML for an automatically generated `.xcsheme` file.
        func callAsFunction(
            defaultXcodeConfiguration: String,
            extensionHost: IdentifiedTarget?,
            referencedContainer: String,
            target: IdentifiedTarget
        ) throws -> (name: String, scheme: String) {
            return try callable(
                /*defaultXcodeConfiguration:*/ defaultXcodeConfiguration,
                /*extensionHost:*/ extensionHost,
                /*referencedContainer:*/ referencedContainer,
                /*target:*/ target,
                /*createScheme:*/ createScheme
            )
        }
    }
}

// MARK: - CreateAutomaticScheme.Callable

extension Generator.CreateAutomaticScheme {
    typealias Callable = (
        _ defaultXcodeConfiguration: String,
        _ extensionHost: IdentifiedTarget?,
        _ referencedContainer: String,
        _ target: IdentifiedTarget,
        _ createScheme: CreateScheme
    ) throws -> (name: String, scheme: String)

    static func defaultCallable(
        defaultXcodeConfiguration: String,
        extensionHost: IdentifiedTarget?,
        referencedContainer: String,
        target: IdentifiedTarget,
        createScheme: XCScheme.CreateScheme
    ) throws -> (name: String, scheme: String) {
        let productType = target.productType

        let buildableReference = BuildableReference(
            blueprintIdentifier: target.identifier.withoutComment,
            buildableName: target.productBasename,
            blueprintName: target.name,
            referencedContainer: referencedContainer
        )
        let buildActionEntry = BuildActionEntry(
            buildableReference: buildableReference,
            buildFor: .all
        )

        let isLaunchable = productType.isLaunchable
        let isTest = productType.isTest

        let buildActionEntries: [BuildActionEntry]
        let name: String
        let runnable: Runnable?
        let wasCreatedForAppExtension: Bool
        if let extensionHost {
            let hostBuildableReference = BuildableReference(
                blueprintIdentifier:
                    extensionHost.identifier.withoutComment,
                buildableName: extensionHost.productBasename,
                blueprintName: extensionHost.name,
                referencedContainer: referencedContainer
            )

            buildActionEntries = [
                buildActionEntry,
                .init(
                    buildableReference: hostBuildableReference,
                    buildFor: .all
                )
            ]
            name =
                "\(target.name.schemeName) in \(extensionHost.name.schemeName)"
            runnable = .hosted(
                buildableReference: buildableReference,
                hostBuildableReference: .init(
                    blueprintIdentifier:
                        extensionHost.identifier.withoutComment,
                    buildableName: extensionHost.productBasename,
                    blueprintName: extensionHost.name,
                    referencedContainer: referencedContainer
                ),
                // FIXME: Get this info from ExtensionPointIdentifiers
                debuggingMode: 42,
                remoteBundleIdentifier: "FIXME"
            )
            wasCreatedForAppExtension = true
        } else {
            buildActionEntries = [buildActionEntry]
            name = target.name.schemeName
            wasCreatedForAppExtension = false

            if isLaunchable {
                runnable = .plain(buildableReference: buildableReference)
            } else {
                runnable = nil
            }
        }

        let launchPreActions: [ExecutionAction]
        if isLaunchable || isTest {
            launchPreActions = [
                .updateLldbInitAndCopyDSYMs(
                    for: buildableReference
                ),
            ]
        } else {
            launchPreActions = []
        }

        let scheme = createScheme(
            buildAction: CreateBuildAction()(
                entries: buildActionEntries,
                postActions: [],
                preActions: [
                    .initializeBazelBuildOutputGroupsFile(
                        with: buildableReference
                    ),
                    .prepareBazelDependencies(with: buildableReference),
                ]
            ),
            testAction: CreateTestAction()(
                buildConfiguration: defaultXcodeConfiguration,
                commandLineArguments: [],
                enableAddressSanitizer: false,
                enableThreadSanitizer: false,
                enableUBSanitizer: false,
                environmentVariables: [],
                expandVariablesBasedOn: nil,
                postActions: [],
                preActions: [],
                testables: isTest ? [buildableReference] : [],
                useLaunchSchemeArgsEnv: true
            ),
            launchAction: CreateLaunchAction()(
                buildConfiguration: defaultXcodeConfiguration,
                commandLineArguments: [],
                customWorkingDirectory: nil,
                enableAddressSanitizer: false,
                enableThreadSanitizer: false,
                enableUBSanitizer: false,
                environmentVariables: baseEnvironmentVariables,
                postActions: [],
                preActions: launchPreActions,
                runnable: runnable
            ),
            profileAction: CreateProfileAction()(
                buildConfiguration: defaultXcodeConfiguration,
                commandLineArguments: [],
                customWorkingDirectory: nil,
                environmentVariables: [],
                postActions: [],
                preActions: launchPreActions,
                useLaunchSchemeArgsEnv: true,
                runnable: runnable
            ),
            analyzeAction: CreateAnalyzeAction()(
                buildConfiguration: defaultXcodeConfiguration
            ),
            archiveAction: CreateArchiveAction()(
                buildConfiguration: defaultXcodeConfiguration
            ),
            wasCreatedForAppExtension: wasCreatedForAppExtension
        )

        return (name, scheme)
    }
}

private let baseEnvironmentVariables: [EnvironmentVariable] = [
    .init(
        key: "BUILD_WORKING_DIRECTORY",
        value: "$(BUILT_PRODUCTS_DIR)"
    ),
    .init(
        key: "BUILD_WORKSPACE_DIRECTORY",
        value: "$(BUILD_WORKSPACE_DIRECTORY)"
    ),
]

private extension BuildActionEntry.BuildFor {
    static let all = Self(
        testing: true,
        running: true,
        profiling: true,
        archiving: true,
        analyzing: true
    )
}

private extension ExecutionAction {
    static let initializeBazelBuildOutputGroupsFileScriptText = #"""
mkdir -p "${BUILD_MARKER_FILE%/*}"
touch "$BUILD_MARKER_FILE"

"""#.schemeXmlEscaped

    static func initializeBazelBuildOutputGroupsFile(
        with buildableReference: BuildableReference
    ) -> Self {
        return Self(
            title: "Initialize Bazel Build Output Groups File",
            escapedScriptText: initializeBazelBuildOutputGroupsFileScriptText,
            expandVariablesBasedOn: buildableReference
        )
    }

    static let prepareBazelDependenciesScriptText = #"""
mkdir -p "$PROJECT_DIR"

if [[ "${ENABLE_ADDRESS_SANITIZER:-}" == "YES" || \
      "${ENABLE_THREAD_SANITIZER:-}" == "YES" || \
      "${ENABLE_UNDEFINED_BEHAVIOR_SANITIZER:-}" == "YES" ]]
then
    # TODO: Support custom toolchains once clang.sh supports them
    cd "$INTERNAL_DIR" || exit 1
    ln -shfF "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib" lib
fi

"""#.schemeXmlEscaped

    /// Symlinks `$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/lib` to
    /// `$(BAZEL_INTEGRATION_DIR)/../lib` so that Xcode can copy sanitizers'
    /// dylibs.
    static func prepareBazelDependencies(
        with buildableReference: BuildableReference
    ) -> Self {
        return Self(
            title: "Prepare BazelDependencies",
            escapedScriptText: prepareBazelDependenciesScriptText,
            expandVariablesBasedOn: buildableReference
        )
    }

    static let updateLldbInitAndCopyDSYMsSxriptText = #"""
"$BAZEL_INTEGRATION_DIR/create_lldbinit.sh"
"$BAZEL_INTEGRATION_DIR/copy_dsyms.sh"

"""#.schemeXmlEscaped

    static func updateLldbInitAndCopyDSYMs(
        for buildableReference: BuildableReference
    ) -> Self {
        return Self(
            title: "Update .lldbinit and copy dSYMs",
            escapedScriptText: updateLldbInitAndCopyDSYMsSxriptText,
            expandVariablesBasedOn: buildableReference
        )
    }
}

private extension String {
    var schemeName: String {
        return replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }
}

private extension PBXProductType {
    var isLaunchable: Bool {
        switch self {
        case .application,
                .messagesApplication,
                .onDemandInstallCapableApplication,
                .watch2App,
                .watch2AppContainer,
                .appExtension,
                .intentsServiceExtension,
                .messagesExtension,
                .tvExtension,
                .extensionKitExtension,
                .xcodeExtension,
                .driverExtension,
                .systemExtension,
                .commandLineTool,
                .xpcService:
            return true
        default:
            return false
        }
    }

    var isTest: Bool {
        switch self {
        case .unitTestBundle, .uiTestBundle: return true
        default: return false
        }
    }

    var shouldCreateScheme: Bool {
        switch self {
        case .messagesApplication, .watch2AppContainer, .watch2Extension:
            return false
        default:
            return true
        }
    }
}
