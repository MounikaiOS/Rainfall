//
//  GridVC.swift
//  RainfallDemo
//
//  Created by Mounika on 11/14/17.
//  Copyright © 2017 Peoplelink. All rights reserved.
//


import UIKit
import MaterialComponents

class GridVC: MDCCollectionViewController {
    let appBar = MDCAppBar()
    let fab = MDCFloatingButton()
    var sectionCount = 5
    var scrollOffsetY = 0.0
    var logoScale = 0.0
    
    var  logoView = UIImageView()
    var  logoSmallView = UIImageView()
    override func viewDidLoad() {
        super.viewDidLoad()

        self.collectionView!.register(MDCCollectionViewTextCell.self, forCellWithReuseIdentifier: "cell")
        styler.cellStyle = .card
        addChildViewController(appBar.headerViewController)
        appBar.headerViewController.headerView.trackingScrollView = self.collectionView
        appBar.headerViewController.headerView.maximumHeight = 240
        appBar.headerViewController.headerView.minimumHeight = 76
        appBar.headerViewController.headerView.insertSubview(pestoHeaderView(), at: 0)
        appBar.addSubviewsToParent()
        // Use a custom shadow under the flexible header.
        let shadowLayer = MDCShadowLayer()
        appBar.headerViewController.headerView.setShadowLayer(shadowLayer, intensityDidChange: { (layer, intensity) in
            shadowLayer.elevation = ShadowElevation(rawValue: ShadowElevation.appBar.rawValue * intensity)
        })
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.barButtonDidTap(sender:)))
        
        
        view.addSubview(fab)
        //        view.addSubview(pestoHeaderView())
        
        fab.translatesAutoresizingMaskIntoConstraints = false
        fab.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16.0).isActive = true
        fab.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16.0).isActive = true
        
        fab.setTitle("+", for: .normal)
        fab.setTitle("-", for: .selected)
        fab.addTarget(self, action: #selector(self.fabDidTap(sender:)), for: .touchUpInside)
        
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.collectionView?.collectionViewLayout.invalidateLayout()
        centerHeaderWithSize(size: size)
    }
    func centerHeaderWithSize(size: CGSize) {
        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let width = size.width;
        let headerFrame = self.appBar.headerViewController.headerView.bounds;
        self.logoView.center = CGPoint(x: width/2.0, y: headerFrame.size.height / 2.0)
        self.logoSmallView.center =
            CGPoint(x: width / 2.0, y: (headerFrame.size.height - statusBarHeight) / 2.0 + statusBarHeight);
    }
    func pestoHeaderView() -> UIView {
        let headerFrame = appBar.headerViewController.headerView.bounds
        let pestoHeaderView = UIView.init(frame: headerFrame)
        let teal = UIColor.init(red: 0.0, green: 0.67, blue: 0.55, alpha: 0.55)
        pestoHeaderView.backgroundColor = teal
        pestoHeaderView.layer.masksToBounds = true
        pestoHeaderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let image = UIImage.init(named: "PestoLogoLarge")
        logoView = UIImageView.init(image: image)
        logoView.contentMode = .scaleAspectFill
        logoView.center = CGPoint.init(x: pestoHeaderView.frame.size.width / 2.0, y: pestoHeaderView.frame.size.height / 2.0)
        pestoHeaderView.addSubview(logoView)
        
        let logoSmallImage = UIImage.init(named: "PestoLogoLarge")
        logoSmallView = UIImageView.init(image: logoSmallImage)
        logoSmallView.contentMode = .scaleAspectFill
        logoSmallView.layer.opacity = 0;
        pestoHeaderView.addSubview(logoView)
        
        return pestoHeaderView;
    }
    @objc func barButtonDidTap(sender: UIBarButtonItem) {
        editor.isEditing = !editor.isEditing
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: editor.isEditing ? "Cancel" : "Edit", style: .plain, target: self, action: #selector(self.barButtonDidTap(sender:)))
        
    }
    
    @objc func fabDidTap(sender: UIButton) {
        self.sectionCount = !sender.isSelected ? self.sectionCount + 1 : (self.sectionCount > 0) ? self.sectionCount - 1 : self.sectionCount
        sender.isSelected = !sender.isSelected
        self.collectionView?.reloadData()
        
    }
    
    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.sectionCount
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let completion = {(accepted: Bool) in
            // perform analytics here
            // and record whether the highlight was accepted
        }
//        if indexPath.item % 2 == 0 {
            let highlightController = MDCFeatureHighlightViewController(highlightedView: UIView.init(frame: CGRect(x: 0, y: 0, width: 200, height: 200)), completion: completion)
            highlightController.titleText = "Just how you want it"
            highlightController.bodyText = "Tap the menu button to switch accounts, change settings & more."
            highlightController.outerHighlightColor =
                UIColor.blue.withAlphaComponent(kMDCFeatureHighlightOuterHighlightAlpha)
            present(highlightController, animated: true, completion:nil)
//        } else {
//            let detailVC = DetailVC(nibName: "DetailVC", bundle: nil)
//            self.navigationController?.pushViewController(detailVC, animated: true)
//
//        }
        
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
        self.scrollOffsetY = Double(scrollView.contentOffset.y)
        self.appBar.headerViewController.scrollViewDidScroll(scrollView)
        centerHeaderWithSize(size: self.view.frame.size)
        self.logoScale = Double(scrollView.contentOffset.y / -240);
        if (self.logoScale < 0.5) {
            self.logoScale = 0.5
            UIView.animate(withDuration: 0.33, delay: 0, options: .curveEaseInOut, animations: {
                self.logoView.layer.opacity = 0
                self.logoSmallView.layer.opacity = 1.0
            }, completion: nil)
        } else {
            UIView.animate(withDuration: 0.33, delay: 0, options: .curveEaseInOut, animations: {
                self.logoView.layer.opacity = 1.0
                self.logoSmallView.layer.opacity = 0.0
            }, completion: nil)
        }
        let rotate = CGAffineTransform(rotationAngle: 0.0)
        self.logoView.transform =
            rotate.scaledBy(x: CGFloat(self.logoScale), y: CGFloat(self.logoScale));
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

