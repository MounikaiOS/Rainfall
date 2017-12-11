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
        var pagesize: vm_size_t = 0
        
        let host_port: mach_port_t = mach_host_self()
        var host_size: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<integer_t>.stride)
        host_page_size(host_port, &pagesize)
        
        var vm_stat: vm_statistics = vm_statistics_data_t()
        withUnsafeMutablePointer(to: &vm_stat) { (vmStatPointer) -> Void in
            vmStatPointer.withMemoryRebound(to: integer_t.self, capacity: Int(host_size)) {
                if (host_statistics(host_port, HOST_VM_INFO, $0, &host_size) != KERN_SUCCESS) {
                    print("Error: Failed to fetch vm statistics")
                }
            }
        }
       let rammem = ProcessInfo.processInfo.physicalMemory/(1024 * 1024 * 1024)

        /* Stats in bytes */
        let mem_used: Int64 = Int64(vm_stat.active_count +
            vm_stat.inactive_count +
            vm_stat.wire_count) * Int64(pagesize)/(1024 * 1024 * 1024)
        let mem_free: Int64 = Int64(vm_stat.free_count) * Int64(pagesize)/(1024 * 1024 * 1024)
        // Do any additional setup after loading the view, typically from a nib.
        print(rammem,mem_free,mem_used)
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
            let detailVC = GridVC(nibName: "GridVC", bundle: nil)
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

