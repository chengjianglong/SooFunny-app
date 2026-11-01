import SwiftUI

/// A picture book page: a few words and an emoji picture.
struct StoryPage: Hashable {
    let scene: String
    let text: String
}

/// A picture book that comes with the app. The stories are SooFunny's own short retellings of
/// public-domain folk tales and nursery rhymes, so they can be read aloud and shared freely.
struct StoryBook: Identifiable, Hashable {
    let id: String
    let title: String
    let cover: String
    let color: Color
    let pages: [StoryPage]
    var language: BookLanguage = .english
}

enum StoryLibrary {
    static let books: [StoryBook] = [
        StoryBook(id: "nursery-rhymes", title: "Twinkle, Twinkle and Friends", cover: "⭐️", color: .purple, pages: [
            StoryPage(scene: "⭐️🌙✨", text: "Twinkle, twinkle, little star, how I wonder what you are! Up above the world so high, like a diamond in the sky."),
            StoryPage(scene: "🥚🧱💥", text: "Humpty Dumpty sat on a wall. Humpty Dumpty had a great fall. All the king's horses and all the king's men couldn't put Humpty together again."),
            StoryPage(scene: "🐱🎻🐄🌙", text: "Hey diddle diddle, the cat and the fiddle, the cow jumped over the moon. The little dog laughed to see such fun, and the dish ran away with the spoon."),
            StoryPage(scene: "🕷️🌧️☀️", text: "The itsy bitsy spider climbed up the water spout. Down came the rain and washed the spider out. Out came the sun and dried up all the rain, and the itsy bitsy spider climbed up the spout again."),
            StoryPage(scene: "🐑🧶", text: "Baa, baa, black sheep, have you any wool? Yes sir, yes sir, three bags full. One for the master, one for the dame, and one for the little boy who lives down the lane."),
            StoryPage(scene: "👦👧⛰️🪣", text: "Jack and Jill went up the hill to fetch a pail of water. Jack fell down and broke his crown, and Jill came tumbling after."),
            StoryPage(scene: "🐭🕰️", text: "Hickory, dickory, dock. The mouse ran up the clock. The clock struck one, the mouse ran down. Hickory, dickory, dock."),
        ]),
        StoryBook(id: "three-little-pigs", title: "The Three Little Pigs", cover: "🐷", color: .pink, pages: [
            StoryPage(scene: "🐷🐷🐷🏡", text: "Once upon a time, three little pigs left home to build houses of their own."),
            StoryPage(scene: "🐷🌾🏠", text: "The first little pig built a house of straw. It was quick and easy!"),
            StoryPage(scene: "🐷🪵🏠", text: "The second little pig built a house of sticks. That was quick too!"),
            StoryPage(scene: "🐷🧱🏠", text: "The third little pig built a house of bricks. It took a long, long time."),
            StoryPage(scene: "🐺🌾💨", text: "Along came a big bad wolf. \"Little pig, little pig, let me come in!\" He huffed and he puffed, and he blew the straw house down!"),
            StoryPage(scene: "🐺🪵💨", text: "The wolf huffed and puffed at the house of sticks. Down it came! The pigs ran to the brick house."),
            StoryPage(scene: "🐺🧱😤", text: "The wolf huffed and puffed, and puffed and huffed. But the brick house did not fall down."),
            StoryPage(scene: "🐷🐷🐷🎉", text: "The wolf gave up and ran away. The three little pigs danced and sang, safe and sound in the brick house."),
        ]),
        StoryBook(id: "good-night-farm", title: "Good Night, Farm", cover: "🌙", color: .indigo, pages: [
            StoryPage(scene: "🌅🚜", text: "The sun goes down over the farm. It's time for bed."),
            StoryPage(scene: "🐄💤", text: "Good night, cow. Moo, moo. Sleep well too."),
            StoryPage(scene: "🐷💤", text: "Good night, pig, snug in the mud. Oink, oink."),
            StoryPage(scene: "🐑💤", text: "Good night, sheep, all fluffy and white. Baa, baa, good night."),
            StoryPage(scene: "🐔💤", text: "Good night, hen, up on the roost. Cluck, cluck, sweet dreams."),
            StoryPage(scene: "🌙⭐️🦉", text: "The moon comes up. The stars come out. Only the owl is awake. Hoo, hoo."),
            StoryPage(scene: "🧸🛏️😴", text: "And now it's your turn. Good night, little one. Sleep tight."),
        ]),
        StoryBook(id: "goldilocks", title: "Goldilocks and the Three Bears", cover: "🐻", color: .orange, pages: [
            StoryPage(scene: "🐻🐻🧸🏡🌲", text: "Once upon a time, three bears lived in a little house in the woods: Papa Bear, Mama Bear and Baby Bear."),
            StoryPage(scene: "🥣🥣🥣🚶", text: "Their porridge was too hot, so the bears went for a walk while it cooled."),
            StoryPage(scene: "👧🌲🏡", text: "A girl named Goldilocks found the little house. She knocked, but nobody answered, so she went inside."),
            StoryPage(scene: "👧🥣😋", text: "She tasted the porridge. This one is too hot! This one is too cold! This one is just right! And she ate it all up."),
            StoryPage(scene: "👧🪑💥", text: "She sat in the chairs. This one is too big! This one is too big too! This one is just right! But crack, the little chair broke."),
            StoryPage(scene: "👧🛏️😴", text: "She tried the beds. Too hard! Too soft! Just right! And Goldilocks fell fast asleep."),
            StoryPage(scene: "🐻🐻🧸😮", text: "The bears came home. \"Someone has been eating my porridge,\" said Baby Bear, \"and they ate it all up!\""),
            StoryPage(scene: "👧🏃‍♀️🌲", text: "Goldilocks woke up, saw three bears, and ran all the way home. She never went into a stranger's house again."),
        ]),
        StoryBook(id: "little-red-hen", title: "The Little Red Hen", cover: "🐔", color: .red, pages: [
            StoryPage(scene: "🐔🌾", text: "The little red hen found some grains of wheat. \"Who will help me plant the wheat?\""),
            StoryPage(scene: "🐶🐱🦆", text: "\"Not I,\" said the dog. \"Not I,\" said the cat. \"Not I,\" said the duck. \"Then I will do it myself,\" said the little red hen. And she did."),
            StoryPage(scene: "🐔🌾☀️", text: "The wheat grew tall and golden. \"Who will help me cut the wheat?\" \"Not I,\" said the dog, the cat and the duck. So she did it herself."),
            StoryPage(scene: "🐔🌾🏠", text: "\"Who will help me take the wheat to the mill?\" \"Not I,\" said everyone. So the little red hen took it herself, and came back with flour."),
            StoryPage(scene: "🐔🍞🔥", text: "\"Who will help me bake the bread?\" \"Not I,\" said the dog, the cat and the duck. So she baked it herself."),
            StoryPage(scene: "🍞😋", text: "The bread smelled warm and wonderful. \"Who will help me eat the bread?\" \"I will!\" said the dog, the cat and the duck."),
            StoryPage(scene: "🐔🐣🍞", text: "\"No,\" said the little red hen. \"I did all the work, so my chicks and I will eat it.\" And they did, every crumb."),
            StoryPage(scene: "🐶🐱🦆🤝", text: "The next time, the dog, the cat and the duck all helped. And everyone shared the bread."),
        ]),
        StoryBook(id: "gingerbread-man", title: "The Gingerbread Man", cover: "🍪", color: .brown, pages: [
            StoryPage(scene: "👵🍪🔥", text: "A little old woman baked a gingerbread man with raisin eyes and a candy smile."),
            StoryPage(scene: "🍪🏃💨", text: "When she opened the oven, out he jumped and away he ran! \"Run, run, as fast as you can! You can't catch me, I'm the gingerbread man!\""),
            StoryPage(scene: "👵👴🏃", text: "The old woman ran after him. The old man ran after him. But nobody could catch the gingerbread man."),
            StoryPage(scene: "🐄🐴🏃", text: "He ran past a cow and a horse. \"Stop!\" they called. \"Run, run, as fast as you can! You can't catch me, I'm the gingerbread man!\""),
            StoryPage(scene: "🍪🌊", text: "Then he came to a wide river. Oh no! The gingerbread man could not swim."),
            StoryPage(scene: "🦊🍪", text: "\"Hop on my tail,\" said a clever fox. \"I will carry you across.\" So the gingerbread man hopped on."),
            StoryPage(scene: "🦊🍪😮", text: "\"The water is deep. Hop onto my nose,\" said the fox. And snap! That was the end of the gingerbread man."),
            StoryPage(scene: "👵🍪🍪🍪", text: "Back home, the little old woman baked a whole new batch. This time she kept the oven shut until they were ready to eat."),
        ]),
        StoryBook(id: "tortoise-and-hare", title: "The Tortoise and the Hare", cover: "🐢", color: .green, pages: [
            StoryPage(scene: "🐇🗣️", text: "A hare liked to brag. \"I'm the fastest animal in the forest! Nobody can beat me!\""),
            StoryPage(scene: "🐢🙂", text: "\"I'll race you,\" said the tortoise, slowly. All the animals laughed."),
            StoryPage(scene: "🏁🐇💨🐢", text: "Ready, set, go! The hare zoomed off. The tortoise walked, step by step by step."),
            StoryPage(scene: "🐇🌳😴", text: "The hare was so far ahead that he lay down under a tree for a nap."),
            StoryPage(scene: "🐢👣", text: "The tortoise did not stop. Step by step, he walked right past the sleeping hare."),
            StoryPage(scene: "🐇😱🏃", text: "The hare woke up and ran as fast as he could. But it was too late!"),
            StoryPage(scene: "🐢🏁🏆", text: "The tortoise crossed the finish line first. Slow and steady wins the race!"),
        ]),
        StoryBook(id: "billy-goats-gruff", title: "The Three Billy Goats Gruff", cover: "🐐", color: .teal, pages: [
            StoryPage(scene: "🐐🐐🐐🌿", text: "Three billy goats named Gruff wanted to eat the sweet green grass on the hill across the river."),
            StoryPage(scene: "🌉👹", text: "But under the bridge lived a grumpy troll."),
            StoryPage(scene: "🐐🌉", text: "Trip, trap, trip, trap! The littlest billy goat crossed the bridge. \"Who's that tripping over my bridge?\" roared the troll."),
            StoryPage(scene: "🐐👹", text: "\"Don't eat me, I'm too small! Wait for my big brother.\" \"Off you go, then,\" said the troll."),
            StoryPage(scene: "🐐🐐🌉", text: "Trip, trap, trip, trap! The middle billy goat said the same thing. \"Wait for my big brother. He's much bigger!\""),
            StoryPage(scene: "🐐💪👹", text: "TRIP, TRAP, TRIP, TRAP! The biggest billy goat Gruff came along. He lowered his horns and bumped the troll right off the bridge. Splash!"),
            StoryPage(scene: "🐐🐐🐐🌿😋", text: "The three billy goats ate sweet green grass on the hill all summer long."),
        ]),
        StoryBook(id: "tang-poems", title: "唐诗五首 Tang Poems", cover: "🏮", color: .red, pages: [
            StoryPage(scene: "🦢🌊", text: "《咏鹅》骆宾王。鹅，鹅，鹅，曲项向天歌。白毛浮绿水，红掌拨清波。"),
            StoryPage(scene: "🌙🛏️🏠", text: "《静夜思》李白。床前明月光，疑是地上霜。举头望明月，低头思故乡。"),
            StoryPage(scene: "🌸🐦🌧️", text: "《春晓》孟浩然。春眠不觉晓，处处闻啼鸟。夜来风雨声，花落知多少。"),
            StoryPage(scene: "🌾☀️🍚", text: "《悯农》李绅。锄禾日当午，汗滴禾下土。谁知盘中餐，粒粒皆辛苦。"),
            StoryPage(scene: "🌄🏯🌊", text: "《登鹳雀楼》王之涣。白日依山尽，黄河入海流。欲穷千里目，更上一层楼。"),
        ], language: .chinese),
        StoryBook(id: "tortoise-and-hare-zh", title: "龟兔赛跑 The Tortoise and the Hare", cover: "🐢", color: .mint, pages: [
            StoryPage(scene: "🐇🗣️", text: "小兔子跑得很快。它总是说：“我是森林里跑得最快的！谁也比不过我！”"),
            StoryPage(scene: "🐢🙂", text: "小乌龟慢慢地说：“我们来比一比吧。”小动物们都笑了。"),
            StoryPage(scene: "🏁🐇💨🐢", text: "预备，开始！小兔子一下子就跑远了。小乌龟一步一步地往前爬。"),
            StoryPage(scene: "🐇🌳😴", text: "小兔子回头一看，小乌龟还在很远的地方。它想：“我先睡一觉吧。”"),
            StoryPage(scene: "🐢👣", text: "小乌龟没有停下来。它一步一步，爬过了正在睡觉的小兔子。"),
            StoryPage(scene: "🐇😱🏃", text: "小兔子醒来，拼命地跑。可是已经太晚了！"),
            StoryPage(scene: "🐢🏁🏆", text: "小乌龟第一个到了终点。慢慢来，不放弃，也能赢！"),
        ], language: .chinese),
    ]
}
