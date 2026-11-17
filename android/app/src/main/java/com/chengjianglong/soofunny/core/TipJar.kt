package com.chengjianglong.soofunny.core

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams

/**
 * SooFunny is free, with every feature for everyone. Grown-ups who'd like to help keep it
 * maintained and updated can leave a one-time tip: a consumable in-app product that unlocks
 * nothing, sold through Google Play. The same three tips as on iOS, with the same product IDs.
 *
 * Nothing about the child is sent: Google Play handles the payment, and the app only asks Play
 * for the tips' prices and finishes ("consumes") a tip once it's paid.
 */
object TipJar {
    /** Small, medium and large tips ($1.99, $4.99 and $9.99 in the US, set in Play Console). */
    val tipIDs = listOf(
        "com.chengjianglong.soofunny.tip.small",
        "com.chengjianglong.soofunny.tip.medium",
        "com.chengjianglong.soofunny.tip.large",
    )

    /** The tips as Google Play sells them, in [tipIDs] order; empty until loaded or when offline. */
    var products by mutableStateOf<List<ProductDetails>>(emptyList())
        private set

    /** True when Google Play couldn't be reached or has no tips to sell (SooFunny is often used offline). */
    var offline by mutableStateOf(false)
        private set

    /** True after a tip went through, to say thank you. */
    var thanked by mutableStateOf(false)
        private set

    private var client: BillingClient? = null

    /** Connects to Google Play and loads the tips' prices. Call when the Support screen opens. */
    fun load(context: Context) {
        thanked = false
        val billing = client ?: BillingClient.newBuilder(context.applicationContext)
            .setListener { result, purchases -> onPurchases(result, purchases) }
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .enableAutoServiceReconnection()
            .build()
            .also { client = it }
        if (billing.isReady) {
            queryProducts(billing)
            return
        }
        billing.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                    Log.i("TipJar", "Google Play billing unavailable: ${result.debugMessage}")
                    offline = true
                    return
                }
                queryProducts(billing)
                finishWaitingTips(billing)
            }

            override fun onBillingServiceDisconnected() {}
        })
    }

    /** Opens Google Play's purchase sheet for [product]. */
    fun buy(activity: Activity, product: ProductDetails) {
        val billing = client ?: return
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product).build()))
            .build()
        billing.launchBillingFlow(activity, params)
    }

    /** Disconnects from Google Play when the Support screen closes. */
    fun close() {
        client?.endConnection()
        client = null
    }

    private fun queryProducts(billing: BillingClient) {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(tipIDs.map {
                QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.INAPP).build()
            })
            .build()
        billing.queryProductDetailsAsync(params) { result, details ->
            val found = details.productDetailsList.sortedBy { tipIDs.indexOf(it.productId) }
            if (result.responseCode != BillingClient.BillingResponseCode.OK) Log.i("TipJar", "Couldn't load tips: ${result.debugMessage}")
            products = found
            offline = found.isEmpty()
        }
    }

    /** Tips paid while the app wasn't watching (a pending payment that went through) are finished too. */
    private fun finishWaitingTips(billing: BillingClient) {
        billing.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { _, purchases ->
            purchases.forEach { finish(billing, it, thank = false) }
        }
    }

    private fun onPurchases(result: BillingResult, purchases: List<Purchase>?) {
        val billing = client ?: return
        if (result.responseCode != BillingClient.BillingResponseCode.OK) return
        purchases.orEmpty().forEach { finish(billing, it, thank = true) }
    }

    /** A tip unlocks nothing, so a paid one is consumed straight away (Play refunds it otherwise). */
    private fun finish(billing: BillingClient, purchase: Purchase, thank: Boolean) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        if (purchase.products.none { it in tipIDs }) return
        billing.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()) { consumed, _ ->
            if (consumed.responseCode == BillingClient.BillingResponseCode.OK && thank) thanked = true
        }
    }
}
