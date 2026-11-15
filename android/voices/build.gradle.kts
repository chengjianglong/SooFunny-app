plugins {
    id("com.android.asset-pack")
}

// Models aren't stored in git: run scripts/fetch_model.sh, and the copy task below puts them here.
assetPack {
    packName.set("voices")
    dynamicDelivery {
        deliveryType.set("install-time")
    }
}

/** Kokoro-82M English (8-bit) and Chinese (16-bit) voices, from ../Models (see scripts/fetch_model.sh). */
val copyModels = tasks.register<Sync>("copyModels") {
    from(rootProject.layout.projectDirectory.dir("../Models")) {
        include("kokoro-82m-q8.onnx", "kokoro-v1.1-zh-fp16.onnx")
    }
    into(layout.projectDirectory.dir("src/main/assets/voices"))
}
