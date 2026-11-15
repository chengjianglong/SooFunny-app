import SwiftUI

/// The Sports tab: 51 summer and winter sports, each introduced in English, Chinese or both
/// (the language switch) and read aloud.
struct SportsView: View {
    @State private var season: SportSeason = .summer
    @State private var showSettings = false
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        BouncyTitle()
                        if language != .chinese {
                            Text("Discover summer and winter sports!")
                                .font(.title3.weight(.semibold))
                        }
                        if language != .english {
                            Text("认识夏季和冬季运动项目！")
                                .font(.title3.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                    seasonPicker

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(Array(OlympicSports.sports(season).enumerated()), id: \.element.id) { index, sport in
                            NavigationLink(value: SportRoute(season: season, index: index)) {
                                SportCard(sport: sport, tint: sportTint(index), language: language)
                            }
                            .buttonStyle(SquishButtonStyle())
                        }
                    }
                }
                .padding([.horizontal, .bottom], 16)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: SportRoute.self) { SportDetail(route: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                ToolbarItem(placement: .topBarLeading) { LanguageSwitch() }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
        .onDisappear { Speech.shared.stop() }
    }

    private var seasonPicker: some View {
        HStack(spacing: 10) {
            ForEach(SportSeason.allCases) { option in
                let selected = option == season
                let color: Color = option == .summer ? .orange : .blue
                Button {
                    withAnimation(.spring(duration: 0.3)) { season = option }
                } label: {
                    VStack(spacing: 0) {
                        let count = OlympicSports.sports(option).count
                        switch language {
                        case .english:
                            Text("\(option.emoji) \(option.english)").font(.headline)
                            Text("\(count) sports").font(.subheadline)
                        case .chinese:
                            Text("\(option.emoji) \(option.chinese)").font(.headline)
                            Text("\(count)项").font(.subheadline)
                        case .both:
                            Text("\(option.emoji) \(option.english)").font(.headline)
                            Text("\(option.chinese) · \(count)").font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 56)
                    .foregroundStyle(selected ? .white : .primary)
                    .background(selected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    .overlay(Capsule().stroke(color.opacity(selected ? 0 : 0.5), lineWidth: 2))
                }
                .buttonStyle(SquishButtonStyle())
                .accessibilityLabel(language.pick("\(option.english) sports", "\(option.chinese)运动"))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

struct SportRoute: Hashable {
    let season: SportSeason
    let index: Int
}

/// A sport in the grid: its picture, English name and Chinese name.
private struct SportCard: View {
    let sport: OlympicSport
    let tint: Color
    let language: LearningLanguage

    var body: some View {
        VStack(spacing: 8) {
            SportPicture(sport: sport, size: 96, tint: tint)
            if language != .chinese {
                Text(sport.english)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            if language != .english {
                Text(sport.chinese)
                    .font(language == .chinese ? .headline : .subheadline.weight(.semibold))
                    .foregroundStyle(language == .chinese ? .primary : .secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 190)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

/// The sport's photo with its emoji as a sticker, or just the emoji on a colored tile.
private struct SportPicture: View {
    let sport: OlympicSport
    let size: CGFloat
    let tint: Color

    var body: some View {
        if let ref = sport.photo, let photo = WordPhotos.image(category: ref.category, word: ref.word) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
                .overlay(alignment: .bottomTrailing) {
                    Text(sport.emoji)
                        .font(.system(size: size * 0.24))
                        .padding(size * 0.04)
                        .background(.white, in: Circle())
                        .offset(x: size * 0.06, y: size * 0.06)
                }
                .accessibilityHidden(true)
        } else {
            Picture(emoji: sport.emoji, word: sport.english, size: size, tint: tint)
        }
    }
}

/// One sport: its picture and names, then what it is in English, in Chinese, or both. The name and
/// then the introduction are read aloud as soon as the page opens, with the words lighting up.
/// Previous / Next move through the season.
private struct SportDetail: View {
    let season: SportSeason
    @State private var index: Int
    @State private var reader = ReadAloud()
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    init(route: SportRoute) {
        season = route.season
        _index = State(initialValue: route.index)
    }

    private var sports: [OlympicSport] { OlympicSports.sports(season) }
    private var sport: OlympicSport { sports[index] }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SportPicture(sport: sport, size: 150, tint: sportTint(index))
                    .id(sport.id)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                // As on a word's page: the name in the chosen language (English above Chinese in
                // Bilingual), with a speaker that plays while it's read and hears it all again.
                HStack(spacing: 8) {
                    WordName(english: sport.english, chinese: sport.chinese, language: language, stacked: true)
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(language == .both ? 4 : 2)
                    Button(action: readAll) {
                        Image(systemName: reader.isReading ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 26, weight: .bold))
                            .symbolEffect(.variableColor.iterative, isActive: reader.isReading)
                            .frame(width: 52, height: 52)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(language.pick("Hear it again", "再听一遍"))
                }
                .multilineTextAlignment(.center)

                if let demo = SportDemos.demo(for: sport.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(language == .both ? "Watch it! 看一看！" : language.pick("Watch it!", "看一看！")).font(.title3.weight(.heavy)).foregroundStyle(.orange)
                        SportDemoView(demo: demo, label: language.pick("Animation of \(sport.english)", "\(sport.chinese)动画"))
                            .id(sport.id)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }

                about(title: aboutTitle, color: language == .chinese ? .red : .blue)

                HStack(spacing: 16) {
                    Button { move(-1) } label: {
                        Label(language.pick("Previous", "上一个"), systemImage: "arrow.left").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == 0)
                    Button { move(1) } label: {
                        Label(language.pick("Next", "下一个"), systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == sports.count - 1)
                }
                .buttonStyle(.bordered)
                .font(.headline)
                .frame(maxWidth: 520)
                Text(language.pick("\(index + 1) of \(sports.count) · \(season.english) sports",
                                   "\(season.chinese)运动：第\(index + 1)个，共\(sports.count)个"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(language.pick(sport.english, sport.chinese))
        .navigationBarTitleDisplayMode(.inline)
        .languageSwitch()
        .onAppear(perform: readAll)
        // Hear it again in the language just picked.
        .onChange(of: language, readAll)
        .onDisappear {
            reader.onPageFinished = nil
            reader.stop()
        }
    }

    /// What the sport is, in the chosen language; in Bilingual, English and then Chinese.
    private var aboutText: String {
        switch language {
        case .english: return sport.aboutEnglish
        case .chinese: return sport.aboutChinese
        case .both: return sport.aboutEnglish + "\n\n" + sport.aboutChinese
        }
    }

    private var aboutTitle: String {
        language == .both ? "What is it? 这是什么运动？" : language.pick("What is it?", "这是什么运动？")
    }

    private func about(title: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.heavy)).foregroundStyle(color)
            highlighted(aboutText)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func highlighted(_ text: String) -> Text {
        var attributed = AttributedString(text)
        if reader.text == text, let range = reader.highlight, let r = Range(range, in: text),
           let lower = AttributedString.Index(r.lowerBound, within: attributed),
           let upper = AttributedString.Index(r.upperBound, within: attributed) {
            attributed[lower..<upper].backgroundColor = .yellow.opacity(0.75)
            attributed[lower..<upper].foregroundColor = .black
        }
        return Text(attributed)
    }

    private func move(_ step: Int) {
        withAnimation(.spring(duration: 0.35)) { index = min(max(0, index + step), sports.count - 1) }
        readAll()
    }

    /// Reads the sport's name and then what it is, with no button to press: in Bilingual, the
    /// English and then the Chinese of each.
    private func readAll() {
        let name = language.spoken(sport.english, sport.chinese)
        let about = aboutText
        let fallback: BookLanguage = language == .chinese ? .chinese : .english
        if language.speaksEnglish { ReadAloud.prefetch(sport.aboutEnglish) }
        reader.onPageFinished = { [reader] in
            reader.onPageFinished = nil
            reader.read(about, language: fallback)
        }
        reader.read(name, language: fallback)
    }
}

private let sportTints: [Color] = [.orange, .pink, .blue, .green, .purple, .teal, .red, .indigo]
private func sportTint(_ index: Int) -> Color { sportTints[index % sportTints.count] }
