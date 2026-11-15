
# The talking buddy's JNI bridge calls these by name (src/main/cpp/llama_jni.cpp).
-keep class com.chengjianglong.soofunny.core.buddy.LlamaNative { *; }
-keep class * implements com.chengjianglong.soofunny.core.buddy.LlamaNative$Callback { *; }
-keep interface com.chengjianglong.soofunny.core.buddy.LlamaNative$Callback { *; }

# ML Kit finds its components by class name (listed in its manifests) and creates them with
# their no-argument constructors, which R8 otherwise removes.
-keep class com.google.mlkit.**.*Registrar { <init>(); }
-keep class com.google.android.gms.internal.mlkit_vision_**.*Registrar { <init>(); }
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# ONNX Runtime's Java API is called from its native library by name.
-keep class ai.onnxruntime.** { *; }
