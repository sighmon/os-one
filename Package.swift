// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OS One",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OS One",
            targets: ["OS One"]),
    ],
    dependencies: [
        // MLX Swift - Apple's machine learning framework for Apple Silicon
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.11.0"),

        // Tokenizers - HuggingFace tokenizers for Swift
        .package(url: "https://github.com/huggingface/swift-transformers.git", from: "0.1.5"),
    ],
    targets: [
        .target(
            name: "OS One",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "OS One"
        ),
    ]
)
