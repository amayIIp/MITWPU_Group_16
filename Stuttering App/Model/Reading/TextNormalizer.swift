import Foundation

/// Turns reference paragraphs and speech transcripts into comparable token
/// streams.
///
/// Alignment can only be as good as the tokens fed to it. Three differences
/// between the paragraph on screen and the words a recogniser writes down are
/// not reading errors at all, and every one of them used to surface as a
/// stutter:
///
/// 1. **Spelling variety.** The reading corpus is written in British English
///    ("civilisation", "behaviour", "centre") while `openai_whisper-small.en`
///    is American. Both sides are folded to one variety here.
/// 2. **Punctuation inside words.** Splitting on every punctuation mark turned
///    "don't" into `don` + `t` and "D.N.A." into three one-letter tokens, all
///    of which entered the word count and the letter histogram.
/// 3. **Digits versus words.** "5" and "five" are the same spoken word.
///
/// Hyphens are the deliberate exception to rule 2: they are split, not kept.
/// A recogniser may write "light years" where the paragraph has "light-years",
/// so splitting both sides makes them match, while keeping both would not.
enum TextNormalizer {

    // MARK: - Tokenising

    /// Lowercased, spelling-folded, punctuation-stripped words in reading order.
    static func tokenize(_ text: String) -> [String] {
        tokenizeWithBoundaries(text).words
    }

    /// Punctuation that ends a clause or sentence, and so licenses a pause.
    private static let boundaryPunctuation: Set<Character> = [
        ".", ",", ";", ":", "!", "?", "\u{2013}", "\u{2014}"
    ]

    /// Tokens plus, for each one, whether the paragraph puts a clause or
    /// sentence break immediately after it.
    ///
    /// Block detection needs this. A silence before a word means something very
    /// different depending on whether a comma or full stop precedes it: after
    /// punctuation the reader is pausing as written, and flagging that as a
    /// disfluency would penalise reading the paragraph correctly.
    static func tokenizeWithBoundaries(_ text: String) -> (words: [String], endsClause: [Bool]) {
        // Em and en dashes are clause breaks, but the corpus writes them
        // unspaced ("works—not"), so they are spaced out here to become their
        // own token and then folded onto the word before them.
        let flattened = text
            .precomposedStringWithCanonicalMapping
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")   // curly apostrophe
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "-", with: " ")          // word-internal hyphen
            .replacingOccurrences(of: "\u{2013}", with: " \u{2013} ")
            .replacingOccurrences(of: "\u{2014}", with: " \u{2014} ")

        var words: [String] = []
        var endsClause: [Bool] = []

