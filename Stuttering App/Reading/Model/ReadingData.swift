//
//  ReadingData.swift
//  Stuttering App
//
//  Created by sdc - user on 26/11/25.
//

import Foundation

let presetTitles = [ //Indexing Sections
    "Daily Challenge",
    "Science",
    "Culture",
    "Sports",
    "Festival",
    "History",
    "Mindset",
    "Travel",
    "Technology",
    "Nature",
    "Custom"
]

let presetContent = [
    // Daily Challenge (Dynamic)
    "Daily Challenge Content Placeholder",

    // Science
    """
    Science uncovers the hidden structure of the universe, slowly pulling back layers of mystery through observation, experimentation, and relentless curiosity. It is a long conversation between humanity and nature, where every discovery invites further questions and every answer opens yet another corridor of possibility. From the arrangement of particles deep inside atoms to the behaviour of galaxies millions of light-years away, science attempts to describe, predict, and understand how the world works—not in vague impressions, but in precise, testable explanations. This clarity gives science its power: it allows ideas to be challenged, improved, replaced, and strengthened across generations.

    At its heart, science is a method, a disciplined way of thinking rooted in evidence rather than intuition alone. A scientist proposes a hypothesis, tests it under controlled conditions, collects data, refines the hypothesis, tests again, and slowly shapes a model that reflects reality. This cycle sits at the centre of all scientific progress, echoing through physics, chemistry, biology, astronomy, geology, and every branch of inquiry. Even failed experiments carry immense value, because they push thinking away from assumptions and closer to truth. Science thrives on repeatability—if a claim is valid, any trained observer should be able to verify it. This shared standard keeps the field honest, transparent, and self-correcting.

    Across time, scientific progress has rebuilt the foundations of civilisation. The development of mathematics made measurement and engineering possible. Astronomy revealed Earth’s place in a vast, expanding cosmos. Chemistry unlocked the structure of matter. Biology explained the deep connection between all living organisms and revealed the fragile balance that sustains life. Physics redefined our understanding of energy, space, and time, while computing transformed how information flows across societies. Medicine has turned once-fatal diseases into preventable or treatable conditions. Agricultural science feeds billions. Environmental science warns us when ecosystems reach critical thresholds. Neuroscience probes the architecture of thought and consciousness itself.

    Science is not just a body of knowledge—it is a shared human endeavour. Researchers collaborate across borders, cultures, and disciplines, creating a network of collective intelligence. A discovery in one field can reshape another. Breakthroughs in quantum mechanics influence computing. Advances in biology inform environmental restoration. Knowledge radiates outward, weaving a larger and more interconnected understanding of the world. The influence of science extends into everyday life more than most people notice. Communication, transportation, health systems, and simple household technologies all rest on scientific foundations. Science also shapes thinking. It teaches people to question assumptions, accept uncertainty, and revise beliefs when new evidence emerges. No scientific idea is ever final. Each one is a stepping stone toward deeper insight. Despite challenges, science remains one of humanity’s most hopeful paths forward, guiding societies toward wiser progress and deeper understanding.

    Consider the vastness of the deep ocean, still largely unexplored, or the complexity of the human genome. Every time we sequence a new strand of DNA or launch a telescope like James Webb, we are engaging in the scientific tradition of seeking the unknown. The rigor of peer review ensures that only the most robust theories stand the test of time, while the spirit of exploration drives us to look beyond our current horizons.
    """,

    // Culture
    """
    Culture shapes identity through shared beliefs, art forms, customs, languages, and ways of expression that carry the memory of communities across generations. It offers individuals belonging, grounding them in stories, rituals, and creative traditions that define who they are and where they come from. Through music, dance, literature, cuisine, clothing, and architecture, culture becomes visible and tangible in everyday life. Cultural diversity expands understanding by exposing people to different worldviews, values, and aesthetics. Each tradition reflects a unique response to environment, history, and social structure.

    As time moves forward, culture evolves. Classical forms merge with modern ideas, creating new styles and hybrid expressions. This evolution keeps traditions alive rather than frozen in the past. Culture also acts as a bridge between generations, passing wisdom, lessons, and identity forward. It helps communities preserve memory during times of rapid change. Understanding culture builds empathy, respect, and connection between different groups. It reduces fear of the unfamiliar and encourages meaningful dialogue. Shared cultural spaces—festivals, theatres, galleries, and public rituals—strengthen social bonds. They remind people of their collective humanity.

    In a globalised world, cultural literacy becomes essential for cooperation. Respecting differences while celebrating common values creates inclusive societies. Culture continues to grow when communities honour the past while embracing new expressions. Consider how global trade has brought distant cuisines to our doorsteps, or how digital media allows a local artist in a small village to share their work with millions. This interconnectedness does not erase culture; rather, it allows for a vibrant exchange where we learn to appreciate the nuances of different lifestyles.

    Language is perhaps the most profound cultural tool. It holds the idioms and nuances that explain a people's relationship with their world. When a language is preserved, a way of seeing the world is preserved with it. Folklore and mythology provide the moral compass for many societies, offering allegories that remain relevant even in the digital age. By participating in culture, we contribute to a living tapestry that is constantly being rewoven by the hands of every new generation.
    """,

    // Sports (Continued expansion...)
    """
    Sports bring movement, discipline, and teamwork into everyday life. They teach individuals how to handle pressure, overcome setbacks, and celebrate both effort and achievement. Through consistent training, athletes develop resilience, focus, and strategic thinking. These qualities transfer into academics, careers, and personal habits. Sports encourage goal-setting and long-term commitment. Improvement comes from patience, repetition, and feedback.

    Beyond individual growth, sports strengthen community bonds. Fans, teammates, and families unite through shared excitement and emotional investment. Local tournaments and global competitions create collective identity. They inspire pride and belonging. Sports promote physical well-being and mental balance. Regular activity reduces stress and supports long-term health. Fair play teaches ethics, respect, and humility. Losses build character just as much as victories.

    In the modern era, sports have become a universal language. Whether it is a soccer match in a rural field or a high-stakes Olympic final, the spirit of competition remains the same. It is a testament to human potential—the desire to run faster, jump higher, and grow stronger. This pursuit of excellence inspires millions to push past their own limits. Sports also provide a platform for social change, highlighting issues of equality and representation on a global stage.

    Teamwork in sports mirrors the collaborative nature of modern society. Learning to rely on a teammate, to communicate under pressure, and to sacrifice personal glory for the success of the group are vital life lessons. The discipline of a morning practice or the focus required to execute a complex play builds a mental toughness that serves athletes long after they leave the field.
    """,
    
    // Festival
    """
    Festivals mark the rhythm of the year, breaking the monotony of daily life with outbursts of colour, music, and shared joy. They connect communities to their history, religion, and harvest cycles. From the lantern-lit skies of Diwali to the rhythmic drumming of carnival, every festival tells a story of triumph, gratitude, or renewal. They are times when strangers become friends, and streets transform into stages for collective celebration.
    """,

    // History
    """
    History is the map of human experience, charting the rise and fall of empires, the evolution of ideas, and the quiet struggles of ordinary people. It is not just a collection of dates, but a continuous narrative that explains why the world looks the way it does today. Studying history builds wisdom, helping us avoid past mistakes and appreciate the sacrifices made for the freedoms we enjoy. It reminds us that change is the only constant.
    """,

    // Mindset
    """
    Mindset determines how we navigate challenges. A growth mindset views failure not as a dead end, but as a necessary step toward mastery. It transforms obstacles into opportunities for learning. Cultivating resilience, gratitude, and curiosity allows individuals to adapt to an ever-changing world. Your internal dialogue shapes your external reality; believing in your capacity to improve is half the battle in achieving any goal.
    """,

    // Travel
    """
    Travel opens the mind like nothing else. Stepping into a foreign land, hearing a new language, and tasting unfamiliar food strips away prejudice. It forces you to adapt, to trust strangers, and to see your own life from a distance. The memories made while exploring—whether hiking a mountain at sunrise or navigating a bustling market—become part of who you are, expanding your understanding of the vast, diverse human family.
    """,

    // Technology
    """
    Technology has reshaped the landscape of human possibility. It has collapsed distances, making global communication instant and effortless. From the device in your pocket to the satellites orbiting Earth, technology drives progress in health, education, and commerce. However, it also challenges us to balance convenience with connection, ensuring that while we are digitally linked, we remain humanely grounded. The value of technology lies in how we use it to improve lives.
    """,

    // Nature
    """
    Nature is the ultimate artist and healer. The stillness of a forest, the rhythmic crash of ocean waves, and the vastness of a desert sky offer a profound sense of peace. Nature reminds us of our scale in the universe. It operates on cycles of growth, decay, and rebirth, teaching patience and resilience. Protecting the natural world is not just about survival; it is about preserving the beauty and balance that sustains our spirits.
    """
]
