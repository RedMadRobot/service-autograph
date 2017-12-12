// swift-tools-version:4.0


import PackageDescription


let package = Package(
    name: "ServiceAutograph",
    products: [
        Product.executable(
            name: "ServiceAutograph",
            targets: ["ServiceAutograph"]
        ),
    ],
    dependencies: [
        Package.Dependency.package(
            url: "https://github.com/RedMadRobot/autograph",
            from: "1.1.1"
        )
    ],
    targets: [
        Target.target(
            name: "ServiceAutograph",
            dependencies: ["Autograph"]
        ),
        Target.testTarget(
            name: "ServiceAutographTests",
            dependencies: ["ServiceAutograph"]
        ),
    ]
)
