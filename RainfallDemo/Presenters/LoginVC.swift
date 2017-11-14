//
//  ViewController.swift
//  RainfallDemo
//
//  Created by Peoplelink on 11/13/17.
//  Copyright © 2017 Peoplelink. All rights reserved.
//

import UIKit
import MaterialComponents

class LoginVC: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var userNameField: MDCTextField!
    @IBOutlet weak var passwordField: MDCTextField!
    @IBOutlet weak var loginButton: MDCRaisedButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        userNameField.delegate = self
        passwordField.delegate = self

        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func loginButtonAction(sender: MDCButton) {
        view.endEditing(true)
        userNameField.trailingUnderlineLabel.text = (userNameField.text?.isEmpty)! ? "Please enter username" : ""
        passwordField.trailingUnderlineLabel.text = (passwordField.text?.isEmpty)! ? "Please enter password" : ""

        if !((userNameField.text?.isEmpty)!) && !((passwordField.text?.isEmpty)!) {
            let detailVC = DetailVC(nibName: "DetailVC", bundle: nil)
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField == userNameField ? (userNameField.trailingUnderlineLabel.text =  "" ) : (passwordField.trailingUnderlineLabel.text =  "")
        }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        view.endEditing(true)
        return true
    }

    



}