        for raw in flattened.split(whereSeparator: { $0.isWhitespace }) {
            let hasBoundary = raw.contains { boundaryPunctuation.contains($0) }

            // Keep letters, digits and apostrophes; drop everything else. This
            // folds "d.n.a." to "dna" and leaves "don't" intact.
            var cleaned = String(raw.filter { $0.isLetter || $0.isNumber || $0 == "'" })
            while cleaned.hasPrefix("'") { cleaned.removeFirst() }
            while cleaned.hasSuffix("'") { cleaned.removeLast() }

            guard !cleaned.isEmpty else {
                // A bare punctuation token (a spaced-out dash) marks the word
                // before it rather than producing a token of its own.
                if hasBoundary, !endsClause.isEmpty { endsClause[endsClause.count - 1] = true }
                continue
            }

            let emitted: [String]
            if let spelled = numberWords(cleaned) {
                emitted = spelled
            } else {
                emitted = [spellingMap[cleaned] ?? cleaned]
            }

            for (offset, word) in emitted.enumerated() {
                words.append(word)
                // Only the last token of an expanded number carries the break.
                endsClause.append(hasBoundary && offset == emitted.count - 1)
            }
        }
        return (words, endsClause)
    }

    /// One normalised form per whitespace-separated word of `text`, in the
    /// same order and with the same count.
    ///
    /// `tokenize` is the wrong tool for tracking where a reader is on screen:
    /// it splits hyphenated words and expands numbers, so its indices drift
    /// away from the words the highlight has to paint. This keeps a strict 1:1
    /// correspondence with a `\S+` scan of the same string, so index *n* here
    /// is index *n* there.
    ///
    /// A token that is pure punctuation yields an empty string, which matches
    /// nothing and is simply stepped over.
    static func displayWordForms(_ text: String) -> [String] {
        text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: { $0.isWhitespace })
            .map { raw -> String in
                let lowered = raw.lowercased()
                    .replacingOccurrences(of: "\u{2019}", with: "'")
                    .replacingOccurrences(of: "\u{2018}", with: "'")

                // A hyphenated word is one word on screen. Compare on its
                // first part, which is what the reader says first.
                let firstPart = lowered
                    .split(whereSeparator: { $0 == "-" || $0 == "\u{2013}" || $0 == "\u{2014}" })
                    .first.map(String.init) ?? lowered

                var cleaned = String(firstPart.filter { $0.isLetter || $0.isNumber || $0 == "'" })
                while cleaned.hasPrefix("'") { cleaned.removeFirst() }
                while cleaned.hasSuffix("'") { cleaned.removeLast() }
                guard !cleaned.isEmpty else { return "" }

                // "5" on the page is "five" out loud.
                if let spelled = numberWords(cleaned), let first = spelled.first { return first }
                return spellingMap[cleaned] ?? cleaned
            }
    }

    // MARK: - Syllables

    /// Vowel-group syllable estimate.
    ///
    /// Clinical fluency is measured per syllable rather than per word, because
    /// a long word offers more opportunities to stutter than a short one. This
    /// is the cheap English approximation — good enough to make the denominator
    /// meaningful, and it needs no pronunciation dictionary.
    static func syllableCount(_ word: String) -> Int {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y"]
        let lower = word.lowercased()

        var groups = 0
        var previousWasVowel = false
        for character in lower {
            let isVowel = vowels.contains(character)
            if isVowel && !previousWasVowel { groups += 1 }
            previousWasVowel = isVowel
        }

        // Trailing silent 'e' ("stone" is one syllable, "table" is two).
        if groups > 1, lower.count > 2, lower.hasSuffix("e"), !lower.hasSuffix("le") {
            groups -= 1
        }
        return max(1, groups)
    }

    /// Total syllables across a token stream.
    static func syllableCount(of words: [String]) -> Int {
        words.reduce(0) { $0 + syllableCount($1) }
    }

    // MARK: - Numbers

    private static let onesWords = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
        "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
        "sixteen", "seventeen", "eighteen", "nineteen"
    ]
    private static let tensWords = [
        "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"
    ]

    /// Spells out an integer token of 100 or less, so "5" and "five" align.
    ///
    /// Deliberately stops at 100. Larger numbers — years especially — have no
    /// single spoken form ("1969" is "nineteen sixty-nine", not "one thousand
    /// nine hundred and sixty-nine"), and both recognisers write them back as
    /// digits, so leaving them alone is what actually makes them match.
    private static func numberWords(_ token: String) -> [String]? {
        guard token.allSatisfy({ $0.isNumber }), let value = Int(token), value >= 0, value <= 100 else {
            return nil
        }
        if value < 20 { return [onesWords[value]] }
        if value == 100 { return ["one", "hundred"] }
        let tens = tensWords[value / 10]
        let ones = value % 10
        return ones == 0 ? [tens] : [tens, onesWords[ones]]
    }

    // MARK: - Spelling variants

    /// British → American spellings, so one variety reaches the aligner.
    ///
    /// The direction is arbitrary; what matters is that both the paragraph and
    /// the transcript are folded the same way.
    private static let spellingMap: [String: String] = buildSpellingMap()

    private static func buildSpellingMap() -> [String: String] {
        var map: [String: String] = [:]

        // ── -ise / -isation → -ize / -ization ─────────────────────────────
        // Only verbs that genuinely take both spellings. Words that are always
        // "-ise" in both varieties (advise, promise, exercise, surprise,
        // compromise, supervise, improvise, franchise, merchandise, televise,
        // disguise, despise, revise, devise, arise, wise, rise, precise,
        // concise, otherwise, likewise) are absent by construction.
        let iseVerbs = [
            "realise", "organise", "recognise", "apologise", "criticise", "emphasise",
            "authorise", "characterise", "civilise", "colonise", "customise", "dramatise",
            "economise", "energise", "equalise", "familiarise", "finalise", "formalise",
            "generalise", "globalise", "harmonise", "hospitalise", "idealise",
            "industrialise", "initialise", "itemise", "jeopardise", "legalise",
            "liberalise", "localise", "maximise", "memorise", "minimise", "mobilise",
            "modernise", "moralise", "nationalise", "neutralise", "normalise",
            "optimise", "personalise", "polarise", "prioritise", "privatise",
            "publicise", "randomise", "rationalise", "revitalise", "revolutionise",
            "socialise", "specialise", "stabilise", "standardise", "sterilise",
            "stigmatise", "subsidise", "summarise", "symbolise", "sympathise",
            "synchronise", "synthesise", "systematise", "terrorise", "theorise",
            "urbanise", "utilise", "verbalise", "victimise", "visualise", "vocalise",
            "westernise", "modularise", "popularise", "sensationalise"
        ]
        for verb in iseVerbs {
            let britishStem = String(verb.dropLast())            // "realis"
            let americanStem = britishStem.dropLast() + "z"      // "realiz"
            for suffix in ["e", "es", "ed", "ing", "er", "ers", "ation", "ations"] {
                map[britishStem + suffix] = americanStem + suffix
            }
        }

        // ── -yse → -yze ───────────────────────────────────────────────────
        for verb in ["analyse", "paralyse", "catalyse"] {
            let britishStem = String(verb.dropLast())
            let americanStem = britishStem.dropLast() + "z"
            for suffix in ["e", "es", "ed", "ing", "er", "ers"] {
                map[britishStem + suffix] = americanStem + suffix
            }
        }

        // ── -our → -or ────────────────────────────────────────────────────
        // An allowlist, not a rule: "four", "hour", "your", "pour", "tour",
        // "flour" and "devour" must never be touched.
        let ourWords = [
            "colour", "behaviour", "favour", "honour", "labour", "neighbour",
            "humour", "rumour", "vapour", "harbour", "flavour", "endeavour",
            "splendour", "valour", "armour", "odour", "parlour", "saviour",
            "tumour", "candour", "clamour", "rigour", "vigour", "savour",
            "succour", "demeanour", "fervour", "ardour", "arbour", "rancour"
        ]
        for word in ourWords {
            let american = String(word.dropLast(3)) + "or"
            for suffix in ["", "s", "ed", "ing", "ful", "fully", "less", "able",
                           "ist", "ists", "ism", "al", "ally", "ite", "ites"] {
                map[word + suffix] = american + suffix
            }
        }

        // ── -re → -er ─────────────────────────────────────────────────────
        let reWords = [
            "centre", "theatre", "amphitheatre", "metre", "kilometre", "centimetre",
            "millimetre", "litre", "millilitre", "fibre", "calibre", "sombre",
            "spectre", "lustre", "meagre", "ochre", "sabre", "mitre", "louvre",
            "sepulchre"
        ]
        for word in reWords {
            let american = String(word.dropLast(2)) + "er"
            let britishStem = String(word.dropLast())            // "centr"
            map[word] = american
            map[word + "s"] = american + "s"
            map[britishStem + "ed"] = american + "ed"            // centred → centered
            map[britishStem + "ing"] = american + "ing"          // centring → centering
        }

        // ── Irregulars ────────────────────────────────────────────────────
        let irregulars: [String: String] = [
            "aluminium": "aluminum", "grey": "gray", "greyish": "grayish",
            "programme": "program", "programmes": "programs",
            "practise": "practice", "practised": "practiced", "practising": "practicing",
            "cheque": "check", "cheques": "checks",
            "tyre": "tire", "tyres": "tires",
            "plough": "plow", "ploughed": "plowed", "ploughing": "plowing",
            "draught": "draft", "draughts": "drafts",
            "storey": "story", "storeys": "stories",
            "jewellery": "jewelry", "jeweller": "jeweler",
            "mould": "mold", "moulded": "molded", "moulding": "molding",
            "moustache": "mustache", "pyjamas": "pajamas",
            "sceptical": "skeptical", "scepticism": "skepticism", "sceptic": "skeptic",
            "aeroplane": "airplane",
            "defence": "defense", "offence": "offense",
            "pretence": "pretense", "licence": "license",
            "whilst": "while", "amongst": "among",
            "learnt": "learned", "spelt": "spelled", "burnt": "burned",
            "dreamt": "dreamed", "leapt": "leaped",
            "kerb": "curb", "gaol": "jail",
            "catalogue": "catalog", "catalogues": "catalogs",
            "dialogue": "dialog", "dialogues": "dialogs",
            "monologue": "monolog", "monologues": "monologs",
            "travelled": "traveled", "travelling": "traveling", "traveller": "traveler",
            "cancelled": "canceled", "cancelling": "canceling",
            "labelled": "labeled", "labelling": "labeling",
            "modelled": "modeled", "modelling": "modeling",
            "fuelled": "fueled", "signalled": "signaled", "totalled": "totaled",
            "marvellous": "marvelous", "counsellor": "counselor",
            "enrol": "enroll", "enrolment": "enrollment",
            "fulfil": "fulfill", "fulfilment": "fulfillment",
            "skilful": "skillful", "wilful": "willful",
            "instalment": "installment", "appal": "appall",
            "distil": "distill", "instil": "instill",
            "encyclopaedia": "encyclopedia", "mediaeval": "medieval",
            "foetus": "fetus", "oestrogen": "estrogen",
            "anaemia": "anemia", "anaesthetic": "anesthetic",
            "manoeuvre": "maneuver", "manoeuvres": "maneuvers",
            "manoeuvred": "maneuvered", "manoeuvring": "maneuvering"
        ]
        map.merge(irregulars) { _, new in new }

        return map
    }
}
