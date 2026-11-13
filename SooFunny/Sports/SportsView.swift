import SwiftUI

/// The Sports tab: every sport of the Summer and Winter Olympic Games, each introduced in
/// English and Chinese and read aloud in both languages.
struct SportsView: View {
    @State private var season: SportSeason = .summer
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        BouncyTitle()
                        Text("Discover the Olympic sports!")
                            .font(.title3.weight(.semibold))
                        Text("认识奥运会的运动项目！")
                            .font(.title3.weight(.semibold))
                    }
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                    seasonPicker

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(Array(OlympicSports.sports(season).enumerated()), id: \.element.id) { index, sport in
                            NavigationLink(value: SportRoute(season: season, index: index)) {
                                SportCard(sport: sport, tint: sportTint(index))
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
                        Text("\(option.emoji) \(option.english)").font(.headline)
                        Text("\(option.chinese) · \(OlympicSports.sports(option).count)").font(.subheadline)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 56)
                    .foregroundStyle(selected ? .white : .primary)
                    .background(selected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    .overlay(Capsule().stroke(color.opacity(selected ? 0 : 0.5), lineWidth: 2))
                }
                .buttonStyle(SquishButtonStyle())
                .accessibilityLabel("\(option.english) Games, \(option.chinese)")
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

    var body: some View {
        VStack(spacing: 8) {
            SportPicture(sport: sport, size: 96, tint: tint)
            Text(sport.english)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(sport.chinese)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
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

/// One sport: its picture and names, then what it is in English and in Chinese, each with a
/// button that reads it aloud while the words light up. Previous / Next move through the season.
private struct SportDetail: View {
    let season: SportSeason
    @State private var index: Int
    @State private var reader = ReadAloud()

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
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text(sport.english)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                        SpeakButton(text: sport.english, size: 26)
                    }
                    Button { read(sport.chinese, .chinese) } label: {
                        HStack(spacing: 8) {
                            Text(sport.chinese).font(.system(size: 34, weight: .bold, design: .rounded))
                            Image(systemName: "speaker.wave.2.fill").font(.system(size: 22, weight: .bold))
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("说 \(sport.chinese)")
                }
                .multilineTextAlignment(.center)

                if let demo = SportDemos.demo(for: sport.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Watch it! 看一看！").font(.title3.weight(.heavy)).foregroundStyle(.orange)
                        SportDemoView(demo: demo, label: "Animation of \(sport.english), \(sport.chinese)动画")
                            .id(sport.id)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }

                about(title: "What is it?", text: sport.aboutEnglish, language: .english,
                      button: "Read to me", color: .blue)
                about(title: "这是什么运动？", text: sport.aboutChinese, language: .chinese,
                      button: "读给我听", color: .red)

                HStack(spacing: 16) {
                    Button { move(-1) } label: {
                        Label("Previous", systemImage: "arrow.left").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == 0)
                    Button { move(1) } label: {
                        Label("Next", systemImage: "arrow.right").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(index == sports.count - 1)
                }
                .buttonStyle(.bordered)
                .font(.headline)
                .frame(maxWidth: 520)
                Text("\(index + 1) of \(sports.count) · \(season.english) Games \(season.chinese)奥运会")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(sport.english) · \(sport.chinese)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Speech.shared.speak(sport.english)
            ReadAloud.prefetch(sport.aboutEnglish)
        }
        .onDisappear { reader.stop() }
    }

    private func about(title: String, text: String, language: BookLanguage, button: String, color: Color) -> some View {
        let reading = reader.isReading && reader.text == text
        return VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.heavy)).foregroundStyle(color)
            highlighted(text)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                reading ? reader.stop() : read(text, language)
            } label: {
                Label(reading ? (language == .chinese ? "停" : "Stop") : button,
                      systemImage: reading ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .symbolEffect(.pulse, isActive: reading)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
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

    private func read(_ text: String, _ language: BookLanguage) {
        Speech.shared.stop()
        reader.read(text, language: language)
    }

    private func move(_ step: Int) {
        reader.stop()
        withAnimation(.spring(duration: 0.35)) { index = min(max(0, index + step), sports.count - 1) }
        Speech.shared.speak(sport.english)
        ReadAloud.prefetch(sport.aboutEnglish)
    }
}

private let sportTints: [Color] = [.orange, .pink, .blue, .green, .purple, .teal, .red, .indigo]
private func sportTint(_ index: Int) -> Color { sportTints[index % sportTints.count] }
