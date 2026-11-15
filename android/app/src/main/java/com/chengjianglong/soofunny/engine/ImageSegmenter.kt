package com.chengjianglong.soofunny.engine

import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** How finely a photo is split into blocks. */
enum class SegmentDetail(
    val title: String,
    val chineseTitle: String,
    /** Number of color clusters for the subject (the background gets about half). */
    val clusters: Int,
    /** Neighboring blocks whose colors differ by less than this (CIE ΔE) become one block. */
    val mergeDeltaE: Float,
    /** Blocks smaller than this fraction of the picture are merged into a neighbor. */
    val minAreaFraction: Double,
    val maxRegions: Int,
) {
    BIG("Big", "大块", 5, 18f, 0.008, 30),
    MEDIUM("Medium", "中块", 8, 13f, 0.0035, 90),
    SMALL("Small", "小块", 12, 9f, 0.0012, 220),
}

/** The result of splitting a picture into colorable blocks: a coloring page. */
class Segmentation(
    val width: Int,
    val height: Int,
    /** Block index for every pixel, including pixels under the outlines. */
    val labels: IntArray,
    /** How much of each pixel is covered by black outline, 0..255 (anti-aliased), stored as bytes. */
    val ink: ByteArray,
    val regionCount: Int,
    /** Average original color of each block (ARGB). */
    val meanColors: IntArray,
    /** True when the picture was a black-and-white drawing (coloring page). */
    val isLineArt: Boolean,
) {
    /** The block under a pixel. */
    fun region(x: Int, y: Int): Int? {
        if (x < 0 || y < 0 || x >= width || y >= height) return null
        val label = labels[y * width + x]
        return if (label >= 0) label else null
    }
}

/**
 * Turns any picture into a coloring page, entirely on device. A port of the iOS `ImageSegmenter`.
 *
 * Black-and-white drawings are split along their own lines. Photos go through a sketch pipeline:
 * edge-preserving smoothing, color grouping in a perceptual color space, merging of look-alike
 * neighbors, contour smoothing at a higher resolution, and even anti-aliased outlines.
 * (iOS also separates subject and background with Apple Vision; on Android there is no subject
 * mask, so [segment] is called with `subject = null` for photos.)
 */
