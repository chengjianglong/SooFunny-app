package com.chengjianglong.soofunny.core

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * App-wide settings, kept on the device in SharedPreferences and observable from Compose.
 * Call [init] once from the Activity before showing any UI.
 */
object AppSettings {
    private const val LANGUAGE = "learningLanguage"
    private const val SPEECH_RATE = "speechRate"
    const val DEFAULT_SPEECH_RATE = 1.0f

    private var prefs: SharedPreferences? = null

    private var languageState by mutableStateOf(LearningLanguage.ENGLISH)
    private var speechRateState by mutableFloatStateOf(DEFAULT_SPEECH_RATE)

    fun init(context: Context) {
        if (prefs != null) return
        val p = context.applicationContext.getSharedPreferences("soofunny", Context.MODE_PRIVATE)
        prefs = p
        languageState = LearningLanguage.fromKey(p.getString(LANGUAGE, null))
        speechRateState = p.getFloat(SPEECH_RATE, DEFAULT_SPEECH_RATE)
    }

    /** English, 中文 or Bilingual, for every tab. */
    var language: LearningLanguage
        get() = languageState
        set(value) {
            if (value == languageState) return
            languageState = value
            prefs?.edit()?.putString(LANGUAGE, value.key)?.apply()
            Speech.stop()
            com.chengjianglong.soofunny.core.voice.NaturalVoices.languageChanged(value)
        }

    /** Speech speed: 1.0 is normal. */
    var speechRate: Float
        get() = speechRateState
        set(value) {
            speechRateState = value
            prefs?.edit()?.putFloat(SPEECH_RATE, value)?.apply()
        }

    fun resetDefaults() {
        language = LearningLanguage.ENGLISH
        speechRate = DEFAULT_SPEECH_RATE
    }

    /** Small per-feature values (math progress and so on). */
    fun prefs(): SharedPreferences = requireNotNull(prefs) { "AppSettings.init was not called" }
}
