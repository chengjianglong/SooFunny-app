package com.chengjianglong.soofunny.ui.sports

import androidx.compose.ui.graphics.Color
import com.chengjianglong.soofunny.ui.KidColors

/** The animated demo for each sport, by sport id: a scene and the actors moving through it. Ported from the iOS app's SportDemos.swift. */
object SportDemos {
    fun demo(id: String): SportDemo? = all[id]

    // Shorthands so each demo reads like a little script.
    private fun k(t: Double, x: Double, y: Double, turn: Double = 0.0) = DemoKey(t, x, y, turn)
    private fun vis(from: Double, to: Double) = from to to
    private fun pt(x: Double, y: Double) = x to y
    private fun rgb(r: Double, g: Double, b: Double) = Color(r.toFloat(), g.toFloat(), b.toFloat())
    private fun e(
        emoji: String, keys: List<DemoKey>, size: Double = 0.2, face: DemoFacing? = null, mirrored: Boolean = false,
        bob: Double = 0.0, bobs: Double = 6.0, visible: Pair<Double, Double> = 0.0 to 1.0, smooth: Boolean = true,
    ) = DemoActor(DemoGlyph.Emoji(emoji), DemoMotion(keys, smooth, visible.first, visible.second), size, face, mirrored, bob, bobs)
    private fun ball(color: Color, keys: List<DemoKey>, size: Double = 0.05, visible: Pair<Double, Double> = 0.0 to 1.0, smooth: Boolean = true) =
        DemoActor(DemoGlyph.Ball(color, size), DemoMotion(keys, smooth, visible.first, visible.second))
    private fun still(
        emoji: String, x: Double, y: Double, size: Double = 0.2, mirrored: Boolean = false,
        visible: Pair<Double, Double> = 0.0 to 1.0, bob: Double = 0.0, bobs: Double = 6.0,
    ) = e(emoji, listOf(k(0.0, x, y)), size = size, mirrored = mirrored, bob = bob, bobs = bobs, visible = visible)
    private fun beam(color: Color, from: Pair<Double, Double>, to: Pair<Double, Double>, visible: Pair<Double, Double>) =
        DemoActor(DemoGlyph.Beam(color, to.first, to.second), DemoMotion(listOf(k(0.0, from.first, from.second)), true, visible.first, visible.second))
    private fun arrow(keys: List<DemoKey>, visible: Pair<Double, Double> = 0.0 to 1.0) =
        DemoActor(DemoGlyph.Arrow, DemoMotion(keys, true, visible.first, visible.second))

