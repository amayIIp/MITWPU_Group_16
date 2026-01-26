//
//  ReadingData.swift
//  Stuttering App
//
//  Created by sdc - user on 26/11/25.
//

import Foundation

let presetTitles = [ //Indexing Sections
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

    // Science
    """
    Science uncovers the hidden structure of the universe, slowly pulling back layers of mystery through observation, experimentation, and relentless curiosity. It is a long conversation between humanity and nature, where every discovery invites further questions and every answer opens yet another corridor of possibility.

    From the arrangement of particles deep inside atoms to the behaviour of galaxies millions of light-years away, science attempts to describe, predict, and understand how the world works—not in vague impressions, but in precise, testable explanations. This clarity gives science its power: it allows ideas to be challenged, improved, replaced, and strengthened across generations.

    At its heart, science is a method, a disciplined way of thinking rooted in evidence rather than intuition alone. A scientist proposes a hypothesis, tests it under controlled conditions, collects data, refines the hypothesis, tests again, and slowly shapes a model that reflects reality.

    This cycle sits at the centre of all scientific progress, echoing through physics, chemistry, biology, astronomy, geology, and every branch of inquiry. Even failed experiments carry immense value, because they push thinking away from assumptions and closer to truth.

    Science thrives on repeatability—if a claim is valid, any trained observer should be able to verify it. This shared standard keeps the field honest, transparent, and self-correcting.

    Across time, scientific progress has rebuilt the foundations of civilisation. The development of mathematics made measurement and engineering possible. Astronomy revealed Earth’s place in a vast, expanding cosmos.

    Chemistry unlocked the structure of matter. Biology explained the deep connection between all living organisms and revealed the fragile balance that sustains life.

    Physics redefined our understanding of energy, space, and time, while computing transformed how information flows across societies. Medicine has turned once-fatal diseases into preventable or treatable conditions.

    Agricultural science feeds billions. Environmental science warns us when ecosystems reach critical thresholds. Neuroscience probes the architecture of thought and consciousness itself.

    Science is not just a body of knowledge—it is a shared human endeavour. Researchers collaborate across borders, cultures, and disciplines, creating a network of collective intelligence.

    A discovery in one field can reshape another. Breakthroughs in quantum mechanics influence computing. Advances in biology inform environmental restoration.

    Knowledge radiates outward, weaving a larger and more interconnected understanding of the world.

    The influence of science extends into everyday life more than most people notice. Communication, transportation, health systems, and simple household technologies all rest on scientific foundations.

    Science also shapes thinking. It teaches people to question assumptions, accept uncertainty, and revise beliefs when new evidence emerges.

    No scientific idea is ever final. Each one is a stepping stone toward deeper insight.

    Despite challenges, science remains one of humanity’s most hopeful paths forward, guiding societies toward wiser progress and deeper understanding.
    """
,

    // Culture
    """
    Culture shapes identity through shared beliefs, art forms, customs, languages, and ways of expression that carry the memory of communities across generations.

    It offers individuals belonging, grounding them in stories, rituals, and creative traditions that define who they are and where they come from.

    Through music, dance, literature, cuisine, clothing, and architecture, culture becomes visible and tangible in everyday life.

    Cultural diversity expands understanding by exposing people to different worldviews, values, and aesthetics.

    Each tradition reflects a unique response to environment, history, and social structure.

    As time moves forward, culture evolves. Classical forms merge with modern ideas, creating new styles and hybrid expressions.

    This evolution keeps traditions alive rather than frozen in the past.

    Culture also acts as a bridge between generations, passing wisdom, lessons, and identity forward.

    It helps communities preserve memory during times of rapid change.

    Understanding culture builds empathy, respect, and connection between different groups.

    It reduces fear of the unfamiliar and encourages meaningful dialogue.

    Shared cultural spaces—festivals, theatres, galleries, and public rituals—strengthen social bonds.

    They remind people of their collective humanity.

    In a globalised world, cultural literacy becomes essential for cooperation.

    Respecting differences while celebrating common values creates inclusive societies.

    Culture continues to grow when communities honour the past while embracing new expressions.
    """
,

    // Sports
    """
    Sports bring movement, discipline, and teamwork into everyday life.

    They teach individuals how to handle pressure, overcome setbacks, and celebrate both effort and achievement.

    Through consistent training, athletes develop resilience, focus, and strategic thinking.

    These qualities transfer into academics, careers, and personal habits.

    Sports encourage goal-setting and long-term commitment.

    Improvement comes from patience, repetition, and feedback.

    Beyond individual growth, sports strengthen community bonds.

    Fans, teammates, and families unite through shared excitement and emotional investment.

    Local tournaments and global competitions create collective identity.

    They inspire pride and belonging.

    Sports promote physical well-being and mental balance.

    Regular activity reduces stress and supports long-term health.

    Fair play teaches ethics, respect, and humility.

    Losses build character just as much as victories.

    Sports remind people that growth comes from consistent effort.

    They celebrate perseverance and the courage to keep improving.
    """
,

    // Festival
    """
    Festivals give communities a chance to pause routine life and celebrate together.

    They bring people together through music, colour, rituals, storytelling, and shared meals.

    Each festival carries historical significance and symbolic meaning.

    Traditions are passed across generations, strengthening cultural identity.

    Festivals honour ancestors, harvests, seasons, and spiritual beliefs.

    They mark transitions and milestones in communal life.

    These celebrations strengthen relationships between families and neighbours.

    They spark gratitude and joy.

    Shared experiences create lasting memories.

    Modern festivals blend long-held customs with creative reinterpretations.

    New expressions keep celebrations relevant for younger generations.

    Inclusivity expands participation.

    Sustainability encourages mindful celebration.

    Festivals remind people that joy is amplified when shared.

    They show that heritage grows when communities embrace both past and future.

    Celebration becomes a bridge between tradition and innovation.
    """
,

    // History
    """
    History records the experiences, ideas, conflicts, and breakthroughs that shaped the world.

    It reveals patterns in human behaviour.

    Societies rise, adapt, struggle, and transform over time.

    By studying the past, individuals gain perspective.

    This perspective guides wiser decisions in the present.

    It also supports responsible planning for the future.

    Historical documents and artefacts preserve memory.

    Personal stories humanise large events.

    They connect people to shared heritage.

    History teaches lessons about leadership and justice.

    It highlights innovation and resilience.

    It also shows consequences of human choices.

    Understanding history encourages reflection.

    It builds critical thinking.

    Long-term awareness grows from historical insight.

    Thoughtful societies depend on remembering their past.
    """
,

    // Mindset
    """
    Mindset influences how people interpret challenges and opportunities.

    It shapes daily experiences and emotional responses.

    A growth-oriented mindset encourages continuous learning.

    Curiosity becomes a habit.

    Obstacles transform into development opportunities.

    Strengthening mindset involves noticing thoughts.

    Managing self-talk builds confidence.

    Reframing negativity supports resilience.

    Consistent improvement requires patience.

    A balanced mindset enhances focus.

    Emotional clarity improves relationships.

    Creativity flourishes with mental openness.

    Mindset supports long-term consistency.

    Adaptability becomes easier.

    Uncertainty becomes manageable.

    The right mental approach builds lasting growth.
    """
,

    // Travel
    """
    Travel introduces people to unfamiliar landscapes and cultures.

    It expands understanding of the world.

    Exposure to diversity nurtures appreciation.

    New languages and customs broaden perspective.

    Travel builds empathy.

    It shows different ways of living and problem-solving.

    Navigating unfamiliar environments strengthens confidence.

    Adaptability increases through experience.

    Travel encourages self-reflection.

    Personal transformation often follows exploration.

    Modern travel emphasizes responsibility.

    Respecting local communities becomes essential.

    Protecting natural spaces supports sustainability.

    Ethical tourism benefits host cultures.

    Travel deepens gratitude.

    It connects people to global humanity.
    """
,

    // Technology
    """
    Technology reshapes how people live and work.

    It simplifies tasks and enables creativity.

    Innovation accelerates problem-solving.

    Digital tools transform communication.

    Learning becomes more accessible.

    Industries evolve rapidly.

    AI and automation redefine productivity.

    Data systems influence decision-making.

    Technology empowers collaboration.

    Creativity expands through new platforms.

    Responsibility grows with capability.

    Privacy becomes a critical concern.

    Security demands constant attention.

    Digital well-being matters.

    Ethical use protects society.

    Progress remains beneficial when guided wisely.
    """
,

    // Nature
    """
    Nature offers perspective and calm.

    Forests, oceans, and mountains sustain life.

    Time outdoors restores emotional balance.

    Stress reduces through natural exposure.

    Creativity sparks through quiet observation.

    Ecosystems provide essentials.

    Clean air and water sustain health.

    Biodiversity supports resilience.

    Conservation protects fragile balance.

    Sustainable living becomes necessary.

    Observing nature deepens respect.

    The planet’s beauty inspires wonder.

    Responsibility grows through awareness.

    Protecting ecosystems safeguards the future.

    Harmony depends on stewardship.

    Nature reminds humanity of interdependence.
    """
]
