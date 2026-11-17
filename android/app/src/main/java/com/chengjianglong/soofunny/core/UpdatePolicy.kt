package com.chengjianglong.soofunny.core

/**
 * When to look for a newer SooFunny and when to offer it, the same rules as the iOS app's
 * `AppUpdateChecker`: Google Play is asked at most every 6 hours, and "Not now" hides the reminder
 * for that version for 3 days. Versions are Play's version codes (whole numbers). Plain Kotlin, so
 * it's tested on the computer.
 */
object UpdatePolicy {
    const val CHECK_INTERVAL_MS = 6 * 60 * 60 * 1000L
    const val SNOOZE_MS = 3 * 24 * 60 * 60 * 1000L

    /** True when the last check was long enough ago (or never happened, or the clock went back). */
    fun isCheckDue(lastCheck: Long?, now: Long): Boolean =
        lastCheck == null || now < lastCheck || now - lastCheck >= CHECK_INTERVAL_MS

    /** True when [available] is newer than [installed] and that version isn't snoozed. */
    fun shouldOffer(available: Int, installed: Int, snoozedVersion: Int?, snoozedUntil: Long?, now: Long): Boolean {
        if (available <= installed) return false
        if (snoozedVersion == available && snoozedUntil != null && now < snoozedUntil) return false
        return true
    }

    /** What "Not now" stores: the version and when the snooze ends. */
    fun snooze(version: Int, now: Long): Pair<Int, Long> = version to now + SNOOZE_MS
}