    val all: Map<String, SportDemo> by lazy { mapOf(
        // Summer
        "swimming" to SportDemo(DemoScene.Pool(lanes = true), duration = 6.0, actors = listOf(
            e("🏊", listOf(k(0.0, 0.92, 0.15), k(0.8, 0.1, 0.15), k(1.0, 0.1, 0.15)), size = 0.17, face = DemoFacing.LEFT, bob = 0.015, bobs = 16.0),
            e("🏊‍♀️", listOf(k(0.0, 0.92, 0.39), k(0.9, 0.12, 0.39), k(1.0, 0.1, 0.39)), size = 0.17, face = DemoFacing.LEFT, bob = 0.015, bobs = 16.0),
            e("🏊", listOf(k(0.0, 0.92, 0.62), k(1.0, 0.16, 0.62)), size = 0.17, face = DemoFacing.LEFT, bob = 0.015, bobs = 16.0),
            e("🏊‍♀️", listOf(k(0.0, 0.92, 0.86), k(0.95, 0.12, 0.86), k(1.0, 0.1, 0.86)), size = 0.17, face = DemoFacing.LEFT, bob = 0.015, bobs = 16.0),
            still("🥇", 0.18, 0.06, size = 0.1, visible = vis(0.8, 1.0)),
        )),
        "diving" to SportDemo(DemoScene.DivingPool, duration = 4.0, actors = listOf(
            e("🤸", listOf(k(0.0, 0.22, 0.12), k(0.2, 0.25, 0.12), k(0.35, 0.36, 0.02, 200.0), k(0.6, 0.5, 0.62, 720.0), k(0.72, 0.52, 0.95, 720.0)),
              size = 0.16, visible = vis(0.0, 0.72)),
            still("💦", 0.5, 0.6, size = 0.18, visible = vis(0.6, 0.85)),
            still("🔟", 0.85, 0.15, size = 0.12, visible = vis(0.75, 1.0)),
        )),
        "artistic-swimming" to SportDemo(DemoScene.Pool(lanes = false), duration = 6.0, actors = listOf(
            e("💃", ovalKeys(cx = 0.5, cy = 0.55, rx = 0.25, ry = 0.22, from = 0.0), size = 0.16, bob = 0.03, bobs = 6.0),
            e("💃", ovalKeys(cx = 0.5, cy = 0.55, rx = 0.25, ry = 0.22, from = 120.0), size = 0.16, bob = 0.03, bobs = 6.0),
            e("💃", ovalKeys(cx = 0.5, cy = 0.55, rx = 0.25, ry = 0.22, from = 240.0), size = 0.16, bob = 0.03, bobs = 6.0),
            e("🤸", listOf(k(0.0, 0.5, 0.6), k(0.4, 0.5, 0.6), k(0.55, 0.5, 0.18, 360.0), k(0.7, 0.5, 0.6, 360.0)), size = 0.16, visible = vis(0.35, 0.75)),
            e("🎵", listOf(k(0.0, 0.1, 0.4), k(1.0, 0.2, 0.05)), size = 0.1),
            e("🎶", listOf(k(0.0, 0.85, 0.45), k(1.0, 0.78, 0.08)), size = 0.1),
        )),
        "water-polo" to SportDemo(DemoScene.Pool(lanes = false, goal = true), duration = 4.0, actors = listOf(
            still("🤽", 0.25, 0.6, size = 0.2, bob = 0.02, bobs = 8.0),
            still("🤽", 0.55, 0.38, size = 0.2, bob = 0.02, bobs = 8.0),
            e("🤽", listOf(k(0.0, 0.82, 0.38), k(0.5, 0.82, 0.55), k(1.0, 0.82, 0.38)), size = 0.18, mirrored = true),
            ball(KidColors.Yellow, listOf(k(0.0, 0.29, 0.5), k(0.25, 0.42, 0.18), k(0.4, 0.57, 0.3), k(0.5, 0.57, 0.3), k(0.7, 0.93, 0.4), k(1.0, 0.93, 0.42)), size = 0.07),
            still("🎉", 0.75, 0.15, size = 0.13, visible = vis(0.72, 1.0)),
        )),
        "athletics" to SportDemo(DemoScene.Track(hurdles = listOf(0.35, 0.65)), duration = 5.0, actors = listOf(
            e("🏃", lineKeys(from = pt(0.05, 0.42), to = pt(0.95, 0.42)), size = 0.2, face = DemoFacing.RIGHT, bob = 0.015, bobs = 14.0),
            e("🏃‍♀️", listOf(k(0.0, 0.05, 0.68), k(0.22, 0.27, 0.68), k(0.3, 0.35, 0.5), k(0.38, 0.43, 0.68), k(0.55, 0.57, 0.68),
                       k(0.63, 0.65, 0.5), k(0.71, 0.73, 0.68), k(1.0, 0.92, 0.68)), size = 0.2, face = DemoFacing.RIGHT),
            e("🏃", lineKeys(from = pt(0.05, 0.92), to = pt(0.88, 0.92)), size = 0.2, face = DemoFacing.RIGHT, bob = 0.015, bobs = 14.0),
        )),
        "archery" to SportDemo(DemoScene.Range(), duration = 3.0, actors = listOf(
            still("🏹", 0.12, 0.5, size = 0.28),
            arrow(listOf(k(0.0, 0.2, 0.48), k(0.15, 0.2, 0.48), k(0.4, 0.55, 0.36), k(0.55, 0.85, 0.45), k(1.0, 0.85, 0.45)), visible = vis(0.1, 0.95)),
            still("✨", 0.86, 0.22, size = 0.12, visible = vis(0.55, 0.95)),
        )),
        "badminton" to SportDemo(DemoScene.Court(rgb(0.2, 0.6, 0.35), floor = rgb(0.8, 0.6, 0.45), netHeight = 0.35), duration = 3.0, actors = listOf(
            e("🏸", listOf(k(0.0, 0.15, 0.5, -30.0), k(0.5, 0.18, 0.62, 0.0), k(1.0, 0.15, 0.5, -30.0)), size = 0.2, mirrored = true),
            e("🏸", listOf(k(0.0, 0.85, 0.62, 0.0), k(0.5, 0.82, 0.5, 30.0), k(1.0, 0.85, 0.62, 0.0)), size = 0.2),
            ball(Color.White, listOf(k(0.0, 0.22, 0.45), k(0.25, 0.5, 0.08), k(0.5, 0.78, 0.45), k(0.75, 0.5, 0.08), k(1.0, 0.22, 0.45)), size = 0.05),
        )),
        "basketball" to SportDemo(DemoScene.Basketball, duration = 4.0, actors = listOf(
            e("⛹️", listOf(k(0.0, 0.25, 0.68), k(0.4, 0.3, 0.68), k(0.5, 0.3, 0.6), k(0.6, 0.3, 0.68), k(1.0, 0.25, 0.68)), size = 0.28),
            e("🏀", listOf(k(0.0, 0.33, 0.62), k(0.1, 0.33, 0.85), k(0.2, 0.33, 0.62), k(0.3, 0.33, 0.85), k(0.42, 0.34, 0.5),
                    k(0.58, 0.62, 0.05), k(0.72, 0.87, 0.3), k(0.82, 0.87, 0.58), k(0.92, 0.85, 0.85), k(1.0, 0.85, 0.85)),
              size = 0.1, smooth = false),
            still("🎉", 0.7, 0.15, size = 0.13, visible = vis(0.72, 1.0)),
            still("3️⃣", 0.12, 0.15, size = 0.11, visible = vis(0.72, 1.0)),
        )),
        "boxing" to SportDemo(DemoScene.Ring, duration = 2.4, actors = listOf(
            e("🥊", listOf(k(0.0, 0.3, 0.55), k(0.2, 0.44, 0.52), k(0.35, 0.3, 0.55), k(1.0, 0.3, 0.55)), size = 0.22, mirrored = true),
            e("🥊", listOf(k(0.0, 0.7, 0.55), k(0.5, 0.7, 0.55), k(0.7, 0.56, 0.5), k(0.85, 0.7, 0.55), k(1.0, 0.7, 0.55)), size = 0.22),
            still("💥", 0.5, 0.45, size = 0.14, visible = vis(0.15, 0.3)),
            still("💥", 0.5, 0.45, size = 0.14, visible = vis(0.65, 0.8)),
        )),
        "breaking" to SportDemo(DemoScene.Stage, duration = 5.0, actors = listOf(
            e("🕺", listOf(k(0.0, 0.3, 0.65), k(0.3, 0.5, 0.65, 0.0), k(0.45, 0.5, 0.65, 720.0), k(0.6, 0.5, 0.7, 900.0), k(0.85, 0.5, 0.7, 900.0), k(1.0, 0.3, 0.65, 1080.0)), size = 0.3),
            e("🎵", listOf(k(0.0, 0.12, 0.5), k(1.0, 0.18, 0.08)), size = 0.1),
            e("🎶", listOf(k(0.0, 0.85, 0.5), k(1.0, 0.8, 0.1)), size = 0.1),
            still("⭐", 0.5, 0.25, size = 0.12, visible = vis(0.62, 0.85)),
        )),
        "canoeing" to SportDemo(DemoScene.River, duration = 6.0, actors = listOf(
            e("🛶", listOf(k(0.0, 0.02, 0.55), k(0.2, 0.25, 0.6), k(0.32, 0.35, 0.35), k(0.45, 0.45, 0.65), k(0.58, 0.6, 0.35),
                    k(0.72, 0.72, 0.65), k(0.85, 0.85, 0.35), k(1.0, 1.02, 0.5)), size = 0.18),
        )),
        "cycling" to SportDemo(DemoScene.Road, duration = 5.0, actors = listOf(
            e("🚴", lineKeys(from = pt(0.0, 0.7), to = pt(1.0, 0.7)), size = 0.24, face = DemoFacing.LEFT, bob = 0.008, bobs = 20.0),
            e("🚴‍♀️", lineKeys(from = pt(-0.15, 0.82), to = pt(0.9, 0.82)), size = 0.24, face = DemoFacing.LEFT, bob = 0.008, bobs = 20.0),
        )),
        "equestrian" to SportDemo(DemoScene.Equestrian(fences = listOf(0.38, 0.72)), duration = 5.0, actors = listOf(
            e("🏇", listOf(k(0.0, 0.02, 0.72), k(0.25, 0.28, 0.72), k(0.33, 0.38, 0.48), k(0.41, 0.48, 0.72), k(0.58, 0.62, 0.72),
                    k(0.66, 0.72, 0.48), k(0.74, 0.82, 0.72), k(1.0, 1.02, 0.72)), size = 0.24, face = DemoFacing.LEFT),
        )),
        "fencing" to SportDemo(DemoScene.Piste, duration = 2.6, actors = listOf(
            e("🤺", listOf(k(0.0, 0.3, 0.6), k(0.25, 0.42, 0.6), k(0.35, 0.3, 0.6), k(0.6, 0.3, 0.6), k(0.7, 0.26, 0.6), k(1.0, 0.3, 0.6)), size = 0.3, mirrored = true),
            e("🤺", listOf(k(0.0, 0.7, 0.6), k(0.25, 0.74, 0.6), k(0.5, 0.7, 0.6), k(0.65, 0.58, 0.6), k(0.8, 0.7, 0.6), k(1.0, 0.7, 0.6)), size = 0.3),
            still("🟢", 0.09, 0.145, size = 0.1, visible = vis(0.22, 0.42)),
            still("🔴", 0.91, 0.145, size = 0.1, visible = vis(0.62, 0.82)),
        )),
        "football" to SportDemo(DemoScene.Field(rgb(0.3, 0.65, 0.3)), duration = 5.0, actors = listOf(
            e("🏃", listOf(k(0.0, 0.1, 0.55), k(0.6, 0.62, 0.5), k(0.75, 0.66, 0.5), k(1.0, 0.66, 0.5)), size = 0.22, face = DemoFacing.RIGHT, bob = 0.012, bobs = 12.0),
            e("⚽", listOf(k(0.0, 0.16, 0.62, 0.0), k(0.6, 0.7, 0.58, 1080.0), k(0.78, 0.96, 0.45, 1500.0), k(1.0, 0.96, 0.47, 1500.0)), size = 0.08),
            e("🧤", listOf(k(0.0, 0.93, 0.5), k(0.3, 0.93, 0.42), k(0.6, 0.93, 0.58), k(0.8, 0.93, 0.6), k(1.0, 0.93, 0.5)), size = 0.12),
            still("🎉", 0.78, 0.15, size = 0.14, visible = vis(0.78, 1.0)),
        )),
        "golf" to SportDemo(DemoScene.Golf, duration = 4.5, actors = listOf(
            e("🏌️", listOf(k(0.0, 0.14, 0.62, 0.0), k(0.15, 0.14, 0.62, -15.0), k(0.22, 0.14, 0.62, 10.0), k(1.0, 0.14, 0.62, 0.0)), size = 0.3),
            ball(Color.White, listOf(k(0.0, 0.22, 0.75), k(0.2, 0.22, 0.75), k(0.45, 0.5, 0.08), k(0.65, 0.76, 0.66), k(0.72, 0.8, 0.6),
                          k(0.8, 0.84, 0.665), k(0.9, 0.86, 0.665), k(1.0, 0.86, 0.665)), size = 0.035, visible = vis(0.0, 0.9)),
            still("🎉", 0.7, 0.2, size = 0.13, visible = vis(0.85, 1.0)),
        )),
        "gymnastics" to SportDemo(DemoScene.Beam, duration = 4.0, actors = listOf(
            e("🤸", listOf(k(0.0, 0.15, 0.47, 0.0), k(0.3, 0.38, 0.47, 360.0), k(0.5, 0.5, 0.25, 540.0), k(0.7, 0.62, 0.47, 720.0), k(1.0, 0.85, 0.47, 1080.0)), size = 0.2),
            still("✨", 0.5, 0.12, size = 0.12, visible = vis(0.4, 0.65)),
        )),
        "handball" to SportDemo(DemoScene.Field(rgb(0.25, 0.5, 0.85)), duration = 4.0, actors = listOf(
            e("🤾", listOf(k(0.0, 0.15, 0.6), k(0.4, 0.55, 0.6), k(0.55, 0.68, 0.35), k(0.7, 0.75, 0.55), k(1.0, 0.75, 0.6)), size = 0.24, face = DemoFacing.LEFT),
            ball(KidColors.Yellow, listOf(k(0.0, 0.2, 0.55), k(0.4, 0.6, 0.55), k(0.55, 0.72, 0.28), k(0.7, 0.96, 0.48), k(1.0, 0.96, 0.52)), size = 0.06),
            still("🧤", 0.92, 0.6, size = 0.1),
            still("🎉", 0.8, 0.15, size = 0.14, visible = vis(0.72, 1.0)),
        )),
        "hockey" to SportDemo(DemoScene.Field(rgb(0.2, 0.45, 0.75)), duration = 4.0, actors = listOf(
            e("🏑", listOf(k(0.0, 0.12, 0.55, 0.0), k(0.5, 0.6, 0.55, 0.0), k(0.6, 0.62, 0.52, -40.0), k(0.68, 0.64, 0.55, 10.0), k(1.0, 0.64, 0.55, 0.0)), size = 0.2),
            ball(Color.White, listOf(k(0.0, 0.2, 0.62), k(0.5, 0.68, 0.62), k(0.7, 0.97, 0.5), k(1.0, 0.97, 0.52)), size = 0.04),
            still("🎉", 0.8, 0.15, size = 0.14, visible = vis(0.72, 1.0)),
        )),
        "judo" to SportDemo(DemoScene.Mat(rgb(0.95, 0.8, 0.2), edge = rgb(0.2, 0.4, 0.8)), duration = 4.0, actors = listOf(
            e("🥋", listOf(k(0.0, 0.32, 0.5), k(0.3, 0.44, 0.5), k(1.0, 0.44, 0.5)), size = 0.28),
            e("🥋", listOf(k(0.0, 0.68, 0.5, 0.0), k(0.3, 0.56, 0.5, 0.0), k(0.45, 0.48, 0.15, 120.0), k(0.6, 0.3, 0.62, 270.0), k(1.0, 0.3, 0.62, 270.0)), size = 0.28),
            still("⭐", 0.5, 0.12, size = 0.12, visible = vis(0.62, 1.0)),
        )),
        "modern-pentathlon" to SportDemo(DemoScene.Pentathlon, duration = 6.0, actors = listOf(
            still("🤺", 0.12, 0.15, size = 0.12), still("🏊", 0.28, 0.15, size = 0.12),
            still("🎯", 0.44, 0.15, size = 0.12), still("🏃", 0.6, 0.15, size = 0.12),
            e("🏃", listOf(k(0.0, 0.05, 0.75), k(0.35, 0.5, 0.75), k(0.55, 0.5, 0.75), k(1.0, 0.98, 0.75)), size = 0.2, face = DemoFacing.RIGHT),
            beam(KidColors.Red, from = pt(0.53, 0.68), to = pt(0.66, 0.48), visible = vis(0.38, 0.42)),
            beam(KidColors.Red, from = pt(0.53, 0.68), to = pt(0.71, 0.48), visible = vis(0.43, 0.47)),
            beam(KidColors.Red, from = pt(0.53, 0.68), to = pt(0.75, 0.48), visible = vis(0.48, 0.52)),
            still("✅", 0.72, 0.32, size = 0.1, visible = vis(0.5, 0.6)),
        )),
        "rowing" to SportDemo(DemoScene.Sea(), duration = 6.0, actors = listOf(
            e("🚣", lineKeys(from = pt(0.02, 0.62), to = pt(1.02, 0.62)), size = 0.2, bob = 0.01, bobs = 12.0),
            e("🚣‍♀️", lineKeys(from = pt(-0.08, 0.85), to = pt(0.92, 0.85)), size = 0.2, bob = 0.01, bobs = 12.0),
        )),
        "rugby-sevens" to SportDemo(DemoScene.Rugby, duration = 5.0, actors = listOf(
            e("🏃", listOf(k(0.0, 0.15, 0.4), k(0.35, 0.45, 0.4), k(0.5, 0.52, 0.35), k(1.0, 0.58, 0.32)), size = 0.2, face = DemoFacing.RIGHT),
            e("🏃‍♀️", listOf(k(0.0, 0.05, 0.7), k(0.35, 0.35, 0.68), k(0.7, 0.8, 0.6), k(0.8, 0.9, 0.62, 70.0), k(1.0, 0.9, 0.62, 70.0)), size = 0.2, face = DemoFacing.RIGHT),
            e("🏉", listOf(k(0.0, 0.2, 0.45, 20.0), k(0.35, 0.5, 0.45, 20.0), k(0.45, 0.42, 0.55, 300.0), k(0.5, 0.42, 0.63, 380.0), k(0.7, 0.84, 0.62, 380.0), k(0.8, 0.94, 0.68, 400.0), k(1.0, 0.94, 0.68, 400.0)),
              size = 0.08),
            still("🎉", 0.7, 0.12, size = 0.14, visible = vis(0.8, 1.0)),
        )),
        "sailing" to SportDemo(DemoScene.Sea(buoys = true), duration = 8.0, actors = listOf(
            e("⛵", listOf(k(0.0, 0.15, 0.75, -5.0), k(0.25, 0.35, 0.56, 5.0), k(0.5, 0.82, 0.58, -5.0), k(0.75, 0.6, 0.92, 5.0), k(1.0, 0.15, 0.75, -5.0)), size = 0.22),
            e("💨", listOf(k(0.0, 0.05, 0.3), k(1.0, 0.4, 0.3)), size = 0.12),
        )),
        "shooting" to SportDemo(DemoScene.Range(rings = false), duration = 3.0, actors = listOf(
            ball(KidColors.Orange, listOf(k(0.0, 0.95, 0.6), k(0.35, 0.65, 0.15), k(0.45, 0.58, 0.12)), size = 0.06, visible = vis(0.0, 0.45)),
            beam(KidColors.Yellow, from = pt(0.05, 0.8), to = pt(0.58, 0.12), visible = vis(0.42, 0.48)),
            still("💥", 0.58, 0.12, size = 0.16, visible = vis(0.45, 0.7)),
            still("✅", 0.5, 0.35, size = 0.1, visible = vis(0.5, 0.8)),
        )),
        "skateboarding" to SportDemo(DemoScene.Skatepark, duration = 4.0, actors = listOf(
            e("🛹", listOf(k(0.0, 0.06, 0.32, 70.0), k(0.15, 0.2, 0.78, 25.0), k(0.3, 0.5, 0.82, 0.0), k(0.45, 0.8, 0.78, -25.0), k(0.5, 0.94, 0.35, -70.0),
                    k(0.55, 0.96, 0.12, -250.0), k(0.6, 0.94, 0.32, -430.0), k(0.75, 0.6, 0.82, -360.0), k(1.0, 0.06, 0.32, -290.0)), size = 0.14),
            still("✨", 0.9, 0.08, size = 0.1, visible = vis(0.52, 0.65)),
        )),
        "sport-climbing" to SportDemo(DemoScene.ClimbingWall, duration = 6.0, actors = listOf(
            e("🧗", listOf(k(0.0, 0.3, 0.85), k(0.15, 0.42, 0.72), k(0.3, 0.28, 0.6), k(0.45, 0.4, 0.48), k(0.6, 0.3, 0.36),
                    k(0.75, 0.44, 0.24), k(0.9, 0.34, 0.13), k(1.0, 0.34, 0.13)), size = 0.18),
            e("🧗", listOf(k(0.0, 0.72, 0.85), k(0.3, 0.72, 0.12), k(1.0, 0.72, 0.12)), size = 0.18),
            still("⏱️", 0.88, 0.12, size = 0.12, visible = vis(0.3, 1.0)),
        )),
        "surfing" to SportDemo(DemoScene.Sea(wave = true), duration = 5.0, actors = listOf(
            e("🏄", listOf(k(0.0, 0.1, 0.72, 0.0), k(0.25, 0.35, 0.6, -20.0), k(0.45, 0.55, 0.32, -40.0), k(0.6, 0.66, 0.4, 30.0),
                    k(0.8, 0.8, 0.62, 10.0), k(1.0, 1.0, 0.72, 0.0)), size = 0.22, face = DemoFacing.RIGHT),
            still("💦", 0.62, 0.28, size = 0.12, visible = vis(0.45, 0.62)),
        )),
        "table-tennis" to SportDemo(DemoScene.TableTennis, duration = 2.0, actors = listOf(
            e("🏓", listOf(k(0.0, 0.08, 0.5), k(0.5, 0.1, 0.55), k(1.0, 0.08, 0.5)), size = 0.16, mirrored = true),
            e("🏓", listOf(k(0.0, 0.92, 0.55), k(0.5, 0.9, 0.5), k(1.0, 0.92, 0.55)), size = 0.16),
            ball(Color.White, listOf(k(0.0, 0.14, 0.5), k(0.25, 0.38, 0.6), k(0.5, 0.86, 0.48), k(0.75, 0.62, 0.6), k(1.0, 0.14, 0.5)), size = 0.035, smooth = false),
        )),
        "taekwondo" to SportDemo(DemoScene.Mat(rgb(0.25, 0.45, 0.9), edge = rgb(0.9, 0.3, 0.3)), duration = 3.0, actors = listOf(
            still("🥋", 0.35, 0.5, size = 0.28),
            still("🥋", 0.68, 0.5, size = 0.28),
            e("🦵", listOf(k(0.0, 0.38, 0.62, 0.0), k(0.3, 0.38, 0.62, 0.0), k(0.45, 0.5, 0.35, -80.0), k(0.6, 0.38, 0.62, 0.0), k(1.0, 0.38, 0.62, 0.0)), size = 0.2,
              visible = vis(0.3, 0.62)),
            still("💥", 0.6, 0.3, size = 0.14, visible = vis(0.42, 0.58)),
        )),
        "tennis" to SportDemo(DemoScene.Court(rgb(0.25, 0.45, 0.75), floor = rgb(0.4, 0.65, 0.4), netHeight = 0.18), duration = 2.6, actors = listOf(
            e("🏃‍♀️", listOf(k(0.0, 0.12, 0.62), k(0.5, 0.15, 0.7), k(1.0, 0.12, 0.62)), size = 0.22, face = DemoFacing.RIGHT, mirrored = false),
            e("🏃", listOf(k(0.0, 0.88, 0.7), k(0.5, 0.85, 0.62), k(1.0, 0.88, 0.7)), size = 0.22, mirrored = true),
            e("🎾", listOf(k(0.0, 0.18, 0.55), k(0.18, 0.4, 0.35), k(0.32, 0.68, 0.85), k(0.5, 0.82, 0.58), k(0.68, 0.6, 0.35),
                    k(0.82, 0.3, 0.85), k(1.0, 0.18, 0.55)), size = 0.06),
        )),
        "triathlon" to SportDemo(DemoScene.Triathlon, duration = 7.0, actors = listOf(
            e("🏊‍♀️", lineKeys(from = pt(0.02, 0.75), to = pt(0.32, 0.75), t0 = 0.0, t1 = 0.33), size = 0.17, face = DemoFacing.LEFT, bob = 0.015, bobs = 30.0, visible = vis(0.0, 0.34)),
            e("🚴‍♀️", lineKeys(from = pt(0.34, 0.72), to = pt(0.66, 0.72), t0 = 0.33, t1 = 0.62), size = 0.2, face = DemoFacing.LEFT, visible = vis(0.33, 0.63)),
            e("🏃‍♀️", lineKeys(from = pt(0.68, 0.72), to = pt(0.97, 0.72), t0 = 0.62, t1 = 0.95), size = 0.2, face = DemoFacing.RIGHT, bob = 0.015, bobs = 30.0, visible = vis(0.62, 1.0)),
            still("🏅", 0.9, 0.25, size = 0.14, visible = vis(0.93, 1.0)),
        )),
        "volleyball" to SportDemo(DemoScene.Court(rgb(0.95, 0.6, 0.3), floor = rgb(0.95, 0.85, 0.6), netHeight = 0.45), duration = 3.0, actors = listOf(
            e("🏃‍♀️", listOf(k(0.0, 0.3, 0.72), k(0.25, 0.38, 0.72), k(0.38, 0.4, 0.4), k(0.5, 0.42, 0.72), k(1.0, 0.3, 0.72)), size = 0.22, face = DemoFacing.RIGHT),
            still("🏃", 0.78, 0.72, size = 0.22, mirrored = true),
            e("🏐", listOf(k(0.0, 0.2, 0.3), k(0.2, 0.3, 0.12), k(0.38, 0.42, 0.25), k(0.55, 0.72, 0.85), k(0.62, 0.78, 0.6),
                    k(0.85, 0.5, 0.05), k(1.0, 0.2, 0.3)), size = 0.08),
            still("💥", 0.43, 0.25, size = 0.12, visible = vis(0.36, 0.44)),
        )),
        "weightlifting" to SportDemo(DemoScene.Platform, duration = 3.5, actors = listOf(
            e("🏋️", listOf(k(0.0, 0.5, 0.72), k(0.3, 0.5, 0.72), k(0.45, 0.5, 0.58), k(0.85, 0.5, 0.58), k(1.0, 0.5, 0.72)), size = 0.38),
            still("💪", 0.22, 0.3, size = 0.12, visible = vis(0.5, 0.85)),
            still("✅", 0.78, 0.3, size = 0.12, visible = vis(0.55, 0.85)),
        )),
        "wrestling" to SportDemo(DemoScene.Mat(rgb(0.95, 0.75, 0.3), edge = rgb(0.25, 0.4, 0.75), round = true), duration = 3.0, actors = listOf(
            e("🤼", listOf(k(0.0, 0.45, 0.55, -5.0), k(0.25, 0.55, 0.55, 5.0), k(0.5, 0.45, 0.55, -5.0), k(0.75, 0.55, 0.55, 5.0), k(1.0, 0.45, 0.55, -5.0)), size = 0.4),
        )),

        // Winter
        "alpine-skiing" to SportDemo(DemoScene.Slope(gates = true), duration = 5.0, actors = listOf(
            e("⛷️", listOf(k(0.0, 0.05, 0.12), k(0.2, 0.25, 0.3), k(0.35, 0.36, 0.3), k(0.5, 0.5, 0.48), k(0.65, 0.6, 0.47),
                    k(0.8, 0.74, 0.62), k(1.0, 1.02, 0.7)), size = 0.18, face = DemoFacing.RIGHT),
            e("💨", listOf(k(0.0, 0.0, 0.1), k(1.0, 0.95, 0.66)), size = 0.1),
        )),
        "biathlon" to SportDemo(DemoScene.Biathlon, duration = 7.0, actors = listOf(
            e("⛷️", listOf(k(0.0, 0.02, 0.55), k(0.3, 0.45, 0.55), k(0.7, 0.45, 0.55), k(1.0, 1.02, 0.55)), size = 0.18, face = DemoFacing.RIGHT),
            beam(KidColors.Yellow, from = pt(0.5, 0.5), to = pt(0.74, 0.385), visible = vis(0.35, 0.38)),
            beam(KidColors.Yellow, from = pt(0.5, 0.5), to = pt(0.79, 0.385), visible = vis(0.42, 0.45)),
            beam(KidColors.Yellow, from = pt(0.5, 0.5), to = pt(0.84, 0.385), visible = vis(0.49, 0.52)),
            beam(KidColors.Yellow, from = pt(0.5, 0.5), to = pt(0.88, 0.385), visible = vis(0.56, 0.59)),
            beam(KidColors.Yellow, from = pt(0.5, 0.5), to = pt(0.93, 0.385), visible = vis(0.63, 0.66)),
            still("⚪", 0.74, 0.385, size = 0.06, visible = vis(0.37, 1.0)), still("⚪", 0.79, 0.385, size = 0.06, visible = vis(0.44, 1.0)),
            still("⚪", 0.84, 0.385, size = 0.06, visible = vis(0.51, 1.0)), still("⚪", 0.88, 0.385, size = 0.06, visible = vis(0.58, 1.0)),
            still("⚪", 0.93, 0.385, size = 0.06, visible = vis(0.65, 1.0)),
        )),
        "bobsleigh" to SportDemo(DemoScene.IceChute, duration = 4.0, actors = listOf(
            e("🏃", listOf(k(0.0, 0.0, 0.08), k(0.15, 0.12, 0.07)), size = 0.12, face = DemoFacing.RIGHT, visible = vis(0.0, 0.16)),
            e("🛷", listOf(k(0.0, 0.05, 0.12, 0.0), k(0.15, 0.17, 0.11, 0.0), k(0.35, 0.3, 0.32, 40.0), k(0.55, 0.5, 0.55, 0.0), k(0.75, 0.75, 0.62, 15.0), k(1.0, 1.05, 0.78, 20.0)),
              size = 0.14, face = DemoFacing.LEFT),
            e("💨", listOf(k(0.0, -0.05, 0.12), k(0.15, 0.08, 0.11), k(0.35, 0.22, 0.3), k(0.55, 0.42, 0.55), k(0.75, 0.66, 0.62), k(1.0, 0.96, 0.76)),
              size = 0.1, visible = vis(0.15, 1.0)),
        )),
        "cross-country-skiing" to SportDemo(DemoScene.SnowHills, duration = 7.0, actors = listOf(
            e("⛷️", lineKeys(from = pt(0.0, 0.76), to = pt(1.0, 0.74)), size = 0.18, face = DemoFacing.RIGHT, bob = 0.01, bobs = 20.0),
            e("⛷️", lineKeys(from = pt(-0.15, 0.86), to = pt(0.85, 0.84)), size = 0.18, face = DemoFacing.RIGHT, bob = 0.01, bobs = 20.0),
        )),
        "curling" to SportDemo(DemoScene.Curling, duration = 5.0, actors = listOf(
            e("🥌", listOf(k(0.0, 0.05, 0.5), k(0.2, 0.3, 0.5), k(0.45, 0.6, 0.52), k(0.65, 0.76, 0.51), k(0.8, 0.81, 0.5), k(1.0, 0.81, 0.5)), size = 0.14),
            e("🧹", listOf(k(0.0, 0.38, 0.38, -20.0), k(0.2, 0.38, 0.38, -20.0), k(0.45, 0.68, 0.38, 20.0), k(0.65, 0.8, 0.38, -20.0), k(0.7, 0.8, 0.3, 0.0)),
              size = 0.14, visible = vis(0.15, 0.72)),
            still("🎉", 0.6, 0.12, size = 0.12, visible = vis(0.8, 1.0)),
        )),
        "figure-skating" to SportDemo(DemoScene.Rink(hockey = false), duration = 6.0, actors = listOf(
            e("⛸️", listOf(k(0.0, 0.15, 0.7, 0.0), k(0.25, 0.4, 0.75, 0.0), k(0.4, 0.5, 0.35, 720.0), k(0.55, 0.6, 0.72, 1080.0), k(0.8, 0.85, 0.45, 1080.0), k(1.0, 0.15, 0.7, 1080.0)),
              size = 0.16),
            still("✨", 0.5, 0.2, size = 0.12, visible = vis(0.35, 0.55)),
            e("🎵", listOf(k(0.0, 0.1, 0.3), k(1.0, 0.2, 0.05)), size = 0.1),
        )),
        "freestyle-skiing" to SportDemo(DemoScene.Kicker, duration = 4.0, actors = listOf(
            e("⛷️", listOf(k(0.0, 0.02, 0.3, 0.0), k(0.3, 0.32, 0.6, 0.0), k(0.38, 0.44, 0.55, -20.0), k(0.5, 0.55, 0.15, -200.0), k(0.65, 0.68, 0.62, -360.0),
                    k(1.0, 1.0, 0.85, -360.0)), size = 0.16, face = DemoFacing.RIGHT),
            still("⭐", 0.55, 0.06, size = 0.1, visible = vis(0.45, 0.65)),
        )),
        "ice-hockey" to SportDemo(DemoScene.Rink(hockey = true), duration = 4.0, actors = listOf(
            e("🏒", listOf(k(0.0, 0.15, 0.48, 0.0), k(0.5, 0.62, 0.48, 0.0), k(0.6, 0.64, 0.45, 40.0), k(0.68, 0.66, 0.48, -10.0), k(1.0, 0.66, 0.48, 0.0)), size = 0.2,
              mirrored = true),
            ball(Color.Black, listOf(k(0.0, 0.22, 0.56), k(0.5, 0.7, 0.56), k(0.7, 0.92, 0.5), k(1.0, 0.92, 0.51)), size = 0.04),
            still("🚨", 0.9, 0.25, size = 0.12, visible = vis(0.7, 1.0)),
        )),
        "luge" to SportDemo(DemoScene.IceChute, duration = 4.0, actors = listOf(
            e("🛷", listOf(k(0.0, 0.0, 0.12, 0.0), k(0.25, 0.3, 0.32, 40.0), k(0.5, 0.5, 0.55, 0.0), k(0.75, 0.75, 0.62, 15.0), k(1.0, 1.05, 0.78, 20.0)), size = 0.13, face = DemoFacing.LEFT),
            e("🙂", listOf(k(0.0, 0.02, 0.09, 0.0), k(0.25, 0.32, 0.28, 40.0), k(0.5, 0.52, 0.51, 0.0), k(0.75, 0.77, 0.58, 15.0), k(1.0, 1.07, 0.74, 20.0)), size = 0.07),
        )),
        "nordic-combined" to SportDemo(DemoScene.SkiJump, duration = 7.0, actors = listOf(
            e("⛷️", listOf(k(0.0, 0.02, 0.06, 30.0), k(0.12, 0.2, 0.36, 10.0), k(0.18, 0.33, 0.42, -10.0), k(0.32, 0.55, 0.38, -20.0), k(0.42, 0.66, 0.84, 10.0),
                    k(0.5, 0.75, 0.92, 0.0)), size = 0.15, face = DemoFacing.RIGHT, visible = vis(0.0, 0.5)),
            e("⛷️", lineKeys(from = pt(0.0, 0.92), to = pt(0.98, 0.92), t0 = 0.5, t1 = 1.0), size = 0.15, face = DemoFacing.RIGHT, bob = 0.01, bobs = 30.0, visible = vis(0.5, 1.0)),
            still("🦅", 0.55, 0.2, size = 0.1, visible = vis(0.15, 0.4)),
        )),
        "short-track" to SportDemo(DemoScene.Oval(small = true), duration = 4.0, actors = listOf(
            e("⛸️", ovalKeys(cx = 0.5, cy = 0.5, rx = 0.3, ry = 0.28, from = 90.0, turns = -1.0, steps = 20), size = 0.12),
            e("⛸️", ovalKeys(cx = 0.5, cy = 0.5, rx = 0.3, ry = 0.28, from = 60.0, turns = -1.0, steps = 20), size = 0.12),
            e("⛸️", ovalKeys(cx = 0.5, cy = 0.5, rx = 0.3, ry = 0.28, from = 30.0, turns = -1.0, steps = 20), size = 0.12),
        )),
        "skeleton" to SportDemo(DemoScene.IceChute, duration = 4.0, actors = listOf(
            e("🛷", listOf(k(0.0, 0.0, 0.12, 0.0), k(0.25, 0.3, 0.32, 40.0), k(0.5, 0.5, 0.55, 0.0), k(0.75, 0.75, 0.62, 15.0), k(1.0, 1.05, 0.78, 20.0)), size = 0.13, face = DemoFacing.LEFT),
            e("⛑️", listOf(k(0.0, 0.06, 0.1, 0.0), k(0.25, 0.35, 0.33, 40.0), k(0.5, 0.56, 0.53, 0.0), k(0.75, 0.81, 0.6, 15.0), k(1.0, 1.11, 0.77, 20.0)), size = 0.07),
        )),
        "ski-jumping" to SportDemo(DemoScene.SkiJump, duration = 5.0, actors = listOf(
            e("⛷️", listOf(k(0.0, 0.02, 0.06, 30.0), k(0.2, 0.2, 0.36, 10.0), k(0.3, 0.33, 0.42, -15.0), k(0.55, 0.58, 0.4, -25.0), k(0.75, 0.72, 0.84, 5.0),
                    k(0.9, 0.88, 0.94, 0.0), k(1.0, 0.95, 0.95, 0.0)), size = 0.15, face = DemoFacing.RIGHT),
            e("🕊️", listOf(k(0.0, 0.6, 0.25), k(1.0, 0.95, 0.15)), size = 0.1, face = DemoFacing.LEFT),
            still("👏", 0.6, 0.6, size = 0.12, visible = vis(0.8, 1.0)),
        )),
        "ski-mountaineering" to SportDemo(DemoScene.Mountain, duration = 8.0, actors = listOf(
            e("⛷️", listOf(k(0.0, 0.15, 0.85), k(0.12, 0.35, 0.72), k(0.24, 0.3, 0.58), k(0.36, 0.45, 0.44), k(0.48, 0.42, 0.3), k(0.58, 0.5, 0.14),
                    k(0.65, 0.52, 0.14), k(0.82, 0.72, 0.55), k(1.0, 0.95, 0.88)), size = 0.14, face = DemoFacing.RIGHT),
            still("⛺", 0.85, 0.85, size = 0.12),
        )),
        "snowboarding" to SportDemo(DemoScene.Halfpipe, duration = 4.0, actors = listOf(
            e("🏂", listOf(k(0.0, 0.06, 0.25, 70.0), k(0.15, 0.22, 0.75, 20.0), k(0.3, 0.5, 0.8, 0.0), k(0.45, 0.78, 0.75, -20.0), k(0.5, 0.94, 0.25, -70.0),
                    k(0.55, 0.96, 0.05, -250.0), k(0.6, 0.94, 0.25, -430.0), k(0.75, 0.6, 0.8, -360.0), k(1.0, 0.06, 0.25, -290.0)), size = 0.16),
            still("✨", 0.9, 0.06, size = 0.1, visible = vis(0.52, 0.65)),
        )),
        "speed-skating" to SportDemo(DemoScene.Oval(small = false), duration = 5.0, actors = listOf(
            e("⛸️", ovalKeys(cx = 0.5, cy = 0.5, rx = 0.38, ry = 0.3, from = 90.0, turns = -1.0, steps = 20), size = 0.12),
            e("⛸️", ovalKeys(cx = 0.5, cy = 0.5, rx = 0.43, ry = 0.36, from = 70.0, turns = -1.0, steps = 20), size = 0.12),
        )),
    ) }
}
