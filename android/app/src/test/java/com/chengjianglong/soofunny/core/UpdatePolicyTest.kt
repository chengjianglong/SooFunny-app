package com.chengjianglong.soofunny.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdatePolicyTest {
    private val hour = 60 * 60 * 1000L
    private val day = 24 * hour
    private val now = 1_800_000_000_000L

    @Test fun checksTheFirstTime() = assertTrue(UpdatePolicy.isCheckDue(null, now))

    @Test fun checksAtMostEverySixHours() {
        assertFalse(UpdatePolicy.isCheckDue(now - 5 * hour, now))
        assertTrue(UpdatePolicy.isCheckDue(now - 6 * hour, now))
        assertTrue(UpdatePolicy.isCheckDue(now - 2 * day, now))
    }

    @Test fun checksWhenTheClockWentBack() = assertTrue(UpdatePolicy.isCheckDue(now + hour, now))

    @Test fun offersOnlyANewerVersion() {
        assertTrue(UpdatePolicy.shouldOffer(5, 4, null, null, now))
        assertFalse(UpdatePolicy.shouldOffer(4, 4, null, null, now))
        assertFalse(UpdatePolicy.shouldOffer(3, 4, null, null, now))
    }

    @Test fun notNowHidesThatVersionForThreeDays() {
        val (version, until) = UpdatePolicy.snooze(5, now)
        assertEquals(5, version)
        assertEquals(now + 3 * day, until)
        assertFalse(UpdatePolicy.shouldOffer(5, 4, version, until, now))
        assertFalse(UpdatePolicy.shouldOffer(5, 4, version, until, now + 3 * day - 1))
        assertTrue(UpdatePolicy.shouldOffer(5, 4, version, until, now + 3 * day))
    }

    @Test fun aNewerVersionIsOfferedEvenWhileTheOldOneIsSnoozed() {
        val (version, until) = UpdatePolicy.snooze(5, now)
        assertTrue(UpdatePolicy.shouldOffer(6, 4, version, until, now + day))
    }
}
