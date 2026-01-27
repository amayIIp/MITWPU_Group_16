import Foundation

struct PhonemeContent {
    
    // A dictionary mapping a letter (as a string) to a list of practice sentences.
    static let practiceSentences: [String: [String]] = [
        "A": [
            "An apple a day keeps the doctor away.",
            "Alice asked for an awful lot of apples.",
            "Animals are amazing and adorable.",
            "Always aim for accuracy and attention.",
            "Aviation adventures are always amusing.",
            "Architects arrange amazing apartment avenues.",
            "Ancient artifacts always attract attention.",
            "Apples and apricots are available around August."
        ],
        "B": [
            "Big brown bears build big bridges.",
            "Betty bought a bit of better butter.",
            "The ball bounced behind the big barn.",
            "Bill brought a basket of blueberries.",
            "Brave boys build bright boats.",
            "Baboons believe bananas bestow benefits.",
            "Bubbling brooks bring beautiful bliss.",
            "Busy bees buzz by bright blossoms."
        ],
        "C": [
            "Cats can climb carefully considering consequences.",
            "Carol cooks carrots and cabbage calmly.",
            "Cold coffee can cause coughing.",
            "Can you call the captain quickly?",
            "Clean cars cost considerable cash.",
            "Clever clowns create colorful costumes.",
            "Crows collect copper coins constantly.",
            "Cake crumbs cover clean carpets."
        ],
        "D": [
            "Dogs dig deep down in the dirt.",
            "David drove down the dark driveway.",
            "Don't do dangerous deeds daily.",
            "Ducks dive deep for dinner.",
            "Danny draws dinosaurs during dusk.",
            "Distant drums disturb dormant deer.",
            "Deep divers discover different depths.",
            "Dark days demand determined dreams."
        ],
        "E": [
            "Elephants eat every evening.",
            "Eleven elfs entered the elevator.",
            "Every effort earns experience.",
            "Eric eats eggs early.",
            "Eagles eye everything everywhere.",
            "Empty echoes enter endless evenings.",
            "Excited engineers examine engine efficiency.",
            "Elegant emus enjoy easy exercises."
        ],
        "F": [
            "Five fat frogs fly fast.",
            "Fred found four funny fish.",
            "Fireflies fly freely in forests.",
            "Fix the fence for the farm.",
            "Friends find fun forever.",
            "Fresh fruit feels fine for Fridays.",
            "Fancy feathers flock from far fields.",
            "Fierce fires flicker following frost."
        ],
        "G": [
            "Green grass grows gradually.",
            "Gary gave George a golden gift.",
            "Goats graze in green gardens.",
            "Great games get good grades.",
            "Girls giggled at the goofy game.",
            "Giant gorillas gather green grapes.",
            "Golden gates glow gently.",
            "Good guys go get great goals."
        ],
        "H": [
            "Harry has a huge house.",
            "Happy hippos hop happily.",
            "Help him hold the heavy hammer.",
            "Hot horses have high hopes.",
            "He heard her humming hymns.",
            "Humble humans hope high.",
            "Heavy hail hits high hills.",
            "History honors honest heroes."
        ],
        "I": [
            "I imagine interesting ideas.",
            "Inside the igloo, it is icy.",
            "Islands in Indonesia are incredible.",
            "Ivy is irritated by insects.",
            "Illness is improved by immunity.",
            "Important icons inspire individual ideals.",
            "Instant images improve internet interest.",
            "Irritating itches involve interesting instincts."
        ],
        "J": [
            "Jack jumps just for joy.",
            "Jill joined the junior judo.",
            "Jellyfish just jiggle joyfully.",
            "John jokes with jolly jesters.",
            "June july and january.",
            "Judges justify joyful journeys.",
            "Just jump join joyful jams.",
            "Jaguars journey just junction."
        ],
        "K": [
            "Kings keep keys to kingdoms.",
            "Kelly kept the kettle kicking.",
            "Kangaroos kick quickly.",
            "Keep kinder kids kind.",
            "Kites kiss the kid's knee.",
            "Kitchen knives keep keen.",
            "Koalas keep kind kids.",
            "Knowledge keeps keen keys."
        ],
        "L": [
            "Lions love long lazy lunches.",
            "Larry likes little lemon lollipops.",
            "Look for lovely lilies lately.",
            "Lost lambs look lonely.",
            "Lights lit the long lane.",
            "Lovely ladies love long lace.",
            "Lemonade likes little lemon.",
            "Large lakes look like light."
        ],
        "M": [
            "Monkeys make many messy mistakes.",
            "Mary made money making masks.",
            "My mother makes marvellous muffins.",
            "Men move many mild mountains.",
            "Music makes me move.",
            "Monday morning makes me mad.",
            "Magic mirrors make many memories.",
            "Massive moons move misty mountains."
        ],
        "N": [
            "Nine nice neighbours noticed noon.",
            "New notes need neat names.",
            "No noise is needed now.",
            "Never nap near newts.",
            "Nelly needs nine nails.",
            "Nightly news needs neat notes.",
            "Nobody notices neat names.",
            "Nearby nations need normal news."
        ],
        "O": [
            "Owls often observe openly.",
            "Open orange ovens often.",
            "Only old oxen obey.",
            "Our own onions are okay.",
            "Over the ocean, oil oozes.",
            "Open oceans offer original objects.",
            "Only oysters order olives.",
            "Often others offer only opinion."
        ],
        "P": [
            "Peter Piper picked a peck of pickled peppers.",
            "Please put the paper past the pen.",
            "Purple plums people prefer.",
            "Pretty parrots play peacefullly.",
            "Paul paints poor pictures.",
            "Practical people plan perfect parties.",
            "Patient painters paint pale petals.",
            "Polite people prefer pure peace."
        ],
        "Q": [
            "Queens quietly question quests.",
            "Quick quacks quiet qualms.",
            "Quit quarrelling quickly.",
            "Quotes quote quaint questions.",
            "Quarter queues are quite queer.",
            "Quiet quests question quality.",
            "Quacking quails quickly quit.",
            "Quaint quilts quiet queens."
        ],
        "R": [
            "Red roses run round the road.",
            "Rabbits run rapidly round roads.",
            "Real reading requires rest.",
            "Robert ran round rapid rivers.",
            "Rain ruins red roofs.",
            "Running rivers reach rocky ridges.",
            "Round rings require real rocks.",
            "Rare robots repair red rockets."
        ],
        "S": [
            "Seven silly snakes slither slowly.",
            "She sells seashells by the seashore.",
            "Sam sang sad songs softly.",
            "Sun shines so strong sometimes.",
            "Small stars shine silently.",
            "Six slippery snails slid slowly.",
            "Sleepy shepherds see soft sheep.",
            "Silver spoons suit sweet soup."
        ],
        "T": [
            "Ten tiny tigers took two taxis.",
            "Tom took the train to town.",
            "Time tells true tales.",
            "Two trees touch the top.",
            "Tasty tea tastes terrific.",
            "Three thin thinkers think things.",
            "Tall towers touch the twilight.",
            "Today Tom told ten tales."
        ],
        "U": [
            "Umbrellas up under us.",
            "Unique unicorns use utensils.",
            "Understand uncle's unusual urge.",
            "Use useful units usually.",
            "Upper units undo under units.",
            "Urgent updates use unique units.",
            "Under usual umbrellas us.",
            "Ugly urchins understand us."
        ],
        "V": [
            "Viky visited very vivid valleys.",
            "Vans view vast villages.",
            "Voices vary very violently.",
            "Violets very vaugely vanish.",
            "Vet visits very vicious vipers.",
            "Vibrant voices value vast views.",
            "Vivid valleys vest vast vines.",
            "Vanilla vapor vanishes very vanish."
        ],
        "W": [
            "We went walking with water everywhere.",
            "Wild wolves wait while watching.",
            "Will we wait for winter?",
            "Wet weather was worse.",
            "Wanda wants white wine.",
            "Water washes white walls.",
            "Weather watchers wait well.",
            "Warm winds wish white winter."
        ],
        "X": [
            "Xylophones x-ray x-mas.",
            "Xenon x-rays xylophones.",
            "Fix six boxes of wax.",
            "Mix six oxes in box.",
            "Fox fix box six.",
            "Xylophone xylophones xylophones.",
            "Extra exercise exhausts x-ray.",
            "Complex boxes relax."
        ],
        "Y": [
            "You yell yellow yoyos.",
            "Young yaks yell yes.",
            "Yesterday you yelled yes.",
            "Yellow yards yield yams.",
            "Yoga yields young years.",
            "Young youths yearn yearly.",
            "Yesterday yoga yielded yelling.",
            "Yellow yaks yummy yams."
        ],
        "Z": [
            "Zebras zigzag zoomed.",
            "Zoo zones zero zebras.",
            "Zack zapped zero zombies.",
            "Zinc zippers zip.",
            "Zero zoos zone zero areas.",
            "Zesty zebras zigzag zoo.",
            "Zippers zip zinc zones.",
            "Zany zebras zigzag zero."
        ]
    ]
    
