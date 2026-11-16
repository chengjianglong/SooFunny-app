package com.chengjianglong.soofunny.core.voice

import com.chengjianglong.soofunny.core.BookLanguage
import com.chengjianglong.soofunny.core.LearningLanguage
import com.chengjianglong.soofunny.core.Sports
import com.chengjianglong.soofunny.core.StoryLibrary
import com.chengjianglong.soofunny.core.WordDictionary
import com.chengjianglong.soofunny.core.buddy.AssistantPrompts
import com.chengjianglong.soofunny.ui.math.MathOperation
import com.chengjianglong.soofunny.ui.math.MathQuestion
import com.chengjianglong.soofunny.ui.math.MathQuestionMaker
import com.chengjianglong.soofunny.ui.math.NICE_TRY
import com.chengjianglong.soofunny.ui.math.cheers
import com.chengjianglong.soofunny.ui.math.praise
import com.chengjianglong.soofunny.ui.settings.TRY_CHINESE
import com.chengjianglong.soofunny.ui.settings.TRY_ENGLISH
import org.junit.Assume.assumeTrue
import org.junit.Test
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Makes the pre-made natural-voice clips ([PremadeVoices]) on a Mac: every phrase of every text
 * SooFunny always reads the same way, in the default English and Chinese voices at normal speed,
 * split exactly as [com.chengjianglong.soofunny.core.Speech] splits it, one AAC file per phrase.
 *
 * Not a normal test: it runs only when asked, from `android/`:
 *
 *     ./gradlew :app:testDebugUnitTest --tests '*PremadeVoiceRenderer*' -PpremadeOut=voices/src/main/assets/premade
 *
 * Needs `scripts/fetch_model.sh` (the Kokoro models in ../Models) and macOS's `afconvert`.
 * Clips already made are kept, so running it again only makes what's new.
 */
class PremadeVoiceRenderer {
    private val repo = File("../..")

    /** Every text read aloud that's always the same, in each language setting. */
    private fun texts(): Set<String> {
        val words = WordDictionary.parse(File(repo, "SooFunny/Words/kids_words.txt").readText())
        val sports = Sports.parse(File("src/main/assets/data/sports.json").readText())
        val books = StoryLibrary.parse(File("src/main/assets/data/books.json").readText())
        val questions = MathOperation.entries.flatMap { op ->
            (0..12).flatMap { f -> (0..12).flatMap { n -> listOf(true, false).map { MathQuestionMaker.make(op, f, n, it) } } }
        }.toSet()

        val out = linkedSetOf<String>()
        out += listOf(TRY_ENGLISH, TRY_CHINESE)
        out += NaturalVoices.COMMON_PHRASES + NaturalVoices.COMMON_CHINESE_PHRASES
        out += ('a'..'z').map { it.toString() }
        for (category in words) for (word in category.words) {
            out += word.text.filter { it.isLetter() }.map { it.lowercaseChar().toString() }
            word.chinese?.let { zh -> out += zh.filter { it.isLetter() }.map { it.toString() } }
        }
        for (lang in LearningLanguage.entries) {
            for (category in words) {
                out += lang.spoken(category.name, category.chinese)
                for (word in category.words) {
                    out += lang.spoken(word.text, word.chinese)
                    out += buddyQuestion(word.text, word.chinese, lang)
                }
            }
            for (sport in sports) {
                out += lang.spoken(sport.english, sport.chinese)
                out += when (lang) {
                    LearningLanguage.ENGLISH -> sport.aboutEnglish
                    LearningLanguage.CHINESE -> sport.aboutChinese
                    LearningLanguage.BOTH -> sport.aboutEnglish + "\n\n" + sport.aboutChinese
                }
                out += buddyQuestion(sport.english, sport.chinese, lang)
            }
            for (book in StoryLibrary.shelf(books, lang)) out += book.pages.indices.map { book.pageText(it, lang) }
            out += cheers.map { lang.spoken(it.first, it.second) }
            out += (0..3).map { praise(it).let { p -> lang.spoken(p.first, p.second) } }
            for (q in questions) {
                out += q.spokenQuestion(lang)
                out += lang.spoken(NICE_TRY.first, NICE_TRY.second) + " " + q.spokenAnswer(lang)
            }
        }
        return out
    }

    /** The buddy's question after its introduction (a word with no Chinese is talked about in English). */
    private fun buddyQuestion(word: String, chinese: String?, lang: LearningLanguage) =
        AssistantPrompts.introductionQuestion(word, if (chinese == null) LearningLanguage.ENGLISH else lang, chinese)

