enum FrozenMotionContract {
    struct Revision: Sendable {
        let reference: String
        let modelFile: String
        let modelSHA256: String
        let controllerFile: String
        let controllerSHA256: String
        let stageFile: String
        let stageSHA256: String
    }

    static let v1 = Revision(
        reference: "card-motion-plane-lock-v1",
        modelFile: "PlaneLockModel.swift",
        modelSHA256: "1b4afc9f0df4669debd2e86e8013416b6cc27cddceb5ebfa5b22247c5eaf6729",
        controllerFile: "PlaneLockController.swift",
        controllerSHA256: "018504e26ab18f5605be1221d6d1022fcaf348ad943fa5d66c7ce7dbf9f075c6",
        stageFile: "PlaneLockStage.swift",
        stageSHA256: "c8b44118b4442aa9bf588fd8e0fe2d50d5494f653ff3ac0d2be2655fd7305325"
    )
    static let v2 = Revision(
        reference: "card-motion-material-lock-v2",
        modelFile: "MaterialLockModel.swift",
        modelSHA256: "57898a7157ca5e8c987021f4b412ca20d6daa402d84be066d732ffc07b59c32e",
        controllerFile: "MaterialLockController.swift",
        controllerSHA256: "018504e26ab18f5605be1221d6d1022fcaf348ad943fa5d66c7ce7dbf9f075c6",
        stageFile: "MaterialLockStage.swift",
        stageSHA256: "5e91af4a2ea862ca50625ed37899ec89682974f00732dc4a2334229b57be3971"
    )
    static let v3 = Revision(
        reference: "card-motion-material-lock-v3",
        modelFile: "MaterialLockModel.swift",
        modelSHA256: "57898a7157ca5e8c987021f4b412ca20d6daa402d84be066d732ffc07b59c32e",
        controllerFile: "MaterialLockController.swift",
        controllerSHA256: "018504e26ab18f5605be1221d6d1022fcaf348ad943fa5d66c7ce7dbf9f075c6",
        stageFile: "MaterialLockStage.swift",
        stageSHA256: "d6885cd33530a0f81876ca2af38499d49b56e72dde5f3f7768e6ef9c27cb08a3"
    )

    static let w2ContractSHA256 = "8d44945cd1b304442f331cd328bc34d94cf3ae5d907a457c8148e9e628a83573"
}
