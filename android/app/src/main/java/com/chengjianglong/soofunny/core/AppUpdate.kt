package com.chengjianglong.soofunny.core

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import androidx.core.content.pm.PackageInfoCompat
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import com.google.android.play.core.ktx.requestAppUpdateInfo

/**
 * "A new SooFunny is ready!": the Android version of the iOS app's `AppUpdateChecker`.
 *
 * When the app opens or comes back to the front, at most every 6 hours, it asks Google Play
 * (through the Play Store app on the phone) whether a newer version is out. Nothing about the
 * child is sent. If there is one, [available] is set and the reminder is shown; "Not now" hides
 * that version for 3 days ([UpdatePolicy]). Updating is behind the grown-up check and uses Play's
 * own full-screen update, or opens SooFunny in the Play Store when Play can't update in the app.
 */
object AppUpdate {
    private const val LAST_CHECK = "updateLastCheck"
    private const val SNOOZED_VERSION = "updateSnoozedVersion"
    private const val SNOOZED_UNTIL = "updateSnoozedUntil"

    /** The newer version to offer, or null. */
    var available by mutableStateOf<AppUpdateInfo?>(null)
        private set

    private var manager: AppUpdateManager? = null
    private var checking = false

    private fun manager(context: Context) =
        manager ?: AppUpdateManagerFactory.create(context.applicationContext).also { manager = it }

    /** Call from the Activity's onResume. Finishes an update a grown-up already started, else checks if due. */
    suspend fun onResume(activity: Activity, launcher: ActivityResultLauncher<IntentSenderRequest>, now: Long = System.currentTimeMillis()) {
        if (checking) return
        checking = true
        try {
            val prefs = AppSettings.prefs()
            val lastCheck = prefs.getLong(LAST_CHECK, -1L).takeIf { it >= 0 }
            val due = UpdatePolicy.isCheckDue(lastCheck, now)
            val info = runCatching { manager(activity).requestAppUpdateInfo() }
                .onFailure { Log.i("AppUpdate", "Google Play couldn't be asked: ${it.message}") }
                .getOrNull() ?: return
            // An update the grown-up started and left: Play asks for it to be shown again.
            if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                startPlayUpdate(activity, info, launcher)
                return
            }
            if (!due) return
            prefs.edit { putLong(LAST_CHECK, now) }
            val offer = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE &&
                UpdatePolicy.shouldOffer(
                    available = info.availableVersionCode(),
                    installed = installedVersion(activity),
                    snoozedVersion = prefs.getInt(SNOOZED_VERSION, -1).takeIf { it >= 0 },
                    snoozedUntil = prefs.getLong(SNOOZED_UNTIL, -1L).takeIf { it >= 0 },
                    now = now,
                )
            available = if (offer) info else null
        } finally {
            checking = false
        }
    }

    /** "Not now": hides this version for 3 days. */
    fun snooze(now: Long = System.currentTimeMillis()) {
        val info = available ?: return
        val (version, until) = UpdatePolicy.snooze(info.availableVersionCode(), now)
        AppSettings.prefs().edit { putInt(SNOOZED_VERSION, version); putLong(SNOOZED_UNTIL, until) }
        available = null
    }

    /** "Update", after the grown-up check. */
    fun update(activity: Activity, launcher: ActivityResultLauncher<IntentSenderRequest>) {
        val info = available ?: return
        available = null
        if (!startPlayUpdate(activity, info, launcher)) openPlayStore(activity)
    }

    private fun startPlayUpdate(activity: Activity, info: AppUpdateInfo, launcher: ActivityResultLauncher<IntentSenderRequest>): Boolean {
        if (!info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) return false
        return runCatching {
            manager(activity).startUpdateFlowForResult(info, launcher, AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE))
        }.getOrDefault(false)
    }

    private fun openPlayStore(activity: Activity) {
        val id = activity.packageName
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$id")))
        } catch (_: ActivityNotFoundException) {
            runCatching { activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$id"))) }
        }
    }

    private fun installedVersion(context: Context): Int = runCatching {
        PackageInfoCompat.getLongVersionCode(context.packageManager.getPackageInfo(context.packageName, 0)).toInt()
    }.getOrDefault(Int.MAX_VALUE)
}
