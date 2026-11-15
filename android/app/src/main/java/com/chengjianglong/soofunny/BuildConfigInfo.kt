package com.chengjianglong.soofunny

import android.content.Context

object BuildConfigInfo {
    /** "0.1 (1)", from the package. */
    fun versionName(context: Context): String = runCatching {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        "${info.versionName} (${info.longVersionCode})"
    }.getOrDefault("0.1")
}
