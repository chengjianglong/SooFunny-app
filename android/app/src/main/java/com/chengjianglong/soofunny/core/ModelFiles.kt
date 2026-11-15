package com.chengjianglong.soofunny.core

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlin.coroutines.coroutineContext

/**
 * Where the big on-device models are.
 *  - The natural voices ship in the "voices" Play Asset Delivery pack (install-time), read like
 *    normal assets: [ENGLISH_VOICE], [CHINESE_VOICE]. Debug builds made with `-PwithModels=true`
 *    carry them as plain assets instead.
 *  - The talking buddy's model is downloaded the first time it's needed ([BuddyModel]).
 */
object ModelFiles {
    const val ENGLISH_VOICE = "voices/kokoro-82m-q8.onnx"
    const val CHINESE_VOICE = "voices/kokoro-v1.1-zh-fp16.onnx"

    /** Opens a voice model, or null if this install doesn't have it. */
    fun openVoice(context: Context, path: String): InputStream? =
        runCatching { context.assets.open(path) }.getOrNull()

    fun hasVoice(context: Context, path: String): Boolean = openVoice(context, path)?.use { true } ?: false
}

/**
 * The talking buddy's model, Qwen 2.5 1.5B Instruct (4-bit GGUF, 1.1 GB, Apache-2.0): downloaded
 * once from Hugging Face into the app's own files, resumable, and checked against its SHA-256 (the
 * same file and checksum as `scripts/fetch_model.sh`). This download is the only thing the app
 * uses the internet for; no data about the child is sent.
 */
object BuddyModel {
    const val URL = "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
    const val SHA256 = "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"
    const val SIZE = 1_117_320_736L

    sealed interface State {
        data object Missing : State
        data class Downloading(val bytes: Long, val total: Long) : State
        data object Checking : State
        data object Ready : State
        data class Failed(val message: String) : State
    }

    var state by mutableStateOf<State>(State.Missing)
        private set

    fun file(context: Context) = File(context.filesDir, "models/qwen2.5-1.5b-instruct-q4_k_m.gguf")
    private fun part(context: Context) = File(context.filesDir, "models/qwen2.5-1.5b-instruct-q4_k_m.gguf.part")

    /** Whether the model is already on the device (checks the size, not the checksum). */
    fun refresh(context: Context): Boolean {
        val ready = file(context).length() == SIZE
        if (ready) state = State.Ready
        else if (state is State.Ready) state = State.Missing
        return ready
    }

    /** Downloads the model (resuming a partial download), then checks it. Returns the file, or null. */
    suspend fun download(context: Context): File? = withContext(Dispatchers.IO) {
        if (refresh(context)) return@withContext file(context)
        val part = part(context).apply { parentFile?.mkdirs() }
        try {
            var have = part.length().takeIf { it < SIZE } ?: 0L
            val connection = (URL(URL).openConnection() as HttpURLConnection).apply {
                connectTimeout = 20_000
                readTimeout = 60_000
                instanceFollowRedirects = true
                if (have > 0) setRequestProperty("Range", "bytes=$have-")
            }
            val code = connection.responseCode
            if (code == HttpURLConnection.HTTP_OK) have = 0L // server ignored the range: start again
            else if (code != HttpURLConnection.HTTP_PARTIAL) error("HTTP $code")
            RandomAccessFile(part, "rw").use { out ->
                out.setLength(have)
                out.seek(have)
                connection.inputStream.use { input ->
                    val buffer = ByteArray(1 shl 16)
                    var lastReport = 0L
                    state = State.Downloading(have, SIZE)
                    while (true) {
                        coroutineContext.ensureActive()
                        val n = input.read(buffer)
                        if (n < 0) break
                        out.write(buffer, 0, n)
                        have += n
                        if (have - lastReport > (4 shl 20)) {
                            lastReport = have
                            state = State.Downloading(have, SIZE)
                        }
                    }
                }
            }
            state = State.Checking
            if (sha256(part) != SHA256) {
                part.delete()
                error("checksum")
            }
            part.renameTo(file(context))
            state = State.Ready
            file(context)
        } catch (e: kotlinx.coroutines.CancellationException) {
            state = State.Missing
            throw e
        } catch (e: Exception) {
            state = State.Failed(e.message ?: "download failed")
            null
        }
    }

    fun delete(context: Context) {
        file(context).delete()
        part(context).delete()
        state = State.Missing
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(1 shl 20)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}
