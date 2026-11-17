package com.chengjianglong.soofunny.ui.settings

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chengjianglong.soofunny.core.TipJar
import com.chengjianglong.soofunny.ui.SooTopBar
import com.chengjianglong.soofunny.ui.language

/**
 * The tips, straight away, as on iOS. Google Play's own purchase sheet confirms the payment, so
 * there's no extra grown-up check.
 */
@Composable
fun SupportScreen(onClose: () -> Unit) {
    val context = LocalContext.current
    val lang = language
    DisposableEffect(Unit) {
        TipJar.load(context)
        onDispose { TipJar.close() }
    }
    val thanked = TipJar.thanked
    Column(Modifier.fillMaxSize().background(Color(0xFFF2F2F7)).statusBarsPadding().navigationBarsPadding()) {
        SooTopBar(title = "", onBack = onClose, backLabel = lang.pick("Close", "关闭"))
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Column(Modifier.widthIn(max = 520.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Text(if (thanked) "💛" else "💖", fontSize = 64.sp)
                Text(
                    if (thanked) lang.pick("Thank you!", "谢谢你！", "\n") else lang.pick("Support SooFunny", "支持 SooFunny", "\n"),
                    style = TextStyle(brush = Brush.linearGradient(listOf(Color(0xFFFF2D55), Color(0xFFFF9500), Color(0xFFAF52DE)))),
                    fontSize = 34.sp, fontWeight = FontWeight.Black, textAlign = TextAlign.Center,
                )
                Text(
                    if (thanked) lang.pick("Your tip helps keep SooFunny maintained and growing, free for every family.",
                        "你的打赏帮助 SooFunny 持续维护和成长，让每个家庭都能免费使用。", "\n\n")
                    else lang.pick("SooFunny is free for everyone, with no ads and no tracking. If your family enjoys it, a tip helps keep it maintained and add new things to learn.",
                        "SooFunny 对所有人免费，没有广告，也不追踪。如果你的家人喜欢它，打赏可以帮助我们维护应用、增加新的学习内容。", "\n\n"),
                    color = Color.Gray, fontSize = 17.sp, textAlign = TextAlign.Center,
                )
                if (TipJar.offline) {
                    Text("📡 " + lang.pick("Tips need an internet connection. Please try again when you're online.", "打赏需要连接网络，请联网后再试。", "\n"),
                        color = Color(0xFFFF9500), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
                }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    TipJar.products.forEach { product ->
                        val emoji = listOf("☕️", "🍰", "🎁").getOrElse(TipJar.tipIDs.indexOf(product.productId)) { "💖" }
                        val price = product.oneTimePurchaseOfferDetails?.formattedPrice.orEmpty()
                        Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(Color.White)
                                .clickable { context.findActivity()?.let { TipJar.buy(it, product) } }.padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Text(emoji, fontSize = 36.sp)
                            Column(Modifier.weight(1f)) {
                                Text(product.name, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                                Text(product.description, fontSize = 14.sp, color = Color.Gray)
                            }
                            Text(price, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = Color.White,
                                modifier = Modifier.clip(RoundedCornerShape(50)).background(Color(0xFF007AFF)).padding(horizontal = 14.dp, vertical = 7.dp))
                        }
                    }
                }
                Text(lang.pick("Tips are optional, one-time payments. They don't unlock anything: every feature is already free.",
                    "打赏是自愿的一次性付款，不会解锁任何内容：所有功能本来就免费。", "\n"),
                    color = Color.Gray, fontSize = 13.sp, textAlign = TextAlign.Center)
            }
        }
    }
}

internal tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
