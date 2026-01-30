//
//  ReadingTableViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 27/11/25.
//

import UIKit

class ReadingTableViewController: UITableViewController {

    private var textForDetailView: String = ""
    private var titleForDetailView: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellTitle = presetTitles[indexPath.row]
    
        if indexPath.row == 0 {
            // Daily Challenge (AI Generated)
            let cellTitle = presetTitles[indexPath.row]
            let troubledLetters = LogManager.shared.getTopStruggledLetters(limit: 5)
            
            // Show Loading Indicator
            let alert = UIAlertController(title: "Creative Mode", message: "Writing a unique story for you...", preferredStyle: .alert)
            self.present(alert, animated: true)
            
            Task {
                do {
                    // Try AI Generation
                    let story = try await AIParagraphGenerator.shared.generate(for: troubledLetters)
                    
                    // Dismiss Loading -> Show Content
                    alert.dismiss(animated: true) { [weak self] in
                        self?.textForDetailView = story
                        self?.titleForDetailView = cellTitle
                        self?.presentModal(withTitle: cellTitle)
                    }
                } catch {
                    // Fallback to Offline Corpus
                    print("AI Failed, using Fallback: \(error)")
                    alert.dismiss(animated: true) { [weak self] in
                        let fallbackContent = PhonemeContent.generateLongFormContent(for: troubledLetters)
                        self?.textForDetailView = fallbackContent
                        self?.titleForDetailView = cellTitle
                        self?.presentModal(withTitle: cellTitle)
                    }
                }
            }
            
        } else if indexPath.row > 0 && indexPath.row < 10 {
            self.textForDetailView = presetContent[indexPath.row]
            self.titleForDetailView = cellTitle
            presentModal(withTitle: cellTitle)
            
        } else if indexPath.row == 10 {
            self.titleForDetailView = cellTitle
            presentTextInputModal()
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
    func presentModal(withTitle title: String) {
            guard let modalNav = storyboard?.instantiateViewController(withIdentifier: "ModalNavigationController") as? UINavigationController,
                  let modalVC = modalNav.topViewController as? ModalViewController else {return}
            
            modalVC.modalTitle = title
            
            modalVC.onDoneButtonTapped = { [weak self] in
                self?.showDetailScreen()
            }
            
            if let sheet = modalNav.sheetPresentationController {
                let customDetent = UISheetPresentationController.Detent.custom { context in
                    return 200 // custom height
                }
                sheet.detents = [customDetent]
            }
            self.present(modalNav, animated: true, completion: nil)
        }
    
   func presentTextInputModal() {
        guard let modalNav = storyboard?.instantiateViewController(withIdentifier: "TextInputNavigationController") as? UINavigationController,
              let textInputVC = modalNav.topViewController as? TextInputViewController else {
            return
        }

        if let sheet = modalNav.sheetPresentationController {
            let customDetent = UISheetPresentationController.Detent.custom { context in
                return 500
            }
            sheet.detents = [customDetent]
            sheet.prefersGrabberVisible = false
        }

        textInputVC.onDoneButtonTapped = { [weak self] (enteredText) in
            self?.textForDetailView = enteredText
            self?.showDetailScreen()
        }
        
        self.present(modalNav, animated: true, completion: nil)
       
           textInputVC.onEmptyInput = { [weak self] in
               self?.showEmptyInputAlert()
           }
    }
    
    func showDetailScreen() {
        guard let detailVC = storyboard?.instantiateViewController(withIdentifier: "DetailVC") as? DetailViewController else {
            return
        }
        
        detailVC.textToDisplay = self.textForDetailView
        detailVC.titleToDisplay = self.titleForDetailView

        let detailNav = UINavigationController(rootViewController: detailVC)
        detailNav.modalPresentationStyle = .fullScreen
        self.present(detailNav, animated: true, completion: nil)
    }
    
    func showEmptyInputAlert() {
        let alert = UIAlertController(
            title: "No Text Entered",
            message: "Please enter some text.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }


}
