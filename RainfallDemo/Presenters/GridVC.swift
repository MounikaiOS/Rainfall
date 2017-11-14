//
//  GridVC.swift
//  RainfallDemo
//
//  Created by Mounika on 11/14/17.
//  Copyright © 2017 Peoplelink. All rights reserved.
//


import UIKit
import MaterialComponents.MaterialAppBar
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialCollections

class GridVC: MDCCollectionViewController {
    let appBar = MDCAppBar()
    let fab = MDCFloatingButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView!.register(MDCCollectionViewTextCell.self, forCellWithReuseIdentifier: "cell")
        styler.cellStyle = .card
        
        addChildViewController(appBar.headerViewController)
        appBar.headerViewController.headerView.backgroundColor = UIColor(red: 1.0, green: 0.76, blue: 0.03, alpha: 1.0)
        
        appBar.headerViewController.headerView.trackingScrollView = self.collectionView
        appBar.addSubviewsToParent()
        
        title = "Material Components"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.barButtonDidTap(sender:)))
        
        appBar.navigationBar.tintColor = UIColor.black
        
        view.addSubview(fab)
        fab.translatesAutoresizingMaskIntoConstraints = false
        fab.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16.0).isActive = true
        fab.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16.0).isActive = true
        
        fab.setTitle("+", for: .normal)
        fab.setTitle("-", for: .selected)
        fab.addTarget(self, action: #selector(self.fabDidTap(sender:)), for: .touchUpInside)
    }
    
    @objc func barButtonDidTap(sender: UIBarButtonItem) {
        editor.isEditing = !editor.isEditing
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: editor.isEditing ? "Cancel" : "Edit", style: .plain, target: self, action: #selector(self.barButtonDidTap(sender:)))
    }
    
    @objc func fabDidTap(sender: UIButton) {
        sender.isSelected = !sender.isSelected
    }
    
    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 5
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let detailVC = DetailVC(nibName: "DetailVC", bundle: nil)
        self.navigationController?.pushViewController(detailVC, animated: true)
    }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        
        if let textCell = cell as? MDCCollectionViewTextCell {
            
            // Add some mock text to the cell.
            let animals = ["Lions", "Tigers", "Bears", "Monkeys"]
            textCell.textLabel?.text = animals[indexPath.item]
        }
        
        return cell
    }
    
    // MARK: UIScrollViewDelegate
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == appBar.headerViewController.headerView.trackingScrollView {
            appBar.headerViewController.headerView.trackingScrollDidScroll()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == appBar.headerViewController.headerView.trackingScrollView {
            appBar.headerViewController.headerView.trackingScrollDidEndDecelerating()
        }
    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == appBar.headerViewController.headerView.trackingScrollView {
            let headerView = appBar.headerViewController.headerView
            headerView.trackingScrollDidEndDraggingWillDecelerate(decelerate)
        }
    }
    
    override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == appBar.headerViewController.headerView.trackingScrollView {
            let headerView = appBar.headerViewController.headerView
            headerView.trackingScrollWillEndDragging(withVelocity: velocity, targetContentOffset: targetContentOffset)
        }
    }
}