    static func generateParagraph(for letters: [String]) -> String {
        var combinedSentences: [String] = []
        let defaultLetter = "S"
        
        let targetLetters = letters.isEmpty ? [defaultLetter] : letters
        
        for letter in targetLetters {
            let upperCaseLetter = letter.uppercased()
            if let sentences = practiceSentences[upperCaseLetter] {
                let shuffled = sentences.shuffled()
                let count = min(shuffled.count, 2)
                combinedSentences.append(contentsOf: shuffled.prefix(count))
            }
        }
        
        if combinedSentences.count < 3 {
             if let sentences = practiceSentences["S"] {
                 combinedSentences.append(contentsOf: sentences.prefix(2))
             }
            if let sentences = practiceSentences["R"] {
                combinedSentences.append(contentsOf: sentences.prefix(1))
            }
        }
        
        return combinedSentences.joined(separator: " ")
    }

    static func generateLongFormContent(for letters: [String]) -> String {
        let totalSentencesNeeded = 300 // Increased for 10-minute density
        var combinedSentences: [String] = []
        let defaultLetter = "S"
        let targetLetters = letters.isEmpty ? [defaultLetter] : letters
        
        var targetedPool: [String] = []
        for letter in targetLetters {
            if let sentences = practiceSentences[letter.uppercased()] {
                targetedPool.append(contentsOf: sentences)
            }
        }
        
        let genericPool = SentenceCorpus.genericSentences
        
        let targetCount = Int(Double(totalSentencesNeeded) * 0.4)
        let genericCount = totalSentencesNeeded - targetCount
        
        for _ in 0..<targetCount {
            if let sentence = targetedPool.randomElement() {
                combinedSentences.append(sentence)
            }
        }
        
        for _ in 0..<genericCount {
            if let sentence = genericPool.randomElement() {
                combinedSentences.append(sentence)
            }
        }
        
        combinedSentences.shuffle()
        return combinedSentences.joined(separator: " ")
    }
}
