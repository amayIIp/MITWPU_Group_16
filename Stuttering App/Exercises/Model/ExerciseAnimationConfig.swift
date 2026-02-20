//
//  ExerciseAnimationConfig.swift
//  Stuttering App 1
//
//  Animation configuration system for exercise text animations
//

import Foundation

enum ExerciseType {
    case imageBased
    case animationBased
    case hybrid
    case textOnly
}

enum AnimationType {
    case fullWord
    case fadeSecondPart
    case highlightFirst
    case elongate
    case prefixedWord
    case transition
}

struct AnimationSubstep {
    let type: AnimationType
    let duration: TimeInterval
    let delay: TimeInterval
    
    init(type: AnimationType, duration: TimeInterval = 1.0, delay: TimeInterval = 0.0) {
        self.type = type
        self.duration = duration
        self.delay = delay
    }
}

struct StepAnimationConfig {
    let stepNumber: Int
    let showImage: Bool
    let substeps: [AnimationSubstep]
    let autoAdvance: Bool
    
    init(stepNumber: Int, showImage: Bool = false, substeps: [AnimationSubstep], autoAdvance: Bool = false) {
        self.stepNumber = stepNumber
        self.showImage = showImage
        self.substeps = substeps
        self.autoAdvance = autoAdvance
    }
}

struct ExerciseAnimationTemplate {
    let exerciseTitle: String
    let exerciseType: ExerciseType
    let stepConfigs: [StepAnimationConfig]
}

class ExerciseAnimationRegistry {
    
    static let shared = ExerciseAnimationRegistry()
    private var templates: [String: ExerciseAnimationTemplate] = [:]
    
    private init() {
        registerAllExercises()
    }
    
