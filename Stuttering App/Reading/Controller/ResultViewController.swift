//
//  ResultViewController.swift
//  Stuttering App
//
//  Created by sdc - user on 29/11/25.
//

import UIKit

class ResultViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Result"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(didTapCloseResult))
    }
    
    @objc func didTapCloseResult() {
        if let initialPresenter = self.presentingViewController?.presentingViewController {
            initialPresenter.dismiss(animated: true, completion: nil)
        }
    }
}
