/// Each built-in book in its other language, page by page: Chinese for the English books and
/// English for the Chinese ones. With these, every book can be read in English, Chinese or both.
enum StoryTranslations {
    struct Translation {
        let title: String
        let pages: [String]
    }

    static let books: [String: Translation] = [
        "nursery-rhymes": Translation(title: "一闪一闪亮晶晶和好朋友们", pages: [
            "一闪一闪亮晶晶，满天都是小星星。挂在天上放光明，好像许多小眼睛。",
            "矮胖子，坐墙头，栽了一个大跟头。国王的马，国王的兵，谁也没法把他拼回去。",
            "嘿，嘀嗒嘀嗒，小猫拉提琴，奶牛跳过了月亮。小狗看了哈哈笑，盘子和勺子一起逃跑了。",
            "小小蜘蛛爬上了水管。下起雨来，把蜘蛛冲了下来。太阳出来，晒干了雨水，小小蜘蛛又爬上了水管。",
            "咩咩小黑羊，你有羊毛吗？有的，有的，满满三大袋。一袋给主人，一袋给夫人，还有一袋给住在小路尽头的小男孩。",
            "杰克和吉尔上山去打水。杰克摔了一跤，碰破了头，吉尔也跟着滚了下来。",
            "嘀嗒嘀嗒，小老鼠爬上了大钟。钟敲了一下，小老鼠跑下来。嘀嗒嘀嗒。",
        ]),
        "three-little-pigs": Translation(title: "三只小猪", pages: [
            "从前，有三只小猪离开家，要盖自己的房子。",
            "第一只小猪用稻草盖了房子。又快又容易！",
            "第二只小猪用木棍盖了房子。也很快！",
            "第三只小猪用砖头盖了房子。花了很长很长的时间。",
            "来了一只大灰狼。“小猪，小猪，让我进去！”他吹呀吹，把稻草房子吹倒了！",
            "大灰狼对着木棍房子吹呀吹。房子倒了！小猪们跑到了砖头房子里。",
            "大灰狼吹呀吹，吹了又吹。可是砖头房子一点也没有倒。",
            "大灰狼没办法，只好跑走了。三只小猪在砖头房子里又唱又跳，平平安安。",
        ]),
        "good-night-farm": Translation(title: "晚安，农场", pages: [
            "太阳在农场上落下了。该睡觉了。",
            "晚安，奶牛。哞，哞。你也睡个好觉。",
            "晚安，小猪，舒舒服服躺在泥里。哼，哼。",
            "晚安，绵羊，毛茸茸白白的。咩，咩，晚安。",
            "晚安，母鸡，站在鸡窝上。咯咯，咯咯，做个好梦。",
            "月亮升起来了。星星出来了。只有猫头鹰还醒着。呼，呼。",
            "现在轮到你了。晚安，小宝贝。好好睡。",
        ]),
        "goldilocks": Translation(title: "金发姑娘和三只熊", pages: [
            "从前，森林里的一座小房子里住着三只熊：熊爸爸、熊妈妈和熊宝宝。",
            "他们的粥太烫了，所以三只熊出去散步，等粥凉一凉。",
            "一个叫金发姑娘的女孩发现了这座小房子。她敲了敲门，没有人回答，她就走了进去。",
            "她尝了尝粥。这碗太烫了！这碗太凉了！这碗刚刚好！她把粥全吃光了。",
            "她坐了坐椅子。这把太大了！这把也太大了！这把刚刚好！可是咔嚓一声，小椅子坏了。",
            "她试了试床。太硬了！太软了！刚刚好！金发姑娘很快就睡着了。",
            "三只熊回家了。“有人吃了我的粥，”熊宝宝说，“还全吃光了！”",
            "金发姑娘醒来，看见三只熊，一路跑回了家。她再也不随便进陌生人的家了。",
        ]),
        "little-red-hen": Translation(title: "小红母鸡", pages: [
            "小红母鸡找到了一些麦粒。“谁来帮我种麦子？”",
            "“我不帮，”小狗说。“我不帮，”小猫说。“我不帮，”小鸭说。“那我就自己来，”小红母鸡说。她真的自己种了。",
            "麦子长得又高又金黄。“谁来帮我割麦子？”“我不帮，”小狗、小猫和小鸭说。于是她自己割了。",
            "“谁来帮我把麦子送到磨坊？”“我不帮，”大家都说。小红母鸡就自己送去，带回了面粉。",
            "“谁来帮我烤面包？”“我不帮，”小狗、小猫和小鸭说。于是她自己烤了。",
            "面包闻起来又香又暖。“谁来帮我吃面包？”“我来！”小狗、小猫和小鸭说。",
            "“不行，”小红母鸡说。“活都是我干的，所以我和我的小鸡们来吃。”她们吃得一点渣也不剩。",
            "下一次，小狗、小猫和小鸭都来帮忙了。大家一起分享了面包。",
        ]),
        "gingerbread-man": Translation(title: "姜饼人", pages: [
            "一位小老太太烤了一个姜饼人，有葡萄干做的眼睛和糖果做的笑脸。",
            "她一打开烤箱，姜饼人就跳出来跑走了！“跑呀跑，快快跑！你抓不到我，我是姜饼人！”",
            "老太太在后面追。老爷爷也在后面追。可是谁也抓不到姜饼人。",
            "他跑过一头奶牛和一匹马。“站住！”它们喊。“跑呀跑，快快跑！你抓不到我，我是姜饼人！”",
            "后来他来到一条宽宽的河边。哎呀！姜饼人不会游泳。",
            "“跳到我的尾巴上来，”一只聪明的狐狸说。“我背你过河。”姜饼人就跳了上去。",
            "“水很深。跳到我的鼻子上来，”狐狸说。啊呜！姜饼人就这样被吃掉了。",
            "回到家，小老太太又烤了一整盘。这一次，她一直关着烤箱门，等到可以吃了才打开。",
        ]),
        "tortoise-and-hare": Translation(title: "龟兔赛跑", pages: [
            "有一只兔子很爱吹牛。“我是森林里跑得最快的！谁也比不过我！”",
            "“我来和你比赛，”乌龟慢慢地说。所有的动物都笑了。",
            "预备，开始！兔子嗖地跑远了。乌龟一步，一步，又一步地走。",
            "兔子跑得太远了，就躺在一棵树下睡起了午觉。",
            "乌龟没有停下来。一步一步，他从正在睡觉的兔子身边走了过去。",
            "兔子醒来，拼命地跑。可是已经太晚了！",
            "乌龟第一个冲过了终点线。慢慢来，坚持到底就能赢！",
        ]),
        "billy-goats-gruff": Translation(title: "三只山羊嘎啦嘎啦", pages: [
            "有三只叫嘎啦嘎啦的山羊，想去吃河对面山坡上又甜又绿的青草。",
            "可是桥下住着一个脾气很坏的怪物。",
            "嗒嗒，嗒嗒！最小的山羊走过了桥。“是谁在我的桥上走？”怪物大吼。",
            "“别吃我，我太小了！等我的哥哥来吧。”“那你走吧，”怪物说。",
            "嗒嗒，嗒嗒！中间的山羊也这么说。“等我的大哥来吧。他大多了！”",
            "嗒嗒！嗒嗒！最大的山羊嘎啦嘎啦来了。他低下角，一下就把怪物撞下了桥。扑通！",
            "三只山羊整个夏天都在山坡上吃又甜又绿的青草。",
        ]),
        "tang-poems": Translation(title: "Five Tang Poems", pages: [
            "Ode to the Goose, by Luo Binwang. Goose, goose, goose! It bends its neck and sings to the sky. White feathers float on green water. Red feet paddle the clear waves.",
            "Quiet Night Thoughts, by Li Bai. Bright moonlight shines before my bed. I think it is frost on the ground. I lift my head and look at the bright moon. I lower my head and think of home.",
            "Spring Morning, by Meng Haoran. Sleeping in spring, I don't notice the dawn. Everywhere I hear birds singing. Last night there was the sound of wind and rain. How many flowers have fallen?",
            "Pity the Farmers, by Li Shen. Hoeing the rice at noon, sweat drips onto the soil. Who knows that the food in our bowls, every single grain, comes from hard work?",
            "Climbing Stork Tower, by Wang Zhihuan. The white sun sets behind the mountains. The Yellow River flows into the sea. To see a thousand miles away, climb up one more floor.",
        ]),
        "tortoise-and-hare-zh": Translation(title: "The Tortoise and the Hare", pages: [
            "The little rabbit runs very fast. He always says, \"I'm the fastest runner in the forest! Nobody can beat me!\"",
            "The little tortoise said slowly, \"Let's have a race.\" All the little animals laughed.",
            "Ready, go! The little rabbit ran far away at once. The little tortoise crawled forward step by step.",
            "The little rabbit looked back. The little tortoise was still far away. He thought, \"I'll have a sleep first.\"",
            "The little tortoise did not stop. Step by step, he crawled past the sleeping rabbit.",
            "The little rabbit woke up and ran as fast as he could. But it was too late!",
            "The little tortoise reached the finish first. Take it slow, never give up, and you can win too!",
        ]),
    ]
}

