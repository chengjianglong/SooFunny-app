import Foundation

/// Summer or Winter Games.
enum SportSeason: String, CaseIterable, Identifiable {
    case summer, winter

    var id: Self { self }
    var english: String { self == .summer ? "Summer" : "Winter" }
    var chinese: String { self == .summer ? "夏季" : "冬季" }
    var emoji: String { self == .summer ? "☀️" : "❄️" }
}

/// One summer or winter sport (or discipline), introduced for children in English and
/// Chinese. Written for SooFunny. `photo` names a bundled word photo (group, word) to reuse.
struct OlympicSport: Identifiable, Hashable {
    let id: String
    let season: SportSeason
    let emoji: String
    let english: String
    let chinese: String
    let aboutEnglish: String
    let aboutChinese: String
    var photo: WordPhotoRef?

    struct WordPhotoRef: Hashable {
        let category: String
        let word: String
    }
}

enum OlympicSports {
    static func sports(_ season: SportSeason) -> [OlympicSport] { all.filter { $0.season == season } }

    private static func s(_ id: String, _ season: SportSeason, _ emoji: String, _ english: String, _ chinese: String,
                          _ aboutEnglish: String, _ aboutChinese: String, photo: String? = nil) -> OlympicSport {
        OlympicSport(id: id, season: season, emoji: emoji, english: english, chinese: chinese,
                     aboutEnglish: aboutEnglish, aboutChinese: aboutChinese,
                     photo: photo.map { .init(category: "Sports", word: $0) })
    }

