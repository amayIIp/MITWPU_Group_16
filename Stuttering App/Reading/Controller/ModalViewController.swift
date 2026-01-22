//
//  ModalViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 27/11/25.
//

import UIKit

class ModalViewController: UIViewController {

    var modalTitle: String = ""
    var onDoneButtonTapped: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "bg")

        self.navigationItem.title = modalTitle
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(didTapClose))
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "checkmark"), style: .prominent, target: self, action: #selector(didTapDone))
    }
    
    @objc func didTapClose() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func didTapDone() {
        self.dismiss(animated: true) {
            self.onDoneButtonTapped?()
        }
    }
}