extension StoryBook {
    private var translation: StoryTranslations.Translation? { StoryTranslations.books[id] }

    var englishTitle: String { language == .chinese ? translation?.title ?? title : title }
    var chineseTitle: String { language == .chinese ? title : translation?.title ?? title }

    func title(in learning: LearningLanguage) -> String {
        switch learning {
        case .english: return englishTitle
        case .chinese: return chineseTitle
        case .both: return englishTitle == chineseTitle ? title : "\(englishTitle)\n\(chineseTitle)"
        }
    }

    /// A page's words in the chosen language. In Bilingual, the English and then the Chinese, so
    /// they're read in that order.
    func pageText(_ index: Int, in learning: LearningLanguage) -> String {
        let original = pages[index].text
        let other = translation?.pages[safe: index]
        let english = language == .chinese ? other : original
        let chinese = language == .chinese ? original : other
        switch learning {
        case .english: return english ?? original
        case .chinese: return chinese ?? original
        case .both: return [english, chinese].compactMap { $0 }.joined(separator: "\n\n")
        }
    }

    /// The language to read a page in when it has no letters to go by.
    func readingLanguage(in learning: LearningLanguage) -> BookLanguage {
        switch learning {
        case .english: return translation == nil ? language : .english
        case .chinese: return translation == nil ? language : .chinese
        case .both: return .english
        }
    }

    /// The Chinese retelling of a story that's also in the library in English: only one of the
    /// two is shown, so the shelf doesn't have the same book twice.
    private static let retellings = ["tortoise-and-hare-zh": "tortoise-and-hare"]

    /// The books on the shelf for this language: the Chinese retelling in 中文, the English one otherwise.
    static func shelf(in learning: LearningLanguage) -> [StoryBook] {
        StoryLibrary.books.filter { book in
            if retellings[book.id] != nil { return learning == .chinese }
            if retellings.values.contains(book.id) { return learning != .chinese }
            return true
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

import SwiftUI

/// A built-in book in the reader, in the chosen language. Switching language starts the book
/// again from its first page in the new language.
struct StoryReader: View {
    let book: StoryBook
    @AppStorage(LearningLanguage.key) private var language: LearningLanguage = .english

    var body: some View {
        BookReader(title: book.title(in: language).replacingOccurrences(of: "\n", with: " · "), color: book.color,
                   pages: book.pages.indices.map { ReaderPage(text: book.pageText($0, in: language), scene: book.pages[$0].scene) },
                   language: book.readingLanguage(in: language), showsLanguageSwitch: true)
            .id(language)
    }
}
