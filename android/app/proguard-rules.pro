
# The talking buddy's JNI bridge calls these by name (src/main/cpp/llama_jni.cpp).
-keep class com.chengjianglong.soofunny.core.buddy.LlamaNative { *; }
-keep class * implements com.chengjianglong.soofunny.core.buddy.LlamaNative$Callback { *; }
-keep interface com.chengjianglong.soofunny.core.buddy.LlamaNative$Callback { *; }
