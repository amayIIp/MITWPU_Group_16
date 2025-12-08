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
        // Do any additional setup after loading the view.
    }
    
    @objc func didTapClose() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func didTapDone() {
        self.dismiss(animated: true) {
            self.onDoneButtonTapped?()
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
