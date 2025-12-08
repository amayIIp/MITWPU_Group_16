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
        // Do any additional setup after loading the view.
    }
    
    
    @objc func didTapCloseResult() {
        if let initialPresenter = self.presentingViewController?.presentingViewController {
            // Ask A to dismiss everything it presented (B and B's presented child, C)
            initialPresenter.dismiss(animated: true, completion: nil)
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
}
