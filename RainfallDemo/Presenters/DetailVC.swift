//
//  DetailVC.swift
//  RainfallDemo
//
//  Created by Mounika on 11/14/17.
//  Copyright © 2017 Peoplelink. All rights reserved.
//

import UIKit
import MaterialComponents
class DetailVC: UIViewController, UIScrollViewDelegate {
    @IBOutlet weak var scrollView: UIScrollView!
    let pages = NSMutableArray()
    let pageControl = MDCPageControl()
    var colors:[UIColor] = [UIColor.red, UIColor.blue, UIColor.green, UIColor.yellow]
    var frame: CGRect = CGRect(x:0, y:0, width:0, height:0)

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        scrollView.delegate = self
        pageControl.numberOfPages = 4
        for index in 0..<4 {
            
            frame.origin.x = self.scrollView.frame.size.width * CGFloat(index)
            frame.size = self.scrollView.frame.size
            let subView = UIView(frame: frame)
            subView.backgroundColor = colors[index]
            self.scrollView .addSubview(subView)
        }
        
        self.scrollView.contentSize = CGSize(width:self.scrollView.frame.size.width * 4,height: self.scrollView.frame.size.height)
        let pageControlSize = pageControl.sizeThatFits(scrollView.bounds.size)
        pageControl.frame = CGRect(x: 0, y: scrollView.bounds.height - 50, width: scrollView.bounds.width, height: pageControlSize.height)
        pageControl.addTarget(self, action: #selector(self.didChangePage(sender:)), for: UIControlEvents.valueChanged)
        pageControl.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
        view.addSubview(pageControl)
        // Do any additional setup after loading the view.
    }
    @objc func didChangePage(sender: MDCPageControl){
        let x = CGFloat(pageControl.currentPage) * scrollView.frame.size.width
        scrollView.setContentOffset(CGPoint(x:x, y:0), animated: true)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        let pageNumber = round(scrollView.contentOffset.x / scrollView.frame.size.width)
        pageControl.currentPage = Int(pageNumber)
        let x = CGFloat(pageControl.currentPage) * scrollView.frame.size.width
        scrollView.setContentOffset(CGPoint(x:x, y:0), animated: true)
        pageControl.scrollViewDidEndDecelerating(scrollView)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