class ImageSegmenter(
    /** Drawings keep their own lines at a high resolution. */
    val lineArtMaxDimension: Int = 2048,
    /** Photos are analyzed at this size (blocks are big, so this is plenty)... */
    val photoMaxDimension: Int = 512,
    /** ...and the finished coloring page is drawn at about this size. */
    val outputDimension: Int = 1024,
) {
    fun segment(image: PixelImage, detail: SegmentDetail, subject: BooleanArray? = null): Segmentation =
        if (looksLikeLineArt(image)) lineArt(image) else sketch(image, detail, subject)

    // Drawings

    private fun lineArt(image: PixelImage): Segmentation {
        val n = image.pixelCount
        // Dark pixels are lines; every enclosed light area becomes a block.
        val classes = IntArray(n)
        val ink = ByteArray(n)
        for (i in 0 until n) {
            val lum = Rgb.luminance(image[i])
            if (lum < 0.55) classes[i] = -1
            // Keep the drawing's own anti-aliasing so lines stay smooth.
            ink[i] = (max(0.0, min(1.0, (0.85 - lum) / 0.45)) * 255).toInt().toByte()
        }
        val (labels, initial) = connectedComponents(classes, image.width, image.height)
        // Specks inside thick lines are not worth coloring.
        val minArea = max(6, n / 5000)
        val sizes = IntArray(initial)
        for (l in labels) if (l >= 0) sizes[l]++
        for (i in labels.indices) if (labels[i] >= 0 && sizes[labels[i]] < minArea) labels[i] = -1
        val count = compact(labels)
        // Pixels under the lines belong to the nearest block, so fills reach right up to the ink.
        growIntoUnlabeled(labels, image.width, image.height)
        return Segmentation(image.width, image.height, labels, ink, count,
            meanColors(image, labels, count, 1), isLineArt = true)
    }

    // Photos

    private fun sketch(image: PixelImage, detail: SegmentDetail, subject: BooleanArray?): Segmentation {
        val w = image.width
        val h = image.height
        val n = image.pixelCount

        // 1. Flatten texture and shading while keeping edges.
        val radius = max(2, max(w, h) / 110)
        val lab = LabImage.from(image).kuwahara(radius).kuwahara(radius).kuwahara(radius / 2 + 1)

        // 2–3. Group colors separately for the subject and the background, so the subject
        // gets the detail and the background stays a few big shapes.
        val backgroundClusters = max(3, detail.clusters / 2)
        var classes = IntArray(n)
        if (subject != null) {
            kMeans(lab, (0 until n).filter { subject[it] }.toIntArray(), detail.clusters, 0, classes)
            kMeans(lab, (0 until n).filter { !subject[it] }.toIntArray(), backgroundClusters, detail.clusters, classes)
        } else {
            kMeans(lab, IntArray(n) { it }, detail.clusters, 0, classes)
        }
        val classCount = detail.clusters + (if (subject == null) 0 else backgroundClusters)
        repeat(2) { classes = majorityFiltered(classes, w, h, classCount) }

        // 4. Connected areas, then merge look-alike neighbors and tiny pieces.
        val (labels, components) = connectedComponents(classes, w, h)
        var count = mergeSimilarRegions(labels, components, w, h, lab, subject, detail.mergeDeltaE)
        val minArea = max(4, (n * detail.minAreaFraction).toInt())
        // A small subject still gets its parts: its minimum block size follows its own area.
        val subjectPixels = subject?.count { it } ?: 0
        val subjectMinArea = max(4, min(minArea, (subjectPixels * detail.minAreaFraction * 6).toInt()))
        count = mergeSmallRegions(labels, count, w, h, minArea, detail.maxRegions, subject, subjectMinArea)

        // 5. Round off squiggly borders and thin fingers (each pass works like a little
        // curvature flow), then redraw the shapes at a higher resolution with smooth contours.
        var shaped = labels
        repeat(6) { shaped = modeFiltered(shaped, w, h) }
        val scale = max(1, outputDimension / max(w, h))
        val outW = w * scale
        val outH = h * scale
        var smooth = upscaled(shaped, w, h, scale)
        repeat(2) { smooth = smoothedContours(smooth, outW, outH, 2 * scale + 1) }
        // Smoothing can pinch off crumbs of a block; fold them back into a neighbor.
        val (pieces, pieceCount) = connectedComponents(smooth, outW, outH)
        smooth = pieces
        count = mergeSmallRegions(smooth, pieceCount, outW, outH, max(4, minArea * scale * scale / 2), detail.maxRegions)

        // 6. Even, anti-aliased outlines along every border.
        val ink = outlineInk(smooth, outW, outH, max(1f, max(outW, outH) / 680f))
        return Segmentation(outW, outH, smooth, ink, count, meanColors(image, smooth, count, scale), isLineArt = false)
    }

    companion object {
        /** Mostly-gray pixels and mostly-white background means a coloring page. */
        fun looksLikeLineArt(image: PixelImage): Boolean {
            var gray = 0
            var light = 0
            for (i in 0 until image.pixelCount) {
                val c = image[i]
                val r = Rgb.r(c)
                val g = Rgb.g(c)
                val b = Rgb.b(c)
                if (max(r, max(g, b)) - min(r, min(g, b)) <= 40) gray++
                if (Rgb.luminance(c) > 0.78) light++
            }
            val n = image.pixelCount.toDouble()
            return gray >= 0.95 * n && light >= 0.5 * n
        }

        /** Clusters the Lab colors of [pixels] and writes `offset + cluster` into [classes]. */
        fun kMeans(
            lab: LabImage, pixels: IntArray, requested: Int, offset: Int, classes: IntArray,
            iterations: Int = 12, seed: Long = 0x500FA1L,
        ) {
            if (pixels.isEmpty()) return
            val k = min(requested, pixels.size)
            val stride = max(1, pixels.size / 20_000)
            val sampleCount = (pixels.size + stride - 1) / stride
            val sl = FloatArray(sampleCount)
            val sa = FloatArray(sampleCount)
            val sb = FloatArray(sampleCount)
            for (s in 0 until sampleCount) {
                val p = pixels[s * stride]
                sl[s] = lab.l[p]; sa[s] = lab.a[p]; sb[s] = lab.b[p]
            }

            // k-means++ seeding with a fixed seed so results are repeatable.
            val rng = SplitMix64(seed)
            val cl = FloatArray(k)
            val ca = FloatArray(k)
            val cb = FloatArray(k)
            val first = rng.nextMod(sampleCount)
            cl[0] = sl[first]; ca[0] = sa[first]; cb[0] = sb[first]
            var centers = 1
            val nearest = FloatArray(sampleCount) { d2(sl[it], sa[it], sb[it], cl[0], ca[0], cb[0]) }
            while (centers < k) {
                var total = 0f
                for (d in nearest) total += d
                var pick = rng.nextMod(sampleCount)
                if (total > 0) {
                    var target = (rng.nextMod(1_000_000).toDouble() / 1_000_000).toFloat() * total
                    for (i in nearest.indices) {
                        target -= nearest[i]
                        if (target <= 0) { pick = i; break }
                    }
                }
                cl[centers] = sl[pick]; ca[centers] = sa[pick]; cb[centers] = sb[pick]
                centers++
                for (i in 0 until sampleCount) {
                    nearest[i] = min(nearest[i], d2(sl[i], sa[i], sb[i], sl[pick], sa[pick], sb[pick]))
                }
            }

            val sumL = FloatArray(k)
            val sumA = FloatArray(k)
            val sumB = FloatArray(k)
            val counts = IntArray(k)
            repeat(iterations) {
                sumL.fill(0f); sumA.fill(0f); sumB.fill(0f); counts.fill(0)
                for (s in 0 until sampleCount) {
                    val c = closest(sl[s], sa[s], sb[s], cl, ca, cb)
                    sumL[c] += sl[s]; sumA[c] += sa[s]; sumB[c] += sb[s]
                    counts[c]++
                }
                for (c in 0 until k) if (counts[c] > 0) {
                    cl[c] = sumL[c] / counts[c]; ca[c] = sumA[c] / counts[c]; cb[c] = sumB[c] / counts[c]
                }
            }
            for (i in pixels) classes[i] = offset + closest(lab.l[i], lab.a[i], lab.b[i], cl, ca, cb)
        }

        /**
         * Replaces each pixel's class with the most common class in its 3x3 neighborhood,
         * removing speckles and smoothing block edges.
         */
        fun majorityFiltered(classes: IntArray, width: Int, height: Int, classCount: Int): IntArray {
            val out = classes.copyOf()
            val counts = IntArray(classCount)
            for (y in 0 until height) {
                for (x in 0 until width) {
                    counts.fill(0)
                    for (dy in -1..1) {
                        val ny = min(height - 1, max(0, y + dy))
                        for (dx in -1..1) {
                            val nx = min(width - 1, max(0, x + dx))
                            counts[classes[ny * width + nx]]++
                        }
                    }
                    var best = classes[y * width + x]
                    for (c in counts.indices) if (counts[c] > counts[best]) best = c
                    out[y * width + x] = best
                }
            }
            return out
        }

        /**
         * Like [majorityFiltered], for any number of labels: each pixel takes the label that
         * appears most often among itself and its eight neighbors. Rounds off staircases.
         */
        fun modeFiltered(labels: IntArray, width: Int, height: Int): IntArray {
            val out = labels.copyOf()
            val o = intArrayOf(-width - 1, -width, -width + 1, -1, 1, width - 1, width, width + 1)
            for (y in 1 until max(1, height - 1)) {
                for (x in 1 until max(1, width - 1)) {
                    val i = y * width + x
                    val center = labels[i]
                    var best = center
                    var centerCount = 1
                    for (k in 0 until 8) if (labels[i + o[k]] == center) centerCount++
                    var bestCount = centerCount
                    if (centerCount < 5) {
                        for (k in 0 until 8) {
                            val candidate = labels[i + o[k]]
                            if (candidate == center || candidate == best) continue
                            var count = 0
                            for (m in 0 until 8) if (labels[i + o[m]] == candidate) count++
                            if (count > bestCount) {
                                bestCount = count
                                best = candidate
                            }
                        }
                    }
                    out[i] = best
                }
            }
            return out
        }

        /**
         * Contour smoothing for the finished page: each pixel near a border takes the label
         * with the most Gaussian-weighted votes in a window around it, turning jagged borders
         * into round curves like a drawn line. Pixels deep inside a block are left alone.
         */
        fun smoothedContours(labels: IntArray, width: Int, height: Int, radius: Int): IntArray {
            val step = max(1, radius / 3)
            val sigma = radius / 2f
            // Samples symmetric around the pixel, so straight borders don't drift.
            val reach = radius / step * step
            val odx = ArrayList<Int>()
            val ody = ArrayList<Int>()
            val ow = ArrayList<Float>()
            var dy = -reach
            while (dy <= reach) {
                var dx = -reach
                while (dx <= reach) {
                    if (dx * dx + dy * dy <= radius * radius) {
                        odx += dx; ody += dy
                        ow += exp(-(dx * dx + dy * dy).toFloat() / (2 * sigma * sigma))
                    }
                    dx += step
                }
                dy += step
            }
            val offsetCount = odx.size
            val offX = odx.toIntArray()
            val offY = ody.toIntArray()
            val weights = ow.toFloatArray()
            val out = labels.copyOf()
            val candidates = IntArray(offsetCount)
            val votes = FloatArray(offsetCount)
            val r = radius
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val i = y * width + x
                    val center = labels[i]
                    // Only pixels within reach of a border can change.
                    if (labels[max(0, y - r) * width + x] == center && labels[min(height - 1, y + r) * width + x] == center &&
                        labels[y * width + max(0, x - r)] == center && labels[y * width + min(width - 1, x + r)] == center &&
                        center == labels[max(0, y - r / 2) * width + max(0, x - r / 2)] &&
                        center == labels[min(height - 1, y + r / 2) * width + min(width - 1, x + r / 2)]
                    ) continue
                    var used = 0
                    for (s in 0 until offsetCount) {
                        val nx = min(width - 1, max(0, x + offX[s]))
                        val ny = min(height - 1, max(0, y + offY[s]))
                        val label = labels[ny * width + nx]
                        var k = 0
                        while (k < used && candidates[k] != label) k++
                        if (k == used) {
                            candidates[k] = label
                            votes[k] = 0f
                            used++
                        }
                        votes[k] += weights[s]
                    }
                    var best = 0
                    for (k in 1 until max(1, used)) if (votes[k] > votes[best]) best = k
                    out[i] = candidates[best]
                }
            }
            return out
        }

        /** Groups 4-connected pixels that share a class. Pixels with class -1 get label -1. */
        fun connectedComponents(classes: IntArray, width: Int, height: Int): Pair<IntArray, Int> {
            val labels = IntArray(classes.size) { -1 }
            var next = 0
            var stack = IntArray(1024)
            for (start in classes.indices) {
                if (classes[start] < 0 || labels[start] >= 0) continue
                val cls = classes[start]
                labels[start] = next
                var top = 0
                stack[top++] = start
                while (top > 0) {
                    val i = stack[--top]
                    val x = i % width
                    val y = i / width
                    if (top + 4 > stack.size) stack = stack.copyOf(stack.size * 2)
                    if (x > 0 && labels[i - 1] < 0 && classes[i - 1] == cls) { labels[i - 1] = next; stack[top++] = i - 1 }
                    if (x + 1 < width && labels[i + 1] < 0 && classes[i + 1] == cls) { labels[i + 1] = next; stack[top++] = i + 1 }
                    if (y > 0 && labels[i - width] < 0 && classes[i - width] == cls) { labels[i - width] = next; stack[top++] = i - width }
                    if (y + 1 < height && labels[i + width] < 0 && classes[i + width] == cls) { labels[i + width] = next; stack[top++] = i + width }
                }
                next++
            }
            return labels to next
        }

        /**
         * Joins neighboring blocks whose average colors look alike (ΔE below [threshold]),
         * so gradients such as a sky become one block. Never joins subject and background.
         */
        fun mergeSimilarRegions(
            labels: IntArray, count: Int, width: Int, height: Int,
            lab: LabImage, subject: BooleanArray?, threshold: Float,
        ): Int {
            if (count <= 1) return count
            val sums = FloatArray(count * 3)
            val sizes = IntArray(count)
            val subjectVotes = IntArray(count)
            val pairs = HashSet<Long>()
            val c = count.toLong()
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val i = y * width + x
                    val l = labels[i]
                    sums[l * 3] += lab.l[i]; sums[l * 3 + 1] += lab.a[i]; sums[l * 3 + 2] += lab.b[i]
                    sizes[l]++
                    if (subject != null && subject[i]) subjectVotes[l]++
                    if (x + 1 < width && labels[i + 1] != l) {
                        val m = labels[i + 1]
                        pairs += min(l, m) * c + max(l, m)
                    }
                    if (y + 1 < height && labels[i + width] != l) {
                        val m = labels[i + width]
                        pairs += min(l, m) * c + max(l, m)
                    }
                }
            }
            val means = FloatArray(count * 3) { sums[it] / max(1, sizes[it / 3]) }
            val isSubject = BooleanArray(count) { subjectVotes[it] * 2 > sizes[it] }

            val parent = IntArray(count) { it }
            fun find(v0: Int): Int {
                var v = v0
                while (parent[v] != v) {
                    parent[v] = parent[parent[v]]
                    v = parent[v]
                }
                return v
            }
            fun dist(x: FloatArray, p: Int, y: FloatArray, q: Int): Float {
                val dl = x[p * 3] - y[q * 3]
                val da = x[p * 3 + 1] - y[q * 3 + 1]
                val db = x[p * 3 + 2] - y[q * 3 + 2]
                return sqrt(dl * dl + da * da + db * db)
            }

            class Candidate(val p: Int, val q: Int, val distance: Float, val key: Long)
            val candidates = ArrayList<Candidate>()
            for (key in pairs) {
                val p = (key / c).toInt()
                val q = (key % c).toInt()
                if (subject != null && isSubject[p] != isSubject[q]) continue
                // The background tolerates bigger differences so it stays simple.
                val limit = if (subject != null && !isSubject[p]) threshold * 1.3f else threshold
                val distance = dist(means, p, means, q)
                if (distance < limit) candidates += Candidate(p, q, distance, key)
            }
            candidates.sortWith(compareBy<Candidate> { it.distance }.thenBy { it.key })

            // Merge the closest pairs first. Tiny steps (a smooth gradient such as a sky) always
            // join; bigger steps are checked against the merged blocks' running averages, so a
            // chain of them can't join two clearly different areas (like sky and waterfall).
            val groupSums = sums.copyOf()
            val groupSizes = sizes.copyOf()
            val mp = FloatArray(3)
            val mq = FloatArray(3)
            for (cand in candidates) {
                val rp = find(cand.p)
                val rq = find(cand.q)
                if (rp == rq) continue
                for (j in 0 until 3) {
                    mp[j] = groupSums[rp * 3 + j] / max(1, groupSizes[rp])
                    mq[j] = groupSums[rq * 3 + j] / max(1, groupSizes[rq])
                }
                val limit = if (subject != null && !isSubject[cand.p]) threshold * 1.3f else threshold
                if (!(cand.distance < limit / 2 || dist(mp, 0, mq, 0) < limit)) continue
                parent[rp] = rq
                for (j in 0 until 3) groupSums[rq * 3 + j] += groupSums[rp * 3 + j]
                groupSizes[rq] += groupSizes[rp]
            }
            for (i in labels.indices) labels[i] = find(labels[i])
            return compact(labels)
        }

        /**
         * Repeatedly merges blocks smaller than [initialMinArea] into the neighbor they share the
         * longest border with, growing the minimum until there are at most [maxRegions] blocks.
         * Blocks that are mostly [subject] use [subjectMinArea] instead.
         */
        fun mergeSmallRegions(
            labels: IntArray, initialCount: Int, width: Int, height: Int,
            initialMinArea: Int, maxRegions: Int,
            subject: BooleanArray? = null, subjectMinArea: Int = 0,
        ): Int {
            var count = initialCount
            var minArea = initialMinArea
            var subjectMin = subjectMinArea
            for (iteration in 0 until 60) {
                if (count <= 1) break
                val sizes = IntArray(count)
                val perimeters = IntArray(count)
                val subjectVotes = IntArray(count)
                if (subject != null) {
                    for (i in labels.indices) if (labels[i] >= 0 && subject[i]) subjectVotes[labels[i]]++
                }
                for (y in 0 until height) {
                    for (x in 0 until width) {
                        val i = y * width + x
                        val l = labels[i]
                        if (l < 0) continue
                        sizes[l]++
                        if (x + 1 < width && labels[i + 1] != l) {
                            perimeters[l]++
                            if (labels[i + 1] >= 0) perimeters[labels[i + 1]]++
                        }
                        if (y + 1 < height && labels[i + width] != l) {
                            perimeters[l]++
                            if (labels[i + width] >= 0) perimeters[labels[i + width]]++
                        }
                    }
                }
                // Too small, or a sliver (under ~2px wide) left by soft edges between colors.
                val small = BooleanArray(count) { r ->
                    val limit = if (subject != null && subjectVotes[r] * 2 > sizes[r]) subjectMin else minArea
                    sizes[r] < limit || sizes[r] * 2 < perimeters[r] * 3
                }
                if (!small.any { it }) {
                    if (count <= maxRegions) break
                    minArea = minArea * 3 / 2 + 1
                    subjectMin = subjectMin * 3 / 2 + 1
                    continue
                }

                val borders = arrayOfNulls<HashMap<Int, Int>>(count)
                fun note(a: Int, b: Int) {
                    if (a < 0 || b < 0 || a == b) return
                    if (small[a]) { val m = borders[a] ?: HashMap<Int, Int>().also { borders[a] = it }; m[b] = (m[b] ?: 0) + 1 }
                    if (small[b]) { val m = borders[b] ?: HashMap<Int, Int>().also { borders[b] = it }; m[a] = (m[a] ?: 0) + 1 }
                }
                for (y in 0 until height) {
                    for (x in 0 until width) {
                        val i = y * width + x
                        if (x + 1 < width) note(labels[i], labels[i + 1])
                        if (y + 1 < height) note(labels[i], labels[i + width])
                    }
                }

                val parent = IntArray(count) { it }
                fun find(v0: Int): Int {
                    var v = v0
                    while (parent[v] != v) {
                        parent[v] = parent[parent[v]]
                        v = parent[v]
                    }
                    return v
                }
                var merged = false
                for (a in (0 until count).filter { small[it] }.sortedBy { sizes[it] }) {
                    val border = borders[a] ?: continue
                    // Longest shared border; on a tie, the lower label.
                    var target = -1
                    var targetLength = -1
                    for ((key, length) in border) {
                        if (length > targetLength || (length == targetLength && key < target)) {
                            target = key
                            targetLength = length
                        }
                    }
                    if (target < 0) continue
                    val ra = find(a)
                    val rt = find(target)
                    if (ra != rt) {
                        parent[ra] = rt
                        merged = true
                    }
                }
                if (!merged) break
                for (i in labels.indices) if (labels[i] >= 0) labels[i] = find(labels[i])
                count = compact(labels)
            }
            return count
        }

        /** Renumbers labels to 0 until count, keeping -1 as is. Returns the count. */
        fun compact(labels: IntArray): Int {
            val maxLabel = labels.maxOrNull() ?: return 0
            if (maxLabel < 0) return 0
            val map = IntArray(maxLabel + 1) { -1 }
            var next = 0
            for (i in labels.indices) {
                val l = labels[i]
                if (l < 0) continue
                if (map[l] < 0) map[l] = next++
                labels[i] = map[l]
            }
            return next
        }

        /** Gives every -1 pixel the label of its nearest labeled pixel (breadth-first). */
        fun growIntoUnlabeled(labels: IntArray, width: Int, height: Int) {
            var frontier = labels.indices.filter { labels[it] >= 0 }.toIntArray()
            if (frontier.isEmpty()) return
            while (frontier.isNotEmpty()) {
                val next = IntArray(min(labels.size, frontier.size * 4))
                var size = 0
                for (i in frontier) {
                    val x = i % width
                    val y = i / width
                    if (x > 0 && labels[i - 1] < 0) { labels[i - 1] = labels[i]; next[size++] = i - 1 }
                    if (x + 1 < width && labels[i + 1] < 0) { labels[i + 1] = labels[i]; next[size++] = i + 1 }
                    if (y > 0 && labels[i - width] < 0) { labels[i - width] = labels[i]; next[size++] = i - width }
                    if (y + 1 < height && labels[i + width] < 0) { labels[i + width] = labels[i]; next[size++] = i + width }
                }
                frontier = next.copyOf(size)
            }
        }

        fun upscaled(labels: IntArray, width: Int, height: Int, factor: Int): IntArray {
            if (factor <= 1) return labels
            val outW = width * factor
            val outH = height * factor
            val out = IntArray(outW * outH)
            for (y in 0 until outH) {
                val row = (y / factor) * width
                for (x in 0 until outW) out[y * outW + x] = labels[row + x / factor]
            }
            return out
        }

        /**
         * Outline coverage for every pixel: a line of `2 * halfWidth` pixels centered on each
         * border between blocks, with soft edges, from a chamfer distance transform.
         */
        fun outlineInk(labels: IntArray, width: Int, height: Int, halfWidth: Float): ByteArray {
            val n = width * height
            val d = FloatArray(n) { Float.MAX_VALUE }
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val i = y * width + x
                    val l = labels[i]
                    // Pixel centers next to a border are half a pixel away from it.
                    if ((x + 1 < width && labels[i + 1] != l) || (x > 0 && labels[i - 1] != l) ||
                        (y + 1 < height && labels[i + width] != l) || (y > 0 && labels[i - width] != l)
                    ) d[i] = 0.5f
                }
            }
            val diagonal = 1.4142f
            for (y in 0 until height) {
                for (x in 0 until width) {
                    val i = y * width + x
                    var v = d[i]
                    if (x > 0) v = min(v, d[i - 1] + 1)
                    if (y > 0) {
                        v = min(v, d[i - width] + 1)
                        if (x > 0) v = min(v, d[i - width - 1] + diagonal)
                        if (x + 1 < width) v = min(v, d[i - width + 1] + diagonal)
                    }
                    d[i] = v
                }
            }
            for (y in height - 1 downTo 0) {
                for (x in width - 1 downTo 0) {
                    val i = y * width + x
                    var v = d[i]
                    if (x + 1 < width) v = min(v, d[i + 1] + 1)
                    if (y + 1 < height) {
                        v = min(v, d[i + width] + 1)
                        if (x + 1 < width) v = min(v, d[i + width + 1] + diagonal)
                        if (x > 0) v = min(v, d[i + width - 1] + diagonal)
                    }
                    d[i] = v
                }
            }
            return ByteArray(n) { (max(0f, min(1f, halfWidth + 0.5f - d[it])) * 255).toInt().toByte() }
        }

        /** Average original color of each block. [scale] is how many label pixels span one image pixel. */
        fun meanColors(image: PixelImage, labels: IntArray, count: Int, scale: Int): IntArray {
            val sr = LongArray(count)
            val sg = LongArray(count)
            val sb = LongArray(count)
            val counts = IntArray(count)
            val labelWidth = image.width * scale
            for (i in labels.indices) {
                val l = labels[i]
                if (l < 0) continue
                val c = image[(i / labelWidth / scale) * image.width + (i % labelWidth) / scale]
                sr[l] += Rgb.r(c).toLong(); sg[l] += Rgb.g(c).toLong(); sb[l] += Rgb.b(c).toLong()
                counts[l]++
            }
            return IntArray(count) { r ->
                val n = max(1, counts[r])
                Rgb.of((sr[r] / n).toInt(), (sg[r] / n).toInt(), (sb[r] / n).toInt())
            }
        }

        private fun d2(l1: Float, a1: Float, b1: Float, l2: Float, a2: Float, b2: Float): Float {
            val dl = l1 - l2
            val da = a1 - a2
            val db = b1 - b2
            return dl * dl + da * da + db * db
        }

        private fun closest(l: Float, a: Float, b: Float, cl: FloatArray, ca: FloatArray, cb: FloatArray): Int {
            var best = 0
            var bestDistance = Float.MAX_VALUE
            for (i in cl.indices) {
                val d = d2(l, a, b, cl[i], ca[i], cb[i])
                if (d < bestDistance) {
                    bestDistance = d
                    best = i
                }
            }
            return best
        }
    }
}

