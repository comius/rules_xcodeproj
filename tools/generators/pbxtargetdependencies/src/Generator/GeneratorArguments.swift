import ArgumentParser
import Foundation
import GeneratorCommon
import PBXProj

extension Generator {
    struct Arguments: ParsableArguments {
        @Argument(
            help: """
Path to where the 'pbxtargetdependencies' 'PBXProj' partial should be written.
""",
            transform: { URL(fileURLWithPath: $0, isDirectory: false) }
        )
        var targetDependenciesOutputPath: URL

        @Argument(
            help: """
Path to where the 'pbxtargetdependencies' 'PBXProj' partial should be written.
""",
            transform: { URL(fileURLWithPath: $0, isDirectory: false) }
        )
        var targetsOutputPath: URL

        @Argument(
            help: """
Path to where the 'pbxproject_target_attributes' 'PBXProj' partial should be \
written.
""",
            transform: { URL(fileURLWithPath: $0, isDirectory: false) }
        )
        var targetAttributesOutputPath: URL

        @Argument(
            help: """
Path to the directory where automatic `.xcscheme` files should be written.
""",
            transform: { URL(fileURLWithPath: $0, isDirectory: true) }
        )
        var xcshemesOutputDirectory: URL

        @Argument(help: """
Minimum Xcode version that the generated project supports.
""")
        var minimumXcodeVersion: SemanticVersion

        @Argument(help: "Name of the default Xcode configuration.")
        var defaultXcodeConfiguration: String

        @Argument(help: "Absolute path to the Bazel workspace.")
        var workspace: String

        @Argument(help: """
Bazel workspace relative path to where the final `.xcodeproj` will be output.
""")
        var installPath: String

        @Option(
            parsing: .upToNextOption,
            help: "Pairs of <target> <test-host> target IDs."
        )
        private var targetAndTestHosts: [TargetID] = []

        @Option(
            parsing: .upToNextOption,
            help: "Pairs of <target> <extension-host> target IDs."
        )
        private var targetAndExtensionHosts: [TargetID] = []

        @OptionGroup var consolidationMapsArguments: ConsolidationMapsArguments

        mutating func validate() throws {
            guard targetAndTestHosts.count.isMultiple(of: 2) else {
                throw ValidationError("""
<target-and-test-hosts> (\(targetAndTestHosts.count) elements) must be \
<target> and <test-host> pairs.
""")
            }

            guard targetAndExtensionHosts.count.isMultiple(of: 2) else {
                throw ValidationError("""
<target-and-extension-hosts> (\(targetAndExtensionHosts.count) elements) must \
be <target> and <extension-hosts> pairs.
""")
            }
        }
    }
}

extension Generator.Arguments {
    var extensionHostIDs: [TargetID: [TargetID]] {
        var ret: [TargetID: [TargetID]] = [:]
        for index in stride(
            from: 0,
            to: targetAndExtensionHosts.count - 1,
            by: 2
        ) {
            ret[targetAndExtensionHosts[index], default: []]
                .append(targetAndExtensionHosts[index+1])
        }
        return ret
    }

    var testHosts: [TargetID: TargetID] {
        return Dictionary(
            uniqueKeysWithValues:
                stride(from: 0, to: targetAndTestHosts.count - 1, by: 2)
                .lazy
                .map { index in
                    return (
                        targetAndTestHosts[index],
                        targetAndTestHosts[index+1]
                    )
                }
        )
    }
}
