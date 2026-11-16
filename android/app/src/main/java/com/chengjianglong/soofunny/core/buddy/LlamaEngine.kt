package com.chengjianglong.soofunny.core.buddy

import android.os.Build
import java.io.Closeable
import java.io.File
import java.util.concurrent.CancellationException

/** Something that turns a prompt into streamed text. [LlamaEngine] in the app; fakes in tests. */
interface LanguageEngine {
    /**
     * Generates a reply, calling [onText] with each new piece, and returns the full text.
     * Throws [CancellationException] once [isCancelled] returns true. Blocks: call it off the main thread.
     */
    fun generate(prompt: String, maxTokens: Int, isCancelled: () -> Boolean, onText: (String) -> Unit): String

    /** Reads [prompt] ahead of time, so a later prompt that starts with it starts sooner. */
    fun prepare(prompt: String) {}
}

/** Why the buddy's brain couldn't answer. The screen shows [message] in the conversation's language. */
class EngineException(val kind: Kind, val code: Int = 0) : Exception(kind.name) {
    enum class Kind { UNSUPPORTED_DEVICE, MODEL_MISSING, LOAD_FAILED, PROMPT_TOO_LONG, DECODE_FAILED }

    fun message(pick: (String, String) -> String): String = when (kind) {
        Kind.UNSUPPORTED_DEVICE -> pick(
            "The talking buddy needs a newer phone or tablet than this one.",
            "这台设备太旧了，小伙伴没法在上面说话。")
        Kind.MODEL_MISSING -> pick(
            "The talking buddy's brain hasn't been downloaded yet.",
            "小伙伴的“大脑”还没有下载。")
        Kind.LOAD_FAILED -> pick(
            "The talking buddy couldn't start. Close other apps and try again.",
            "小伙伴没能启动。请关掉其他应用再试一次。")
        Kind.PROMPT_TOO_LONG -> pick(
            "That conversation got too long. Tap Back and start again.",
            "这次聊得太长了。请点“返回”重新开始。")
        Kind.DECODE_FAILED -> pick(
            "The talking buddy got confused (error $code). Please try again.",
            "小伙伴糊涂了（错误 $code）。请再试一次。")
    }
}

/** The JNI functions in src/main/cpp/llama_jni.cpp. */
internal object LlamaNative {
    interface Callback {
        fun isCancelled(): Boolean
        fun onPiece(bytes: ByteArray)
    }

    external fun load(path: String, contextSize: Int, batchSize: Int, threads: Int): Long
    external fun generate(handle: Long, prompt: String, maxTokens: Int, callback: Callback, outError: IntArray): Int
    external fun free(handle: Long)

    const val OK = 0
    const val CANCELLED = 1
    const val PROMPT_TOO_LONG = -1
    const val TOKENIZE_FAILED = -2
}

/**
 * Qwen 2.5 1.5B Instruct (4-bit GGUF), downloaded once ([com.chengjianglong.soofunny.core.BuddyModel])
 * and run on the device's CPU with llama.cpp. It talks well in both English and Chinese. Nothing
 * the child says leaves the device. A port of `LlamaEngine.swift`.
 *
 * Not thread-safe: call it from one thread ([WordBuddy] uses a single worker thread).
 */
class LlamaEngine private constructor(private var handle: Long) : LanguageEngine, Closeable {
    companion object {
        const val CONTEXT_SIZE = 2048
        const val BATCH_SIZE = 512

        @Volatile private var libraryLoaded = false

        /** Loads the model (a few seconds). Blocking: call it off the main thread. */
        fun load(model: File): LlamaEngine {
            if (!model.isFile) throw EngineException(EngineException.Kind.MODEL_MISSING)
            loadLibrary()
            val threads = threadCount()
            val handle = LlamaNative.load(model.absolutePath, CONTEXT_SIZE, BATCH_SIZE, threads)
            if (handle == 0L) throw EngineException(EngineException.Kind.LOAD_FAILED)
            return LlamaEngine(handle)
        }

        /**
         * All cores but two (left for the UI and speech), at most six. On an eight-core phone with
         * two fast and six slow cores (Unisoc T606) six threads read a prompt 2.5× as fast as four;
         * eight are slower again.
         */
        private fun threadCount() = (Runtime.getRuntime().availableProcessors() - 2).coerceIn(1, 6)

        @Synchronized
        private fun loadLibrary() {
            if (libraryLoaded) return
            // The library is built for CPUs with these features; on older ones it would crash.
            if (!cpuIsSupported()) throw EngineException(EngineException.Kind.UNSUPPORTED_DEVICE)
            try {
                System.loadLibrary("soofunny_llama")
            } catch (_: UnsatisfiedLinkError) {
                throw EngineException(EngineException.Kind.UNSUPPORTED_DEVICE) // e.g. a 32-bit phone
            }
            libraryLoaded = true
        }

        /** arm64 needs the dot-product and half-precision instructions; x86_64 needs AVX2 and FMA. */
        private fun cpuIsSupported(): Boolean {
            val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: return false
            val info = runCatching { File("/proc/cpuinfo").readText() }.getOrNull() ?: return true
            val features = info.lineSequence()
                .filter { it.startsWith("Features") || it.startsWith("flags") }
                .flatMap { it.substringAfter(':').trim().split(' ').asSequence() }
                .toSet()
            if (features.isEmpty()) return true // can't tell: try anyway
            return when (abi) {
                "arm64-v8a" -> "asimddp" in features && "asimdhp" in features
                "x86_64" -> listOf("avx2", "fma", "f16c").all { it in features }
                else -> false
            }
        }
    }

    override fun generate(prompt: String, maxTokens: Int, isCancelled: () -> Boolean, onText: (String) -> Unit): String {
        val text = StringBuilder()
        val callback = object : LlamaNative.Callback {
            override fun isCancelled() = isCancelled()
            override fun onPiece(bytes: ByteArray) {
                val piece = String(bytes, Charsets.UTF_8)
                text.append(piece)
                onText(piece)
            }
        }
        val error = IntArray(1)
        val status = synchronized(this) {
            check(handle != 0L) { "engine closed" }
            LlamaNative.generate(handle, prompt, maxTokens, callback, error)
        }
        return when (status) {
            LlamaNative.OK -> text.toString()
            LlamaNative.CANCELLED -> throw CancellationException("cancelled")
            LlamaNative.PROMPT_TOO_LONG -> throw EngineException(EngineException.Kind.PROMPT_TOO_LONG)
            LlamaNative.TOKENIZE_FAILED -> throw EngineException(EngineException.Kind.DECODE_FAILED, -2)
            else -> throw EngineException(EngineException.Kind.DECODE_FAILED, error[0])
        }
    }

    override fun prepare(prompt: String) {
        runCatching { generate(prompt, 0, { false }) {} }
    }

    @Synchronized
    override fun close() {
        if (handle != 0L) LlamaNative.free(handle)
        handle = 0L
    }
}