    private func registerAllExercises() {
        
        // ==========================================
        // EXERCISE 1.1 - Image-Based (Traditional)
        // ==========================================
        templates["Airflow Practice"] = ExerciseAnimationTemplate(
            exerciseTitle: "Airflow Practice",
            exerciseType: .imageBased,
            stepConfigs: []  // No animation configs needed
        )
        
        // ==========================================
        // EXERCISE 1.2 - Animation-Based
        // Input: "Ba-by"
        // Step 1: "Baby" -> "B(1.0)aby(0.5)" -> "Ba"
        // Step 2: "Baaaa..."
        // Step 3: "Baaaby" -> "Baby"
        // ==========================================
        templates["Flexible Pacing"] = ExerciseAnimationTemplate(
            exerciseTitle: "Flexible Pacing",
            exerciseType: .animationBased,
            stepConfigs: [
                StepAnimationConfig(
                    stepNumber: 1,
                    showImage: false,
                    substeps: [
                        AnimationSubstep(type: .fullWord, duration: 1.5, delay: 0.0),
                        AnimationSubstep(type: .fadeSecondPart, duration: 1.0, delay: 0.3),
                        AnimationSubstep(type: .highlightFirst, duration: 1.0, delay: 0.3)
                    ],
                    autoAdvance: false
                ),
                StepAnimationConfig(
                    stepNumber: 2,
                    showImage: false,
                    substeps: [
                        AnimationSubstep(type: .elongate, duration: 2.0, delay: 0.0)
                    ],
                    autoAdvance: false
                ),
                StepAnimationConfig(
                    stepNumber: 3,
                    showImage: false,
                    substeps: [
                        AnimationSubstep(type: .prefixedWord, duration: 1.5, delay: 0.0),
                        AnimationSubstep(type: .fullWord, duration: 1.0, delay: 0.3)
                    ],
                    autoAdvance: false
                )
            ]
        )
        
        // ==========================================
        // EXERCISE 2.1 - Hybrid (Image + Animations)
        // Step 1: Image shown, no text
        // Step 2: "Baby" -> "B(1.0)aby(0.5)" -> "Ba" -> "Baaaa..."
        // Step 3: "Baaaby" -> "Baby"
        // ==========================================
        templates["Gentle Onset"] = ExerciseAnimationTemplate(
            exerciseTitle: "Gentle Onset",
            exerciseType: .hybrid,
            stepConfigs: [
                StepAnimationConfig(
                    stepNumber: 1,
                    showImage: true,
                    substeps: [],  // No text animations
                    autoAdvance: false
                ),
                StepAnimationConfig(
                    stepNumber: 2,
                    showImage: false,
                    substeps: [
                        AnimationSubstep(type: .fullWord, duration: 1.5, delay: 0.0),
                        AnimationSubstep(type: .fadeSecondPart, duration: 1.0, delay: 0.3),
                        AnimationSubstep(type: .highlightFirst, duration: 1.0, delay: 0.3),
                        AnimationSubstep(type: .elongate, duration: 1.5, delay: 0.3)
                    ],
                    autoAdvance: false
                ),
                StepAnimationConfig(
                    stepNumber: 3,
                    showImage: false,
                    substeps: [
                        AnimationSubstep(type: .prefixedWord, duration: 1.5, delay: 0.0),
                        AnimationSubstep(type: .fullWord, duration: 1.0, delay: 0.3)
                    ],
                    autoAdvance: false
                )
            ]
        )
        
        // ==========================================
        // EXERCISE 2.2 - Image-Based (Traditional)
        // ==========================================
        templates["Light Contacts"] = ExerciseAnimationTemplate(
            exerciseTitle: "Light Contacts",
            exerciseType: .imageBased,
            stepConfigs: []
        )
        
        // ==========================================
        // EXERCISE 2.3 - Animation-Based
        // Step 1: "Baby" -> "Baaaa..."
        // Step 2: "Baaaby" -> "Baby"
        // ==========================================
        templates["Prolongation"] = ExerciseAnimationTemplate(
            exerciseTitle: "Prolongation",
            exerciseType: .animationBased,
            stepConfigs: [
                StepAnimationConfig(
                    stepNumber: 1,
                    showImage: false,
                    substeps: [
                        AnimationSubstep(type: .fullWord, duration: 1.5, delay: 0.0),
                        AnimationSubstep(type: .elongate, duration: 1.5, delay: 0.3)
                    ],
                    autoAdvance: false
                ),
                StepAnimationConfig(
                    stepNumber: 2,
                    showImage: false,
                    substeps: [
                        AnimationSubstep(type: .prefixedWord, duration: 1.5, delay: 0.0),
                        AnimationSubstep(type: .fullWord, duration: 1.0, delay: 0.3)
                    ],
                    autoAdvance: false
                )
            ]
        )
        
        // ==========================================
        // EXERCISES 3.1, 3.2, 3.3 - Toolkit
        // ==========================================
        templates["Preparatory Set"] = ExerciseAnimationTemplate(
            exerciseTitle: "Preparatory Set",
            exerciseType: .textOnly,
            stepConfigs: []
        )
        
        templates["Pull-Out"] = ExerciseAnimationTemplate(
            exerciseTitle: "Pull-Out",
            exerciseType: .textOnly,
            stepConfigs: []
        )
        
        templates["Block Correction"] = ExerciseAnimationTemplate(
            exerciseTitle: "Block Correction",
            exerciseType: .textOnly,
            stepConfigs: []
        )
        
        templates["Tongue Twisters"] = ExerciseAnimationTemplate(
            exerciseTitle: "Tongue Twisters",
            exerciseType: .textOnly,
            stepConfigs: []
        )
        
        templates["Video Diary"] = ExerciseAnimationTemplate(
            exerciseTitle: "Video Diary",
            exerciseType: .textOnly,
            stepConfigs: []
        )
        
        templates["Story Cubes"] = ExerciseAnimationTemplate(
            exerciseTitle: "Story Cubes",
            exerciseType: .textOnly,
            stepConfigs: []
        )
    }
    
    func getTemplate(for exerciseTitle: String) -> ExerciseAnimationTemplate? {
        return templates[exerciseTitle]
    }
}
