// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CT",
    products: [
        // 跨平台核心库：模型、存储协议、进度聚合。iOS App / Widget / CLI / 测试共用。
        .library(name: "MacroCore", targets: ["MacroCore"]),
        .executable(name: "CT", targets: ["CT"]),
    ],
    targets: [
        .target(
            name: "MacroCore"
        ),
        .executableTarget(
            name: "CT",
            dependencies: ["MacroCore"]
        ),
        .testTarget(
            name: "CTTests",
            dependencies: ["MacroCore"]
        ),
    ]
)
