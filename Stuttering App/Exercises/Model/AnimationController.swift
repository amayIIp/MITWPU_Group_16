//
//  AnimationController.swift
//  Stuttering App 1
//
//  Controls execution of animation sequences
//

import UIKit

protocol AnimationControllerDelegate: AnyObject {
    func didUpdateText(_ attributedText: NSAttributedString)
    func didCompleteStep(shouldAutoAdvance: Bool)
    func shouldHideTargetLabel(_ hide: Bool)
}

class AnimationController {
    
    weak var delegate: AnimationControllerDelegate?
    
    private var textBuilder: TextAnimationBuilder?
    private var currentConfig: StepAnimationConfig?
    private var substepIndex: Int = 0
    private var workItems: [DispatchWorkItem] = []
    
    
    func startAnimation(for stepConfig: StepAnimationConfig, word: String) {
        // Cancel any ongoing animations
        cancelAnimations()
        
        // Initialize text builder with the word
        textBuilder = TextAnimationBuilder(syllableWord: word)
        currentConfig = stepConfig
        substepIndex = 0
        
        // Check if this step shows an image instead of animations
        if stepConfig.showImage {
            delegate?.shouldHideTargetLabel(true)
            return
        }
        
        executeSubstepSequence()
    }
    
    func cancelAnimations() {
        workItems.forEach { $0.cancel() }
        workItems.removeAll()
        substepIndex = 0
    }
    
    private func executeSubstepSequence() {
        guard let config = currentConfig,
              let builder = textBuilder else { return }
        
        // Show target label
        delegate?.shouldHideTargetLabel(false)
        
        // Iterate through all substeps
        for (index, substep) in config.substeps.enumerated() {
            let totalDelay = calculateTotalDelay(upToIndex: index)
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.executeSubstep(substep, builder: builder, isLast: index == config.substeps.count - 1)
            }
            
            workItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay, execute: workItem)
        }
    }
    
    private func executeSubstep(_ substep: AnimationSubstep, builder: TextAnimationBuilder, isLast: Bool) {
        let attributedText = builder.generateText(for: substep.type)
        
        
        UIView.transition(
            with: UIView(),
            duration: 0.3,
            options: .transitionCrossDissolve,
            animations: {
                self.delegate?.didUpdateText(attributedText)
            },
            completion: { _ in
                if isLast {
                    self.handleStepCompletion()
                }
            }
        )
    }
    
    private func handleStepCompletion() {
        guard let config = currentConfig else { return }
        
        if config.autoAdvance {
            let workItem = DispatchWorkItem { [weak self] in
                self?.delegate?.didCompleteStep(shouldAutoAdvance: true)
            }
            workItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
        } else {
            delegate?.didCompleteStep(shouldAutoAdvance: false)
        }
    }
    
    private func calculateTotalDelay(upToIndex index: Int) -> TimeInterval {
        guard let config = currentConfig else { return 0 }
        
        var totalDelay: TimeInterval = 0
        
        for i in 0..<index {
            let substep = config.substeps[i]
            totalDelay += substep.delay + substep.duration
        }
        
        if index < config.substeps.count {
            totalDelay += config.substeps[index].delay
        }
        
        return totalDelay
    }
}