    /// Summer sports follow the 2024 Summer Games programme, winter sports the 2026 Winter Games.
    /// On-screen text avoids the trademarked Games names (see SportsTests).
    static let all: [OlympicSport] = [
        // MARK: Summer
        s("swimming", .summer, "🏊", "Swimming", "游泳",
          "Swimmers race through the water in a pool. They use four strokes: freestyle, backstroke, breaststroke and butterfly. The first swimmer to touch the wall wins!",
          "游泳运动员在泳池里比赛谁游得快。一共有四种泳姿：自由泳、仰泳、蛙泳和蝶泳。最先摸到池边的人获胜！"),
        s("diving", .summer, "🌊", "Diving", "跳水",
          "Divers jump from a springboard or a high platform and do flips and twists in the air. Then they try to go into the water with only a tiny splash. Judges give points for every dive.",
          "跳水运动员从跳板或高高的跳台上跳下，在空中翻腾和转体。入水时水花越小越好。裁判会给每一跳打分。"),
        s("artistic-swimming", .summer, "🩰", "Artistic Swimming", "花样游泳",
          "Swimmers dance in the water to music, all moving together. They lift teammates out of the water and hold their breath for a long time. It needs strength and lots of teamwork.",
          "花样游泳运动员随着音乐在水中跳舞，动作整齐一致。他们会把队友托出水面，还要憋气很长时间。这项运动需要力量和团队合作。"),
        s("water-polo", .summer, "🤽", "Water Polo", "水球",
          "Two teams swim and pass a ball, trying to throw it into the other team's goal. Players can't stand on the bottom of the pool, so they tread water the whole game!",
          "两队在水中游动传球，想把球投进对方的球门。球员不能踩到池底，所以整场比赛都要踩水！"),
        s("athletics", .summer, "🏃", "Athletics", "田径",
          "Athletics has running, jumping and throwing. Athletes race on a track, leap over bars and into sand, and throw things like the javelin. It is one of the oldest sports in the world.",
          "田径包括跑、跳和投掷。运动员在跑道上赛跑，跳过横杆或跳进沙坑，还要投掷标枪等器材。这是世界上最古老的运动之一。",
          photo: "running"),
        s("archery", .summer, "🏹", "Archery", "射箭",
          "Archers shoot arrows with a bow at a round target far away. The yellow middle, called the bullseye, scores the most points. Archers need steady hands and a calm mind.",
          "射箭运动员用弓把箭射向远处的圆形靶子。黄色的靶心得分最高。射箭需要稳稳的手和平静的心。"),
        s("badminton", .summer, "🏸", "Badminton", "羽毛球",
          "Players hit a light shuttlecock over a high net with a racket. The shuttlecock can fly very, very fast. A player wins a point when it lands on the other side.",
          "运动员用球拍把轻轻的羽毛球打过高高的球网。羽毛球可以飞得非常快。球落在对方场地里就得一分。",
          photo: "badminton"),
        s("basketball", .summer, "🏀", "Basketball", "篮球",
          "Two teams of five bounce and pass the ball, trying to throw it through the other team's hoop. Shots from far away count for three points. In 3x3 basketball, each team has just three players.",
          "两队各五人，运球、传球，想把球投进对方的篮筐。从远处投进的球算三分。三人篮球每队只有三个人。",
          photo: "basketball"),
        s("boxing", .summer, "🥊", "Boxing", "拳击",
          "Two boxers wearing padded gloves try to land punches in a ring. Judges score who boxed better in each round. Boxers must be fast, strong and quick to dodge.",
          "两名戴着厚手套的拳击手在擂台上比赛出拳。裁判为每一回合打分，看谁打得更好。拳击手要又快又有力气，还要会躲闪。"),
        s("breaking", .summer, "🕺", "Breaking", "霹雳舞",
          "Breaking is a street dance from New York. Dancers called B-Boys and B-Girls battle one on one with spins, freezes and power moves to the music.",
          "霹雳舞是一种来自纽约的街舞。舞者们一对一斗舞，随着音乐做旋转、定格和高难度动作。"),
        s("canoeing", .summer, "🛶", "Canoeing", "皮划艇",
          "Paddlers race small boats called canoes and kayaks. Some race on calm water. Others rush down a wild, splashy course and go through gates, which is called slalom.",
          "运动员划着叫作划艇和皮艇的小船比赛。有的在平静的水面上比速度，有的在湍急的水道中穿过一个个水门，这叫激流回旋。"),
        s("cycling", .summer, "🚴", "Cycling", "自行车",
          "Riders race bikes on roads, around a steep indoor track, on bumpy mountain trails and on BMX courses with jumps. Racing bikes can go very fast!",
          "自行车运动员在公路、室内场地赛道、崎岖的山地和有跳坡的小轮车赛道上比赛。赛车可以骑得非常快！"),
        s("equestrian", .summer, "🏇", "Equestrian", "马术",
          "In equestrian sports, a rider and a horse compete as a team. They jump over fences, do graceful dance-like moves called dressage, and ride across the countryside.",
          "马术比赛中，骑手和马是一个团队。他们要跳过障碍，表演像跳舞一样优雅的盛装舞步，还要在野外越野骑行。"),
        s("fencing", .summer, "🤺", "Fencing", "击剑",
          "Fencers fight with long, thin swords while wearing masks and white suits. They score by touching the other fencer with the sword. Lights flash to show who scored.",
          "击剑运动员戴着面罩、穿着白色击剑服，用细长的剑比赛。用剑碰到对手就能得分。灯会亮起来，显示谁得了分。"),
        s("football", .summer, "⚽", "Football (Soccer)", "足球",
          "Two teams of eleven players kick the ball and try to score in the other team's goal. Only the goalkeeper may use their hands. It is the most popular sport in the world.",
          "两队各十一人用脚踢球，想把球踢进对方球门。只有守门员可以用手碰球。足球是世界上最受欢迎的运动。",
          photo: "soccer"),
        s("golf", .summer, "⛳", "Golf", "高尔夫球",
          "Golfers hit a small ball with a club, trying to get it into a hole in as few shots as possible. The course has grass, sand traps and sometimes ponds.",
          "高尔夫球手用球杆击打小球，想用最少的杆数把球打进洞里。球场上有草地、沙坑，有时还有池塘。",
          photo: "golf"),
        s("gymnastics", .summer, "🤸", "Gymnastics", "体操",
          "Gymnasts flip, swing and balance on the floor, the balance beam and the bars. Rhythmic gymnasts dance with ribbons, hoops and balls, and trampoline gymnasts bounce high into the air.",
          "体操运动员在自由体操场地、平衡木和各种杠上翻腾、摆动和保持平衡。艺术体操运动员拿着彩带、圈和球跳舞，蹦床运动员会弹得很高很高。",
          photo: "gymnastics"),
        s("handball", .summer, "🤾", "Handball", "手球",
          "Two teams of seven pass a ball with their hands and throw it into the other team's goal. Players may take only three steps while holding the ball.",
          "两队各七人用手传球，想把球扔进对方的球门。拿着球的时候最多只能走三步。"),
        s("hockey", .summer, "🏑", "Hockey", "曲棍球",
          "In field hockey, two teams use curved sticks to hit a small, hard ball into the other team's goal. They play on a smooth field of artificial grass.",
          "曲棍球比赛中，两队用弯弯的球棍击打一个又小又硬的球，想把它打进对方球门。比赛在平平的人造草场上进行。",
          photo: "hockey"),
        s("judo", .summer, "🥋", "Judo", "柔道",
          "Judo comes from Japan. Two players in white or blue suits try to throw each other onto the mat or hold each other down. Judo means \"the gentle way.\"",
          "柔道来自日本。两名穿着白色或蓝色柔道服的选手想办法把对方摔倒在垫子上，或者把对方压住。柔道的意思是“柔和之道”。"),
        s("modern-pentathlon", .summer, "🏅", "Modern Pentathlon", "现代五项",
          "Modern pentathlon mixes several sports in one day, like fencing, swimming, and a last race that combines running and laser shooting. Athletes must be good at everything!",
          "现代五项要在一天里完成好几个项目，比如击剑、游泳，还有把跑步和激光射击结合在一起的比赛。运动员必须样样都很棒！"),
        s("rowing", .summer, "🚣", "Rowing", "赛艇",
          "Rowers sit in long, thin boats and pull oars to race across calm water. They sit facing backward, so they cross the finish line backward!",
          "赛艇运动员坐在又长又窄的船里，用桨划水比赛。他们是背对着前进方向坐的，所以冲过终点时是倒着的！"),
        s("rugby-sevens", .summer, "🏉", "Rugby Sevens", "七人制橄榄球",
          "Two teams of seven run with an oval ball and try to put it down behind the other team's goal line. They may only pass the ball backward or sideways. Each half lasts just seven minutes.",
          "两队各七人抱着椭圆形的球奔跑，想把球放到对方的得分线后面。传球只能往后或往旁边传。每个半场只有七分钟。"),
        s("sailing", .summer, "⛵", "Sailing", "帆船",
          "Sailors race boats that are pushed by the wind. They watch the wind and waves to find the fastest way around the course. Some boats even fly above the water on foils!",
          "帆船运动员驾驶靠风推动的船比赛。他们要观察风和浪，找出绕过航线最快的路线。有些船甚至能靠水翼“飞”在水面上！"),
        s("shooting", .summer, "🎯", "Shooting", "射击",
          "Shooters aim very carefully and score points for hitting the middle of the target. Some aim at paper targets and others at flying clay discs. Staying very still is the secret.",
          "射击运动员非常仔细地瞄准，打中靶子中心就能得高分。有的打纸靶，有的打飞起来的飞碟。保持身体一动不动是秘诀。"),
        s("skateboarding", .summer, "🛹", "Skateboarding", "滑板",
          "Skaters ride boards on wheels and do tricks on ramps, rails and stairs. Judges score how hard, smooth and creative the tricks are.",
          "滑板运动员踩着带轮子的滑板，在坡道、栏杆和台阶上做各种花样动作。裁判根据动作的难度、流畅和创意打分。"),
        s("sport-climbing", .summer, "🧗", "Sport Climbing", "竞技攀岩",
          "Climbers go up tall walls covered with colorful holds. In speed climbing they race to the top in just a few seconds. In other events they work out tricky routes like puzzles.",
          "攀岩运动员在布满彩色岩点的高墙上攀爬。速度攀岩只要几秒钟就能爬到顶，其他项目则要像解谜一样找出难爬的路线。"),
        s("surfing", .summer, "🏄", "Surfing", "冲浪",
          "Surfers ride ocean waves standing on a board. Judges give points for big turns, speed and style. Surfers have to wait patiently for the right wave.",
          "冲浪运动员站在冲浪板上乘着海浪滑行。裁判根据转弯、速度和动作风格打分。冲浪运动员还要耐心等待合适的海浪。",
          photo: "surfing"),
        s("table-tennis", .summer, "🏓", "Table Tennis", "乒乓球",
          "Players hit a small, light ball back and forth over a low net on a table. The ball spins and flies so fast that players need very quick reactions. It is also called ping pong.",
          "运动员在球台上隔着矮矮的球网来回击打一个又小又轻的球。球又快又会旋转，所以需要非常快的反应。乒乓球在中国非常受欢迎。",
          photo: "ping pong"),
        s("taekwondo", .summer, "🦵", "Taekwondo", "跆拳道",
          "Taekwondo comes from Korea. Players wear padded vests and helmets and score points with fast, high kicks and punches. Spinning kicks score extra points.",
          "跆拳道来自韩国。选手穿着护具、戴着头盔，用又快又高的踢腿和出拳得分。转身踢能得更多分。"),
        s("tennis", .summer, "🎾", "Tennis", "网球",
          "Players hit a fuzzy yellow ball over a net with a racket. The ball may bounce only once on each side. Playing alone is called singles, and playing in pairs is called doubles.",
          "运动员用球拍把毛茸茸的黄色小球打过球网。球在每一边最多只能弹一次。一个人打叫单打，两个人一起打叫双打。",
          photo: "tennis"),
        s("triathlon", .summer, "🏊‍♀️", "Triathlon", "铁人三项",
          "Triathletes swim, then ride a bike, then run, all in one race without stopping. Changing quickly from one sport to the next is part of the race.",
          "铁人三项运动员要在一场比赛里连续完成游泳、骑自行车和跑步，中间不能停下来。快速地从一个项目换到下一个项目也是比赛的一部分。"),
        s("volleyball", .summer, "🏐", "Volleyball", "排球",
          "Two teams hit a ball over a high net with their hands and arms and try to make it land on the other side. Each team may touch the ball three times. Beach volleyball is played on sand by teams of two.",
          "两队用手和手臂把球击过高高的球网，想让球落在对方场地上。每队最多只能碰球三次。沙滩排球在沙滩上进行，每队两个人。",
          photo: "volleyball"),
        s("weightlifting", .summer, "🏋️", "Weightlifting", "举重",
          "Weightlifters lift a heavy bar with weights on it from the floor up over their heads. The person who lifts the most wins. It takes strength and good technique.",
          "举重运动员把装着杠铃片的沉重杠铃从地上举过头顶。举起最重的人获胜。举重既需要力量，也需要好的技术。"),
        s("wrestling", .summer, "🤼", "Wrestling", "摔跤",
          "Two wrestlers grab, push and pull, trying to hold the other's shoulders down on the mat. Wrestling is one of the oldest sports in the world, thousands of years old.",
          "两名摔跤手互相抓、推、拉，想把对方的双肩压在垫子上。摔跤是世界上最古老的运动之一，已经有几千年的历史了。"),

        // MARK: Winter
        s("alpine-skiing", .winter, "⛷️", "Alpine Skiing", "高山滑雪",
          "Skiers race down snowy mountains, zooming around poles called gates. The fastest racers go as fast as a car on a highway!",
          "高山滑雪运动员从雪山上飞速滑下，绕过叫作旗门的杆子。最快的选手能像高速公路上的汽车一样快！",
          photo: "skiing"),
        s("biathlon", .winter, "🎯", "Biathlon", "冬季两项",
          "Biathletes ski across the snow with a rifle on their backs. They stop to shoot at small targets, and missing usually means extra skiing!",
          "冬季两项运动员背着枪在雪地上滑雪。他们会停下来射击小小的靶子，打偏了通常就要多滑一段路！"),
        s("bobsleigh", .winter, "🛷", "Bobsleigh", "雪车",
          "Bobsledders push a sled, jump in and race down a twisting track made of ice. A team can have one, two or four people. Bobsleds can go faster than 140 kilometers an hour!",
          "雪车运动员推动雪车，然后跳上车，沿着弯弯曲曲的冰道冲下去。一队可以是一人、两人或四人。雪车的速度可以超过每小时140公里！"),
        s("cross-country-skiing", .winter, "🌲", "Cross-Country Skiing", "越野滑雪",
          "Skiers race long distances over snowy hills and through forests. It is one of the hardest sports for your heart and lungs!",
          "越野滑雪运动员在雪地的山坡和森林里进行长距离比赛。这是对心脏和肺最有挑战的运动之一！"),
        s("curling", .winter, "🥌", "Curling", "冰壶",
          "Players slide heavy granite stones across the ice toward a round target called the house. Teammates sweep the ice with brooms to help the stone go farther and straighter.",
          "冰壶运动员把沉重的花岗岩石壶推过冰面，滑向叫作大本营的圆形目标。队友用刷子刷冰，帮助冰壶滑得更远、更直。"),
        s("figure-skating", .winter, "⛸️", "Figure Skating", "花样滑冰",
          "Skaters glide, spin and jump on the ice to music. Some skate alone, and others skate in pairs or dance together. Judges score their skill and beauty.",
          "花样滑冰运动员随着音乐在冰上滑行、旋转和跳跃。有单人滑，也有双人滑和冰上舞蹈。裁判根据技术和艺术表现打分。"),
        s("freestyle-skiing", .winter, "🌀", "Freestyle Skiing", "自由式滑雪",
          "Freestyle skiers flip and twist in the air off big jumps, race over bumps called moguls, and do tricks in a halfpipe.",
          "自由式滑雪运动员从大跳台上飞起，在空中翻转，在雪包上快速滑行，还在U型场地里做各种技巧动作。"),
        s("ice-hockey", .winter, "🏒", "Ice Hockey", "冰球",
          "Two teams skate fast and use sticks to shoot a hard rubber disc, called a puck, into the other team's goal. It is one of the fastest team sports.",
          "两队在冰上快速滑行，用球杆把一个硬橡胶做的冰球打进对方球门。冰球是最快的团体运动之一。"),
        s("luge", .winter, "🛷", "Luge", "雪橇",
          "Luge sliders lie on their backs on a small sled and race feet first down an icy track. They steer with their legs and shoulders.",
          "雪橇运动员仰面躺在小雪橇上，脚朝前沿着冰道滑下。他们用腿和肩膀来控制方向。"),
        s("nordic-combined", .winter, "🎿", "Nordic Combined", "北欧两项",
          "Nordic combined mixes two sports: ski jumping and cross-country skiing. The best jumpers start the ski race first, and the first to cross the finish line wins.",
          "北欧两项把跳台滑雪和越野滑雪结合在一起。跳得最好的选手先出发滑雪，第一个冲过终点的人获胜。"),
        s("short-track", .winter, "⛸️", "Short Track Speed Skating", "短道速滑",
          "Skaters race in a group around a small oval track on the ice. They pass each other a lot, and the turns are very tight.",
          "短道速滑运动员成群地在小小的椭圆形冰道上比赛。比赛中经常超越对手，弯道又急又窄。"),
        s("skeleton", .winter, "🛷", "Skeleton", "钢架雪车",
          "Skeleton sliders run, dive head first onto a small sled and race down an icy track. Their chin is just a few centimeters above the ice!",
          "钢架雪车运动员先助跑，然后头朝前趴在小雪车上沿着冰道冲下去。他们的下巴离冰面只有几厘米！"),
        s("ski-jumping", .winter, "🕊️", "Ski Jumping", "跳台滑雪",
          "Ski jumpers speed down a huge ramp and fly through the air like birds. They score points for how far they fly and how well they land.",
          "跳台滑雪运动员从巨大的跳台上滑下，像小鸟一样在空中飞行。他们根据飞行的距离和落地的姿势得分。"),
        s("ski-mountaineering", .winter, "🏔️", "Ski Mountaineering", "滑雪登山",
          "Ski mountaineers climb up a snowy mountain on skis, sometimes carrying them on their backs, and then ski down fast.",
          "滑雪登山运动员穿着滑雪板爬上雪山，有时还要把雪板背在背上走，然后再快速滑下来。"),
        s("snowboarding", .winter, "🏂", "Snowboarding", "单板滑雪",
          "Snowboarders ride down the snow on one wide board. Some race, and others do big tricks in the halfpipe and off jumps.",
          "单板滑雪运动员站在一块宽宽的滑雪板上从雪坡滑下。有的比赛速度，有的在U型场地和跳台上做高难度动作。"),
        s("speed-skating", .winter, "⛸️", "Speed Skating", "速度滑冰",
          "Speed skaters race around a big oval track of ice. They bend low and swing their arms to go as fast as they can.",
          "速度滑冰运动员在大大的椭圆形冰道上比赛。他们弯下身子、摆动手臂，尽可能滑得快。"),
    ]
}
