// JNI bridge between core/buddy/LlamaEngine.kt and llama.cpp: load a GGUF model, generate a
// reply token by token (streamed back to Kotlin, with a cancel check), and free it. A port of
// SooFunny/Assistant/LlamaEngine.swift. Not thread-safe: Kotlin calls it from one thread.

#include <jni.h>
#ifdef __ANDROID__
#include <android/log.h>
#else
#include <cstdio>
#endif

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <random>
#include <string>
#include <vector>

#include "llama.h"

namespace {

constexpr const char *TAG = "SooFunnyLlama";

// Status codes returned by nativeGenerate (see LlamaEngine.kt).
constexpr jint OK = 0;
constexpr jint CANCELLED = 1;
constexpr jint PROMPT_TOO_LONG = -1;
constexpr jint TOKENIZE_FAILED = -2;
constexpr jint DECODE_FAILED = -3;

struct Engine {
    llama_model *model = nullptr;
    llama_context *context = nullptr;
    const llama_vocab *vocab = nullptr;
    int32_t contextSize = 2048;
    int32_t batchSize = 512;
    // The tokens now in the context's memory, so a prompt that starts the same way (the same
    // instructions, the conversation so far) only needs its new end read.
    std::vector<llama_token> cached;
};

double millisSince(std::chrono::steady_clock::time_point start) {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
}

void infoLog(const char *format, double a, double b, double c, double d) {
#ifdef __ANDROID__
    __android_log_print(ANDROID_LOG_INFO, TAG, format, a, b, c, d);
#else
    fprintf(stderr, format, a, b, c, d);
    fprintf(stderr, "\n");
#endif
}

void quietLog(ggml_log_level level, const char *text, void *) {
    if (level != GGML_LOG_LEVEL_ERROR) return; // (CONT lines are progress dots)
#ifdef __ANDROID__
    __android_log_print(ANDROID_LOG_ERROR, TAG, "%s", text);
#else
    fprintf(stderr, "%s: %s", TAG, text);
#endif
}

std::vector<llama_token> tokenize(const llama_vocab *vocab, const std::string &text) {
    std::vector<llama_token> tokens(text.size() + 8);
    int32_t count = llama_tokenize(vocab, text.data(), (int32_t) text.size(), tokens.data(),
                                   (int32_t) tokens.size(), true, true);
    if (count < 0 && count != INT32_MIN) {
        tokens.resize(-count);
        count = llama_tokenize(vocab, text.data(), (int32_t) text.size(), tokens.data(),
                               (int32_t) tokens.size(), true, true);
    }
    tokens.resize(std::max(0, count));
    return tokens;
}

void appendPiece(const llama_vocab *vocab, llama_token token, std::string &out) {
    char buffer[64];
    int32_t length = llama_token_to_piece(vocab, token, buffer, sizeof buffer, 0, false);
    if (length >= 0) {
        out.append(buffer, length);
        return;
    }
    std::vector<char> big(-length);
    length = llama_token_to_piece(vocab, token, big.data(), (int32_t) big.size(), 0, false);
    if (length > 0) out.append(big.data(), length);
}

// How many leading bytes of `text` are whole UTF-8 characters; the rest waits for the next token
// (a Chinese character or an emoji can be split across tokens).
size_t completeUtf8Prefix(const std::string &text) {
    size_t i = 0, end = 0;
    while (i < text.size()) {
        auto c = (unsigned char) text[i];
        size_t length = c < 0x80 ? 1 : (c >> 5) == 0x6 ? 2 : (c >> 4) == 0xE ? 3 : (c >> 3) == 0x1E ? 4 : 1;
        if (i + length > text.size()) break;
        i += length;
        end = i;
    }
    return end;
}

llama_sampler *makeSampler(const llama_vocab *vocab) {
    llama_sampler *chain = llama_sampler_chain_init(llama_sampler_chain_default_params());
    // A small model can get stuck saying the same sentence over and over (more so in Chinese).
    llama_sampler_chain_add(chain, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), 64, 1.1f, 0.0f, 0.0f));
    llama_sampler_chain_add(chain, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.9f, 1));
    llama_sampler_chain_add(chain, llama_sampler_init_temp(0.7f));
    llama_sampler_chain_add(chain, llama_sampler_init_dist(std::random_device{}()));
    return chain;
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_chengjianglong_soofunny_core_buddy_LlamaNative_load(JNIEnv *env, jobject, jstring path, jint contextSize,
                                                             jint batchSize, jint threads) {
    static bool initialized = false;
    if (!initialized) {
        llama_log_set(quietLog, nullptr);
        llama_backend_init();
        initialized = true;
    }
    const char *file = env->GetStringUTFChars(path, nullptr);
    llama_model_params modelParams = llama_model_default_params();
    modelParams.n_gpu_layers = 0;
    llama_model *model = llama_model_load_from_file(file, modelParams);
    env->ReleaseStringUTFChars(path, file);
    if (model == nullptr) return 0;

    llama_context_params contextParams = llama_context_default_params();
    contextParams.n_ctx = (uint32_t) contextSize;
    contextParams.n_batch = (uint32_t) batchSize;
    contextParams.n_threads = threads;
    contextParams.n_threads_batch = threads;
    contextParams.no_perf = true;
    llama_context *context = llama_init_from_model(model, contextParams);
    if (context == nullptr) {
        llama_model_free(model);
        return 0;
    }
    auto *engine = new Engine();
    engine->model = model;
    engine->context = context;
    engine->vocab = llama_model_get_vocab(model);
    engine->contextSize = contextSize;
    engine->batchSize = batchSize;
    return reinterpret_cast<jlong>(engine);
}