    @Test
    fun render() {
        val target = System.getProperty("soofunny.premadeOut")
        assumeTrue("Run with -PpremadeOut=<folder> to make the clips", target != null)
        val out = File(target!!).let { if (it.isAbsolute) it else File("..", target) }.apply { mkdirs() }

        // Each phrase once, in the language it's read in.
        val pieces = sortedSetOf<Pair<BookLanguage, String>>(compareBy({ it.first }, { it.second }))
        for (text in texts()) for (run in BookLanguage.spokenRuns(text)) {
            for (piece in Kokoro.pieces(run.text)) if (piece.text.any { it.isLetterOrDigit() }) pieces += run.language to piece.text
        }
        val todo = pieces.map { (language, text) ->
            val key = PremadeVoices.key(language, PremadeVoices.VOICES.getValue(language), PremadeVoices.SPEED, text)
            Triple(language, text, key)
        }
        println("Pre-made voices: ${todo.size} phrases (${todo.count { it.first == BookLanguage.CHINESE }} Chinese)")

        val models = File(repo, "Models")
        val data = File(repo, "SooFunny/Voice/Resources")
        // Several voices side by side, each on two cores, keep a many-core Mac busy without
        // the threads fighting over cores.
        val workers = (Runtime.getRuntime().availableProcessors() / 2 - 1).coerceIn(1, 7)
        val pool = Executors.newFixedThreadPool(workers)
        val voices = ThreadLocal.withInitial {
            mapOf(
                BookLanguage.ENGLISH to KokoroTTS.createFromFiles(data, File(models, "kokoro-82m-q8.onnx"), BookLanguage.ENGLISH, PremadeVoices.VOICES.getValue(BookLanguage.ENGLISH)),
                BookLanguage.CHINESE to KokoroTTS.createFromFiles(data, File(models, "kokoro-v1.1-zh-fp16.onnx"), BookLanguage.CHINESE, PremadeVoices.VOICES.getValue(BookLanguage.CHINESE)),
            )
        }
        val done = AtomicInteger()
        val made = AtomicInteger()
        val failed = java.util.Collections.synchronizedList(mutableListOf<String>())
        val tmp = File(System.getProperty("java.io.tmpdir"), "soofunny-premade").apply { mkdirs() }
        for ((language, text, key) in todo) pool.execute {
            val file = File(out, PremadeVoices.fileName(key))
            try {
                if (!file.isFile || file.length() == 0L) {
                    val samples = Kokoro.trimmingSilence(voices.get().getValue(language).synthesize(text, PremadeVoices.SPEED))
                    if (samples.isEmpty()) {
                        failed += "$key (silent)"
                    } else {
                        val wav = File(tmp, file.nameWithoutExtension + ".wav")
                        writeWav(wav, samples)
                        val partial = File(out, file.name + ".part.m4a")
                        val p = ProcessBuilder("afconvert", "-f", "m4af", "-d", "aac", "-b", "40000", wav.path, partial.path)
                            .redirectErrorStream(true).start()
                        val log = p.inputStream.bufferedReader().readText()
                        if (p.waitFor() != 0 || !partial.renameTo(file)) failed += "$key ($log)"
                        wav.delete()
                        made.incrementAndGet()
                    }
                }
            } catch (e: Throwable) {
                failed += "$key ($e)"
            }
            val n = done.incrementAndGet()
            if (n % 250 == 0) println("  $n / ${todo.size}")
        }
        pool.shutdown()
        pool.awaitTermination(6, TimeUnit.HOURS)

        // The list the app reads: phrase key, tab, file name. Clips no longer needed are removed.
        val ok = todo.filter { File(out, PremadeVoices.fileName(it.third)).isFile }
        File(out, File(PremadeVoices.INDEX).name).writeText(ok.joinToString("") { "${it.third}\t${PremadeVoices.fileName(it.third)}\n" })
        val keep = ok.map { PremadeVoices.fileName(it.third) }.toSet() + File(PremadeVoices.INDEX).name
        out.listFiles().orEmpty().filter { it.name !in keep }.forEach { it.delete() }
        val bytes = out.listFiles().orEmpty().sumOf { it.length() }
        println("Pre-made voices: made ${made.get()}, ${ok.size} in all, ${bytes / 1_000_000} MB, ${failed.size} failed")
        failed.take(20).forEach { println("  failed: $it") }
    }

    private fun writeWav(file: File, samples: FloatArray) {
        val data = ByteBuffer.allocate(samples.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (s in samples) data.putShort((s.coerceIn(-1f, 1f) * 32767f).toInt().toShort())
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray()); putInt(36 + data.capacity()); put("WAVE".toByteArray())
            put("fmt ".toByteArray()); putInt(16); putShort(1); putShort(1); putInt(Kokoro.SAMPLE_RATE)
            putInt(Kokoro.SAMPLE_RATE * 2); putShort(2); putShort(16)
            put("data".toByteArray()); putInt(data.capacity())
        }
        RandomAccessFile(file, "rw").use { it.setLength(0); it.write(header.array()); it.write(data.array()) }
    }
}