/** Paints a coloring page: each block's fill, with the outlines blended on top. */
object ColoringRenderer {
    /** Writes ARGB pixels into [out] (size width * height). */
    fun render(segmentation: Segmentation, fills: IntArray, out: IntArray, outlineColor: Int = Rgb.INK) {
        val n = segmentation.width * segmentation.height
        val ir = Rgb.r(outlineColor)
        val ig = Rgb.g(outlineColor)
        val ib = Rgb.b(outlineColor)
        val labels = segmentation.labels
        val ink = segmentation.ink
        for (i in 0 until n) {
            val label = labels[i]
            val c = if (label >= 0) fills[label] else Rgb.WHITE
            val a = ink[i].toInt() and 0xFF
            val keep = 255 - a
            out[i] = Rgb.of(
                (Rgb.r(c) * keep + ir * a) / 255,
                (Rgb.g(c) * keep + ig * a) / 255,
                (Rgb.b(c) * keep + ib * a) / 255,
            )
        }
    }
}

/** The crayon box. */
object Palette {
    val crayons: IntArray = intArrayOf(
        0xF94144, 0xF3722C, 0xF8961E, 0xF9C74F, 0xFFE66D, 0x90BE6D,
        0x43AA8B, 0x2EC4B6, 0x4CC9F0, 0x277DA1, 0x5E60CE, 0x9B5DE5,
        0xF15BB5, 0xFFAFCC, 0xA0522D, 0xFFD6A5, 0x8D99AE, 0x2B2D42,
    ).map { Rgb.hex(it) }.toIntArray()
}