extern "C" JNIEXPORT void JNICALL
Java_com_chengjianglong_soofunny_core_buddy_LlamaNative_free(JNIEnv *, jobject, jlong handle) {
    auto *engine = reinterpret_cast<Engine *>(handle);
    if (engine == nullptr) return;
    llama_free(engine->context);
    llama_model_free(engine->model);
    delete engine;
}

/**
 * Generates a reply to `prompt` (already in the model's chat format), at most `maxTokens` long.
 * Calls callback.isCancelled() before each step and callback.onPiece(byte[]) with each new piece
 * of UTF-8 text. Returns a status code; `outError` (int[1]) gets llama_decode's code on failure.
 */
extern "C" JNIEXPORT jint JNICALL
Java_com_chengjianglong_soofunny_core_buddy_LlamaNative_generate(JNIEnv *env, jobject, jlong handle, jstring jprompt,
                                                                 jint maxTokens, jobject callback, jintArray outError) {
    auto *engine = reinterpret_cast<Engine *>(handle);
    if (engine == nullptr) return DECODE_FAILED;
    jclass callbackClass = env->GetObjectClass(callback);
    jmethodID isCancelled = env->GetMethodID(callbackClass, "isCancelled", "()Z");
    jmethodID onPiece = env->GetMethodID(callbackClass, "onPiece", "([B)V");
    auto cancelled = [&]() -> bool {
        jboolean result = env->CallBooleanMethod(callback, isCancelled);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            return true;
        }
        return result;
    };
    auto fail = [&](jint code) {
        jint value = code;
        env->SetIntArrayRegion(outError, 0, 1, &value);
        return DECODE_FAILED;
    };

    // The prompt as UTF-8 bytes (GetStringUTFChars gives modified UTF-8, which breaks emojis).
    std::string prompt;
    {
        jclass stringClass = env->FindClass("java/lang/String");
        jmethodID getBytes = env->GetMethodID(stringClass, "getBytes", "(Ljava/lang/String;)[B");
        jstring charset = env->NewStringUTF("UTF-8");
        auto bytes = (jbyteArray) env->CallObjectMethod(jprompt, getBytes, charset);
        jsize length = env->GetArrayLength(bytes);
        prompt.resize(length);
        env->GetByteArrayRegion(bytes, 0, length, reinterpret_cast<jbyte *>(prompt.data()));
        env->DeleteLocalRef(bytes);
        env->DeleteLocalRef(charset);
        env->DeleteLocalRef(stringClass);
    }

    std::vector<llama_token> tokens = tokenize(engine->vocab, prompt);
    if (tokens.empty()) return TOKENIZE_FAILED;
    if ((int32_t) tokens.size() + maxTokens >= engine->contextSize) return PROMPT_TOO_LONG;

    // Keep what's already read of the same beginning; read only the rest. At least the last
    // token is always read again, for its next-token predictions.
    size_t keep = 0;
    while (keep < engine->cached.size() && keep < tokens.size() && engine->cached[keep] == tokens[keep]) keep++;
    keep = std::min(keep, tokens.size() - 1);
    llama_memory_t memory = llama_get_memory(engine->context);
    if (keep == 0 || !llama_memory_seq_rm(memory, 0, (llama_pos) keep, -1)) {
        llama_memory_clear(memory, true);
        keep = 0;
    }
    engine->cached.assign(tokens.begin(), tokens.begin() + (long) keep);

    auto started = std::chrono::steady_clock::now();
    // Read the prompt in batches.
    for (size_t start = keep; start < tokens.size();) {
        if (cancelled()) return CANCELLED;
        auto count = (int32_t) std::min<size_t>(engine->batchSize, tokens.size() - start);
        int32_t status = llama_decode(engine->context, llama_batch_get_one(tokens.data() + start, count));
        if (status != 0) {
            llama_memory_clear(memory, true);
            engine->cached.clear();
            return fail(status);
        }
        engine->cached.insert(engine->cached.end(), tokens.begin() + (long) start, tokens.begin() + (long) (start + count));
        start += count;
    }
    double readMillis = millisSince(started);
    auto generating = std::chrono::steady_clock::now();
    int generated = 0;

    llama_sampler *sampler = makeSampler(engine->vocab);
    std::string pending;  // bytes of a character split across tokens
    jint result = OK;
    for (int i = 0; i < maxTokens; i++) {
        if (cancelled()) {
            result = CANCELLED;
            break;
        }
        llama_token token = llama_sampler_sample(sampler, engine->context, -1);
        if (llama_vocab_is_eog(engine->vocab, token)) break;
        appendPiece(engine->vocab, token, pending);
        size_t ready = completeUtf8Prefix(pending);
        if (ready > 0) {
            jbyteArray piece = env->NewByteArray((jsize) ready);
            env->SetByteArrayRegion(piece, 0, (jsize) ready, reinterpret_cast<const jbyte *>(pending.data()));
            env->CallVoidMethod(callback, onPiece, piece);
            env->DeleteLocalRef(piece);
            pending.erase(0, ready);
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
                result = CANCELLED;
                break;
            }
        }
        int32_t status = llama_decode(engine->context, llama_batch_get_one(&token, 1));
        if (status != 0) {
            llama_memory_clear(memory, true);
            engine->cached.clear();
            result = fail(status);
            break;
        }
        engine->cached.push_back(token);
        generated++;
    }
    llama_sampler_free(sampler);
    infoLog("read %.0f new of %.0f prompt tokens in %.0f ms; %.1f tokens/s writing",
            (double) (tokens.size() - keep), (double) tokens.size(), readMillis,
            generated * 1000.0 / std::max(1.0, millisSince(generating)));
    return result;
}
