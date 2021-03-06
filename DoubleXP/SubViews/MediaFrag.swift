//
//  MediaFrag.swift
//  DoubleXP
//
//  Created by Toussaint Peterson on 2/25/20.
//  Copyright © 2020 Peterson, Toussaint. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import moa
import SwiftHTTP
import SwiftNotificationCenter
import WebKit
import SwiftRichString
import FBSDKCoreKit

class MediaFrag: ParentVC, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDelegate, UITableViewDataSource, MediaCallbacks, SocialMediaManagerCallback {
    
    @IBOutlet weak var authorCell: UIView!
    @IBOutlet weak var articleVideoView: UIView!
    @IBOutlet weak var articleTable: UITableView!
    @IBOutlet weak var gcTag: UILabel!
    @IBOutlet weak var channelDXPLogo: UIImageView!
    @IBOutlet weak var twitchPlayer: TestPlayer!
    @IBOutlet weak var twitchPlayerOverlay: UIView!
    @IBOutlet weak var channelLoading: UIView!
    @IBOutlet weak var channelCollection: UICollectionView!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var videosButton: UIButton!
    @IBOutlet weak var streamsButton: UIButton!
    @IBOutlet weak var channelOverlayClose: UIImageView!
    @IBOutlet weak var channelOverlayDesc: UILabel!
    @IBOutlet weak var channelOverlayImage: UIImageView!
    @IBOutlet weak var twitchChannelOverlay: UIView!
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var expandLabel: UILabel!
    @IBOutlet weak var collapseButton: UIImageView!
    @IBOutlet weak var expandButton: UIImageView!
    @IBOutlet weak var articleBlur: UIVisualEffectView!
    @IBOutlet weak var articleOverlay: UIView!
    @IBOutlet weak var articleHeader: UIView!
    @IBOutlet weak var optionsCollection: UICollectionView!
    @IBOutlet weak var news: UICollectionView!
    @IBOutlet weak var articleAuthorBadge: UIImageView!
    @IBOutlet weak var articleSourceImage: UIImageView!
    @IBOutlet weak var articleName: UILabel!
    @IBOutlet weak var articleSub: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var articleImage: UIImageView!
    @IBOutlet weak var articleWV: WKWebView!
    @IBOutlet weak var videoAvailLabel: UILabel!
    @IBOutlet weak var playLogo: UIImageView!
    var options = [String]()
    var selectedCategory = ""
    var newsSet = false
    var articles = [Any]()
    var viewSet = false
    var articleSet = false
    var selectedArticle: NewsObject!
    var selectedArticleImage: UIImage?
    var articlePayload = [Any]()
    var twitchPayload = [Any]()
    var twitchCoverShowing = false
    var currentCell: NewsArticleCell?
    var selectedChannel: TwitchChannelObj!
    var currentVideoCell: ArticleVideoCell?
    var constraint : NSLayoutConstraint?
    var channelConstraint : NSLayoutConstraint?
    var streams = [TwitchStreamObject]()
    var currentCategory = "news"
    
    var articlesLoaded = false
    private var streamsSet = false
    @IBOutlet weak var loadingViewSpinner: UIActivityIndicatorView!
    
    private let refreshControl = UIRefreshControl()
    private let channelRefreshControl = UIRefreshControl()
    
    @IBOutlet weak var standby: UIView!
    
    var mediaFragActive = false
    var channelOpen = false
    var articleOpen = false
    
    var currentTwitchImage: Image?
    private var isExpanded = false
    
    @IBOutlet private var maxWidthConstraint: NSLayoutConstraint! {
        didSet {
            maxWidthConstraint.isActive = false
        }
    }
    
    struct Constants {
        static let spacing: CGFloat = 16
        static let secret = "uyvhqn68476njzzdvja9ulqsb8esn3"
        static let id = "aio1d4ucufi6bpzae0lxtndanh3nob"
    }
    
    var maxWidth: CGFloat? = nil {
        didSet {
            guard let maxWidth = maxWidth else {
                return
            }
            maxWidthConstraint.isActive = true
            maxWidthConstraint.constant = maxWidth
        }
    }
    
    let styleBase = Style({
        $0.color = UIColor.white
    })
    
    let styleBaseDark = Style({
        $0.color = UIColor.black
    })
    
    let testAttr = Style({
        $0.font = UIFont.boldSystemFont(ofSize: 20)
        $0.color = UIColor.blue
    })
    
    @IBOutlet weak var header: UIView!
    @IBOutlet weak var twitchLoginButton: UIView!
    @IBOutlet weak var twitchCover: UIView!
    @IBOutlet weak var articleOverlayClose: UIImageView!
    private var standbyShowing = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.pageName = "Media"
        
        options.append("#popular")
        options.append("#reviews")
        options.append("#twitch")
        options.append("empty")
        
        self.selectedCategory = options[0]
        
        if #available(iOS 10.0, *) {
            self.news.refreshControl = refreshControl
            self.channelCollection.refreshControl = channelRefreshControl
        } else {
            self.news.addSubview(refreshControl)
            self.channelCollection.addSubview(channelRefreshControl)
        }
        self.news.refreshControl?.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        self.channelCollection.refreshControl?.addTarget(self, action: #selector(downloadStreams), for: .valueChanged)
        
        optionsCollection.dataSource = self
        optionsCollection.delegate = self
        
        self.news?.collectionViewLayout = TestCollection()
        
        self.constraint = NSLayoutConstraint(item: self.articleOverlay, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.0, constant: 0)
        
        self.channelConstraint = NSLayoutConstraint(item: self.twitchChannelOverlay, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.0, constant: 0)
        
        self.constraint?.isActive = true
        self.channelConstraint?.isActive = true
        
        let expand = UITapGestureRecognizer(target: self, action: #selector(expandOverlay))
        expandButton.isUserInteractionEnabled = true
        expandButton.addGestureRecognizer(expand)
        
        AppEvents.logEvent(AppEvents.Name(rawValue: "Media"))
        
        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification,
            object: self.view.window,
            queue: nil
        ) { notification in
            self.hideStandby()
        }

        animateView()
    }
    
    private func showStandby(){
        if(!self.standbyShowing){
            UIView.animate(withDuration: 0.5, animations: {
                self.standby.alpha = 1
                self.standby.isUserInteractionEnabled = true
            }, completion: nil)
        }
    }
    
    private func hideStandby(){
        if(!self.standbyShowing){
            UIView.animate(withDuration: 0.5, animations: {
                self.standby.alpha = 0
                self.standby.isUserInteractionEnabled = false
            }, completion: nil)
        }
    }
    
    @objc func pullToRefresh(){
        if(self.currentCategory == "news"){
            getMedia()
        }
        else if(self.currentCategory == "reviews"){
            getReviews()
        }
        else{
            if(self.refreshControl.isRefreshing){
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    @objc func getMedia(){
        if(self.loadingView.alpha == 0){
            UIView.animate(withDuration: 0.8, animations: {
                self.loadingView.alpha = 1
                self.loadingViewSpinner.startAnimating()
            }, completion: { (finished: Bool) in
                let delegate = UIApplication.shared.delegate as! AppDelegate
                let manager = delegate.mediaManager
                manager.getGameSpotNews(callbacks: self)
            })
        }
        else{
            self.loadingViewSpinner.startAnimating()
             
            let delegate = UIApplication.shared.delegate as! AppDelegate
            let manager = delegate.mediaManager
            manager.getGameSpotNews(callbacks: self)
        }
    }
    
    @objc func getReviews(){
        if(self.loadingView.alpha == 0){
            UIView.animate(withDuration: 0.8, animations: {
                self.loadingView.alpha = 1
                self.loadingViewSpinner.startAnimating()
            }, completion: { (finished: Bool) in
                let delegate = UIApplication.shared.delegate as! AppDelegate
                let manager = delegate.mediaManager
                manager.getReviews(callbacks: self)
            })
        }
        else{
            let delegate = UIApplication.shared.delegate as! AppDelegate
            let manager = delegate.mediaManager
            manager.getReviews(callbacks: self)
        }
    }
    
    private func animateView(){
        let top = CGAffineTransform(translationX: 0, y: 50)
        UIView.animate(withDuration: 0.5, animations: {
            self.optionsCollection.alpha = 1
            self.optionsCollection.transform = top
        }, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.getMedia()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if(collectionView == optionsCollection){
            return options.count
        }
        else if(collectionView == self.channelCollection){
            return self.streams.count
        }
        else{
            return articles.count
        }
    }
    
    private func scrollToTop(collectionView: UICollectionView){
        collectionView.scrollToItem(at: IndexPath(row: 0, section: 0),
              at: .top,
        animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if(collectionView == optionsCollection){
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! MediaCategoryCell
            let current = self.options[indexPath.item]
            
            if(current == "empty"){
                cell.mediaCategory.isHidden = true
                cell.categoryContents.isHidden = true
                cell.contentView.backgroundColor = .clear
                cell.isUserInteractionEnabled = false
                cell.categoryImg.isHidden = true
            }
            else{
                if(current == "#twitch"){
                    cell.contentView.backgroundColor = #colorLiteral(red: 0.395016551, green: 0.2572917342, blue: 0.6494273543, alpha: 1)
                    cell.mediaCategory.textColor = UIColor(named: "stayWhite")
                    cell.categoryContents.textColor = UIColor(named: "stayWhite")
                    cell.categoryImg.image = #imageLiteral(resourceName: "twitch_white.png")
                    cell.categoryImg.contentMode = .scaleAspectFill
                    cell.categoryImg.clipsToBounds = true
                    
                    cell.categoryContents.text = "streams/videos"
                }
                if(current == "#popular"){
                    cell.categoryContents.text = "what's goin' on"
                }
                if(current == "#reviews"){
                    cell.categoryContents.text = "game reviews"
                }
                
                cell.contentView.layer.cornerRadius = 20.0
                cell.contentView.layer.borderWidth = 1.0
                cell.contentView.layer.borderColor = UIColor.clear.cgColor
                cell.contentView.layer.masksToBounds = true
                
                cell.layer.shadowColor = UIColor.black.cgColor
                cell.layer.shadowOffset = CGSize(width: cell.bounds.width + 20, height: cell.bounds.height + 20)
                cell.layer.shadowRadius = 2.0
                cell.layer.shadowOpacity = 0.8
                cell.layer.masksToBounds = false
                cell.layer.shadowPath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: cell.contentView.layer.cornerRadius).cgPath
                
                
                cell.mediaCategory.text = current
            }
            
            return cell
        }
        else if(collectionView == self.channelCollection){
            let current = self.streams[indexPath.item]
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "contentCell", for: indexPath) as! TwitchContentCell
            if(current is TwitchStreamObject){
                let current = (self.streams[indexPath.item] as! TwitchStreamObject)
                cell.channelName.text = current.title
                cell.channelUser.text = current.handle
                
                let str = current.thumbnail
                let replaced = str.replacingOccurrences(of: "{width}x{height}", with: "800x500")
                cell.contentImage.moa.url = replaced
                cell.contentImage.contentMode = .scaleAspectFill
                cell.contentImage.clipsToBounds = true
            }
            return cell
        }
        else{
            let current = self.articles[indexPath.item]
            if(current is NewsObject){
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "newsCell", for: indexPath) as! NewsArticleCell
                cell.title.text = (current as! NewsObject).title
                cell.subTitle.text = (current as! NewsObject).subTitle
                
                if(!(current as! NewsObject).imageAdded){
                    cell.articleBack.moa.onSuccess = { image in
                        UIView.animate(withDuration: 0.5, delay: 0.2, options: [], animations: {
                            cell.articleBack.alpha = 0.1
                            cell.articleBack.contentMode = .scaleAspectFill
                            cell.articleBack.clipsToBounds = true
                        }, completion: nil)
                        
                        (current as! NewsObject).image = image
                        (current as! NewsObject).imageAdded = true
                        
                      return image
                    }
                }
                else{
                    cell.articleBack.image = (current as! NewsObject).image
                }
                
                switch ((current as! NewsObject).author) {
                case "Kwatakye Raven":
                    //cell..text = "DoubleXP"
                    cell.authorLabel.text = (current as! NewsObject).author
                    cell.authorImage.image = #imageLiteral(resourceName: "mike_badge.png")
                    cell.sourceImage.image = #imageLiteral(resourceName: "team_thumbs_up.png")
                    break
                case "Aaron Hodges":
                    cell.authorLabel.text = (current as! NewsObject).author
                    cell.sourceImage.image = #imageLiteral(resourceName: "team_thumbs_up.png")
                    cell.authorImage.image = #imageLiteral(resourceName: "hodges_badge.png")
                    break
                default:
                    cell.authorLabel.text = (current as! NewsObject).author
                    cell.sourceImage.image = #imageLiteral(resourceName: "gamespot_icon_ios.png")
                    cell.authorImage.image = #imageLiteral(resourceName: "unknown_badge.png")
                }
                
                cell.articleBack.image = #imageLiteral(resourceName: "new_logo3.png")
                cell.articleBack.moa.url = (current as! NewsObject).imageUrl
                
                cell.tag = indexPath.item
                
                return cell
            }
            else if(current is TwitchChannelObj){
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "channelCell", for: indexPath) as! TwitchChannelCell
                cell.gameName.text = (current as! TwitchChannelObj).gameName
                
                let str = (current as! TwitchChannelObj).imageUrlIOS
                let replaced = str.replacingOccurrences(of: "{width}x{height}", with: "800x500")
                
                cell.image.moa.url = replaced
                cell.image.contentMode = .scaleAspectFill
                cell.image.clipsToBounds = true
                
                cell.contentView.layer.cornerRadius = 10.0
                cell.contentView.layer.borderWidth = 1.0
                cell.contentView.layer.borderColor = UIColor.clear.cgColor
                cell.contentView.layer.masksToBounds = true
                
                cell.layer.shadowColor = UIColor.black.cgColor
                cell.layer.shadowOffset = CGSize(width: 0, height: 2.0)
                cell.layer.shadowRadius = 2.0
                cell.layer.shadowOpacity = 0.5
                cell.layer.masksToBounds = false
                cell.layer.shadowPath = UIBezierPath(roundedRect: cell.bounds, cornerRadius:
                    cell.contentView.layer.cornerRadius).cgPath
                //cell.devLogo.contentMode = .scaleAspectFill
                //cell.devLogo.clipsToBounds = true
                
                return cell
            }
            else if(current is Bool){
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "twitchLoginCell", for: indexPath) as! TwitchLoginCell
                cell.loginButton.applyGradient(colours:  [#colorLiteral(red: 0.3081886768, green: 0.1980658174, blue: 0.5117434263, alpha: 1), #colorLiteral(red: 0.395016551, green: 0.2572917342, blue: 0.6494273543, alpha: 1)], orientation: .horizontal)
                return cell
            }
            else{
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "contributorCell", for: indexPath) as! ContributorCell
                return cell
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if(collectionView == optionsCollection){
            if(self.articlesLoaded){
                let current = self.options[indexPath.item]
                
                self.selectedCategory = current
                let cell = collectionView.cellForItem(at: indexPath) as! MediaCategoryCell
                cell.mediaCategory.font = UIFont.systemFont(ofSize: 18, weight: .bold)
                if(cell.mediaCategory.text == "#twitch"){
                    cell.mediaCategory.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                }
                
                for cell in self.optionsCollection.visibleCells{
                    let currentCell = cell as! MediaCategoryCell
                    if(currentCell.mediaCategory.text != current){
                        currentCell.mediaCategory.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                    }
                }
                
                let delegate = UIApplication.shared.delegate as! AppDelegate
                
                switch(self.selectedCategory){
                    case "#popular":
                        self.currentCategory = "news"
                        self.articlesLoaded = false
                        AppEvents.logEvent(AppEvents.Name(rawValue: "Media - Popular Selected"))
                        delegate.currentLanding?.updateNavColor(color: UIColor(named: "darker")!)
                        
                        UIView.animate(withDuration: 0.3, animations: {
                            self.loadingView.alpha = 1
                        }, completion: { (finished: Bool) in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                delegate.currentLanding?.updateNavColor(color: UIColor(named: "darker")!)
                                
                                if(!delegate.mediaCache.reviewsCache.isEmpty){
                                    self.onMediaReceived(category: "news")
                                }
                                else{
                                    self.getMedia()
                                }
                            }
                        })
                    
                    break;
                    case "#twitch":
                        self.currentCategory = "twitch"
                        self.articlesLoaded = false
                        AppEvents.logEvent(AppEvents.Name(rawValue: "Media - Twitch Selected"))
                        delegate.currentLanding?.updateNavColor(color: UIColor(named: "twitchPurpleDark")!)
                        
                        UIView.animate(withDuration: 0.3, animations: {
                            self.loadingView.alpha = 1
                        }, completion: { (finished: Bool) in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.articles = [Any]()
                                
                                let manager = SocialMediaManager()
                                manager.getTopGames(callbacks: self)
                            }
                        })
                    break;
                    case "#reviews":
                        self.currentCategory = "reviews"
                        self.articlesLoaded = false
                        AppEvents.logEvent(AppEvents.Name(rawValue: "Media - Reviews Selected"))
                        delegate.currentLanding?.updateNavColor(color: UIColor(named: "darker")!)
                        
                        UIView.animate(withDuration: 0.3, animations: {
                            self.loadingView.alpha = 1
                        }, completion: { (finished: Bool) in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.news?.collectionViewLayout = TestCollection()
                                delegate.currentLanding?.updateNavColor(color: UIColor(named: "darker")!)
                                
                                if(!delegate.mediaCache.reviewsCache.isEmpty){
                                    self.onMediaReceived(category: "reviews")
                                }
                                else{
                                    self.getReviews()
                                }
                            }
                        })
                    break;
                    default:
                        self.articles = [Any]()
                        self.articlesLoaded = false
                        articles.append(contentsOf: delegate.mediaCache.newsCache)
                        delegate.currentLanding?.updateNavColor(color: UIColor(named: "darker")!)
                        
                        if(self.twitchCoverShowing){
                            UIView.transition(with: self.header, duration: 0.3, options: .curveEaseInOut, animations: {
                                self.header.backgroundColor = UIColor(named: "dark")
                                self.optionsCollection.backgroundColor = UIColor(named: "darkOpacity")
                            })
                            
                            delegate.currentLanding?.updateNavColor(color: UIColor(named: "darker")!)
                                
                            UIView.animate(withDuration: 0.8, animations: {
                                    self.twitchCover.alpha = 0
                            }, completion: { (finished: Bool) in
                                self.news.performBatchUpdates({
                                    let indexSet = IndexSet(integersIn: 0...0)
                                    self.news.reloadSections(indexSet)
                                }, completion: nil)
                            })
                            
                            self.twitchCoverShowing = false
                        }
                        else{
                            self.news.performBatchUpdates({
                                let indexSet = IndexSet(integersIn: 0...0)
                                self.news.reloadSections(indexSet)
                            }, completion: nil)
                        }
                    break;
                }
            }
        }
        else if(collectionView == channelCollection){
            let current = streams[indexPath.item]
            
            NotificationCenter.default.addObserver(
                forName: UIWindow.didBecomeKeyNotification,
                object: self.view.window,
                queue: nil
            ) { notification in
                print("Video stopped")
                //self.twitchPlayer.isHidden = true
                self.twitchPlayer.setChannel(to: "")
                
                UIView.animate(withDuration: 0.8) {
                    self.twitchPlayerOverlay.alpha = 0
                }
            }
            
            twitchPlayer.configuration.allowsInlineMediaPlayback = true
            twitchPlayer.configuration.mediaTypesRequiringUserActionForPlayback = []
            twitchPlayer.setChannel(to: current.handle)
            //twitchPlayer.togglePlaybackState()
            
            UIView.animate(withDuration: 0.8) {
                self.twitchPlayerOverlay.alpha = 1.0
            }
        }
        else {
            let current = self.articles[indexPath.item]
            if(current is NewsObject){
                let cell = collectionView.cellForItem(at: indexPath) as! NewsArticleCell
                self.selectedArticle = (current as! NewsObject)
                self.selectedArticleImage = cell.articleBack.image
                self.currentCell = cell
            
                self.showArticle(article: self.selectedArticle)
                
                AppEvents.logEvent(AppEvents.Name(rawValue: "Article Selected: Source - " + selectedArticle.source))
                //onVideoLoaded(url: "https://static-gamespotvideo.cbsistatic.com/vr/2019/04/23/kingsfieldiv1_700_1000.mp4")
                
                
                /*if(self.selectedArticle.source == "gs"){
                    let delegate = UIApplication.shared.delegate as! AppDelegate
                    delegate.mediaManager.downloadVideo(title: self.selectedArticle.title, url: selectedArticle.videoUrl, callbacks: self)
                }
                else{
                    onVideoLoaded(url: self.selectedArticle.videoUrl)
                }*/
            }
            
            if(current is TwitchChannelObj){
                let cell = collectionView.cellForItem(at: indexPath) as! TwitchChannelCell
                self.currentTwitchImage = cell.image.image
                self.selectedChannel = (current as! TwitchChannelObj)
                
                self.showChannel(channel: self.selectedChannel)
            }
        }
    }
    
    func showArticle(article: NewsObject){
        self.articleOverlay.alpha = 1
        self.twitchChannelOverlay.alpha = 0
        self.articlePayload = [Any]()
        
        self.articleName.text = self.selectedArticle.title
        self.articleSub.text = self.selectedArticle.subTitle
        
        let source = self.selectedArticle.source
        if(source == "gs"){
            self.articleSourceImage.image = #imageLiteral(resourceName: "gamespot_icon_ios.png")
        }
        else{
            self.articleSourceImage.image = #imageLiteral(resourceName: "new_logo.png")
        }
        
        let author = self.selectedArticle.author
        switch (author) {
        case "Kwatakye Raven":
            //cell..text = "DoubleXP"
            self.authorLabel.text = author
            self.articleAuthorBadge.image = #imageLiteral(resourceName: "mike_badge.png")
            break
        case "Aaron Hodges":
            self.authorLabel.text = author
            self.articleAuthorBadge.image = #imageLiteral(resourceName: "hodges_badge.png")
            break
        default:
            self.authorLabel.text = author
            self.articleAuthorBadge.image = #imageLiteral(resourceName: "unknown_badge.png")
        }
        
        if(self.selectedArticle.videoUrl.isEmpty){
            self.playLogo.alpha = 0.1
            self.videoAvailLabel.text = "No Video Available (wah wah waaaaaaah)"
            
            self.articleImage.alpha = 0
            self.articleWV.alpha = 0
        }
        else{
            let videoTap = UITapGestureRecognizer(target: self, action: #selector(videoClicked))
            self.articleVideoView.isUserInteractionEnabled = true
            self.articleVideoView.addGestureRecognizer(videoTap)
            
            if(self.selectedArticleImage != nil){
                self.articleImage.image = self.selectedArticleImage
                self.articleImage.contentMode = .scaleAspectFill
                self.articleImage.clipsToBounds = true
                self.articleImage.alpha = 0.1
            }
            self.articleWV.alpha = 1
        }
        
        let authorTap = UITapGestureRecognizer(target: self, action: #selector(authorClicked))
        self.authorCell.isUserInteractionEnabled = true
        self.authorCell.addGestureRecognizer(authorTap)
        
        
        self.articlePayload.append(article.storyText)
        
        if(!self.articleSet){
            self.articleTable.delegate = self
            self.articleTable.dataSource = self
        
            self.articleSet = true
        }
        else{
            self.articleTable.reloadData()
        }
        
        self.expandButton.isHidden = false
        self.expandLabel.isHidden = false
        
        let close = UITapGestureRecognizer(target: self, action: #selector(closeOverlay))
        articleOverlayClose.isUserInteractionEnabled = true
        articleOverlayClose.addGestureRecognizer(close)
        
        UIView.animate(withDuration: 0.3, animations: {
            self.articleBlur.alpha = 1
        }, completion: { (finished: Bool) in
            UIView.animate(withDuration: 0.3, delay: 0.2, options: [], animations: {
                self.constraint?.constant = self.view.frame.size.height / 2
                
                UIView.animate(withDuration: 0.5) {
                    self.articleOverlay.alpha = 1
                    self.view.bringSubviewToFront(self.articleOverlay)
                    self.view.layoutIfNeeded()
                }
            
            }, completion: nil)
        })
        
        self.articleOpen = true
    }
    
    @objc func videoClicked(_ sender: AnyObject?) {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        
        if(self.selectedArticle.source == "gs"){
            AppEvents.logEvent(AppEvents.Name(rawValue: "Media - GS Video Selected"))
            delegate.mediaManager.downloadVideo(title: self.selectedArticle.title, url: selectedArticle.videoUrl, callbacks: self)
        }
        else{
            AppEvents.logEvent(AppEvents.Name(rawValue: "Media - DXP Video Selected"))
            self.onVideoLoaded(url: selectedArticle.videoUrl)
        }
        
        showStandby()
    }
    
    @objc func authorClicked(_ sender: AnyObject?) {
        let author = self.selectedArticle.author
        switch (author) {
        case "Kwatakye Raven":
            //cell..text = "DoubleXP"
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.currentLanding!.navigateToProfile(uid: getHomeUid(position: 2))
            break
        case "Aaron Hodges":
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.currentLanding!.navigateToProfile(uid: getHomeUid(position: 1))
            break
        default:
            print("do nothing")
        }
    }
    
    private func getHomeUid(position: Int) -> String{
        if(position == 1){
            return "oFdx8UequuOs77s8daWFifODVhJ3"
        }
        
        if(position == 2){
            return "N1k1BqmvEvdOXrbmi2p91kTNLOo1"
        }
        
        return ""
    }
    
    func showChannel(channel: TwitchChannelObj){
        self.articleOverlay.alpha = 0
        self.twitchChannelOverlay.alpha = 1
        self.channelOverlayDesc.text = channel.gameName
        if(channel.isGCGame(game: channel.gameName)){
            self.channelDXPLogo.isHidden = false
            self.connectButton.isHidden = false
            self.connectButton.isUserInteractionEnabled = true
            self.gcTag.isHidden = false
        }
        else{
            self.channelDXPLogo.isHidden = true
            self.connectButton.isHidden = true
            self.connectButton.isUserInteractionEnabled = false
            self.gcTag.isHidden = true
        }
        
        let close = UITapGestureRecognizer(target: self, action: #selector(closeChannel))
        channelOverlayClose.isUserInteractionEnabled = true
        channelOverlayClose.addGestureRecognizer(close)
        
        streamsButton.addTarget(self, action: #selector(downloadStreams), for: .touchUpInside)
        videosButton.addTarget(self, action: #selector(downloadVideos), for: .touchUpInside)
        connectButton.addTarget(self, action: #selector(navigateToConnect), for: .touchUpInside)
        
        UIView.animate(withDuration: 0.3, animations: {
            self.articleBlur.alpha = 1
        }, completion: { (finished: Bool) in
            UIView.animate(withDuration: 0.3, delay: 0.2, options: [], animations: {
                self.channelConstraint?.constant = self.view.frame.size.height
                
                UIView.animate(withDuration: 0.5) {
                    self.twitchChannelOverlay.alpha = 1
                    self.view.bringSubviewToFront(self.twitchChannelOverlay)
                    self.view.layoutIfNeeded()
                }
            }, completion: nil)
        })
        
        self.channelOpen = true
    }
    
    func onReviewsReceived(payload: [NewsObject]) {
    }
    
    func onMediaReceived(category: String) {
        DispatchQueue.main.async() {
            if(self.refreshControl.isRefreshing){
                self.refreshControl.endRefreshing()
            }
            
            self.articles = [Any]()
            
            let delegate = UIApplication.shared.delegate as! AppDelegate
            delegate.currentMediaFrag = self
            
            if(category == "news"){
                self.articles.append(contentsOf: delegate.mediaCache.newsCache)
            }
            else if(category == "reviews"){
                self.articles.append(contentsOf: delegate.mediaCache.reviewsCache)
            }
            else{
                //"show error"
                return
            }
            
            if(!self.newsSet){
                self.news?.collectionViewLayout = TestCollection()
                self.news.delegate = self
                self.news.dataSource = self
                self.newsSet = true
                
                let top = CGAffineTransform(translationX: 0, y: 40)
                UIView.animate(withDuration: 0.3, animations: {
                    self.loadingView.alpha = 0
                    self.loadingViewSpinner.stopAnimating()
                }, completion: { (finished: Bool) in
                    UIView.animate(withDuration: 0.5, delay: 0.2, options: [], animations: {
                        self.news.transform = top
                        self.news.alpha = 1
                        self.articlesLoaded = true
                    }, completion: nil)
                })
            }
            else{
                self.news?.collectionViewLayout = TestCollection()
                self.news.reloadData()
                self.scrollToTop(collectionView: self.news)
                UIView.animate(withDuration: 0.3, animations: {
                    self.loadingView.alpha = 0
                    self.loadingViewSpinner.stopAnimating()
                }, completion: { (finished: Bool) in
                    UIView.animate(withDuration: 0.5, delay: 0.2, options: [], animations: {
                        self.news.alpha = 1
                        self.articlesLoaded = true
                    }, completion: nil)
                })
            }
        }
    }
    
    func onVideoLoaded(url: String) {
        DispatchQueue.main.async() {

            if let videoURL:URL = URL(string: url) {
                let embedHTML = "<html><head><meta name='viewport' content='width=device-width, initial-scale=0.0, maximum-scale=1.0, minimum-scale=0.0'></head> <iframe width=\(self.currentCell!.bounds.width)\" height=\(self.currentCell!.bounds.width)\" src=\(url)?&playsinline=1\" frameborder=\"0\" allowfullscreen></iframe></html>"

                //let html = "<video playsinline controls width=\"100%\" height=\"100%\" src=\"\(url)\"> </video>"
                //self.testPlayer.loadHTMLString(embedHTML, baseURL: nil)
                //self.currentVideoCell?.videoImage.isHidden = true
                //self.currentWV!.isHidden = fals
                self.articleWV.loadHTMLString(embedHTML, baseURL: nil)
                //let request:URLRequest = URLRequest(url: videoURL)
                //self.testPlayer.load(request)
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        print("gone")
        NotificationCenter.default.removeObserver(NSNotification.Name.AVPlayerItemDidPlayToEndTime)
    }
    
    func playerDidFinishPlaying(note: NSNotification) {
        print("gone")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        self.articleWV.removeObserver(self, forKeyPath: #keyPath(UIViewController.view.frame))
        //self.navigationController?.popViewController(animated: false)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, error) in

        if complete != nil {
          let height = webView.scrollView.contentSize
          print("height of webView is: \(height)")
        }
      })
    }
    
    func windowDidBecomeVisible(notification: NSNotification) {
        print("open")
    }
    
    @objc func downloadStreams(){
        self.streams.removeAll()
        self.channelCollection.performBatchUpdates({
            let indexSet = IndexSet(integersIn: 0...0)
            self.channelCollection.reloadSections(indexSet)
        }, completion: nil)
        
        UIView.animate(withDuration: 0.8, animations: {
            self.channelLoading.alpha = 1
        }, completion: { (finished: Bool) in
            let manager = SocialMediaManager()
            manager.getChannelTopStreams(currentChannel: self.selectedChannel, callbacks: self)
        })
    }
    
    @objc func downloadVideos(){
        self.streams.removeAll()
        self.channelCollection.performBatchUpdates({
            let indexSet = IndexSet(integersIn: 0...0)
            self.channelCollection.reloadSections(indexSet)
        }, completion: nil)
        
        UIView.animate(withDuration: 0.8, animations: {
            self.channelLoading.alpha = 1
        }, completion: { (finished: Bool) in
            let manager = SocialMediaManager()
            manager.getChannelTopVideos(currentChannel: self.selectedChannel, callbacks: self)
        })
    }
    
    @objc func expandOverlay(){
        AppEvents.logEvent(AppEvents.Name(rawValue: "Media - Article Expand"))
        self.isExpanded = true
        self.expandButton.isHidden = true
        self.expandLabel.isHidden = true
        
        self.constraint?.constant = self.view.frame.size.height
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
            
            self.articleTable.reloadData()
        }
    }
    
    @objc func navigateToConnect(){
        let delegate = UIApplication.shared.delegate as! AppDelegate
        delegate.currentLanding?.updateNavColor(color: UIColor(named: "darker")!)
        var currentGame: GamerConnectGame? = nil
        
        for game in delegate.gcGames{
            if(game.gameName == self.selectedChannel.gcGameName){
                currentGame = game
            }
        }
        
        if(currentGame != nil){
            delegate.currentLanding?.navigateToSearch(game: currentGame!)
        }
        else{
            delegate.currentLanding?.navigateToHome()
        }
    }
        
    @objc func closeOverlay(){
        AppEvents.logEvent(AppEvents.Name(rawValue: "Media - Close Article"))
        self.isExpanded = false
        self.constraint?.constant = 0
        
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
            self.articleOverlay.alpha = 1
            self.articleBlur.alpha = 0
        })
        
        reloadColView()
        
        self.articleOpen = false
    }
    
    @objc func closeChannel(){
        AppEvents.logEvent(AppEvents.Name(rawValue: "Media - Close Channel"))
        self.channelConstraint?.constant = 0
        
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
            self.twitchChannelOverlay.alpha = 1
            self.articleBlur.alpha = 0
        })
        
        reloadColView()
        
        self.streams = [TwitchStreamObject]()
        self.channelCollection.reloadData()
        
        self.channelOpen = false
    }
    
    private func reloadColView(){
        self.articleOverlay.setNeedsLayout()
        self.articleOverlay.layoutIfNeeded()
    }
    
    func showTwitchLogin(){
        if(!self.twitchCoverShowing){
            let delegate = UIApplication.shared.delegate as! AppDelegate
            delegate.currentLanding?.updateNavColor(color: UIColor(named: "twitchPurpleDark")!)
            UIView.transition(with: self.header, duration: 0.3, options: .curveEaseInOut, animations: {
                self.header.backgroundColor = UIColor(named: "twitchPurpleDark")
                self.optionsCollection.backgroundColor = UIColor(named: "twitchPurple")
                self.twitchCover.alpha = 1
            }, completion: nil)
            
            self.twitchCoverShowing = true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if(collectionView == optionsCollection){
            //media options
            return CGSize(width: 123, height: CGFloat(126))
        }
        else if(collectionView == channelCollection){
            //twitch channel
            return CGSize(width: (channelCollection.bounds.width), height: 150)
        }
        else {
            let current = self.articles[indexPath.item]
            if(current is Int){
                if((current as! Int) == 0){
                    //empty cell
                    return CGSize(width: (collectionView.bounds.width), height: CGFloat(30))
                }
                else{
                    return CGSize(width: (collectionView.bounds.width - 20), height: CGFloat(200))
                }
            }
            else if(current is Bool){
                //if((current as! Bool) == false){
                    return CGSize(width: (collectionView.bounds.width), height: (collectionView.bounds.height))
                //}
            }
            else{
                return CGSize(width: (collectionView.bounds.width - 20), height: CGFloat(150))
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.articlePayload.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let current = self.articlePayload[indexPath.item]
        let cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath) as! ArticleTextCell
        
        let groupStyle = StyleXML.init(base: styleBase, ["strong" : testAttr])
        let attr = (current as! String).htmlToAttributedString
                      
        cell.label.attributedText = attr?.string.set(style: groupStyle)
        cell.label.lineBreakMode = .byWordWrapping
        
        if(self.isExpanded){
            cell.label.numberOfLines = 500
        }
        else{
            cell.label.numberOfLines = 4
            cell.label.lineBreakMode = .byTruncatingTail
        }
    
        return cell
        
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        print("closing")
    }
    
    func onTweetsLoaded(tweets: [TweetObject]) {
    }
    
    func onChannelsLoaded(channels: [TwitchChannelObj]) {
        DispatchQueue.main.async {
            self.articles.append(contentsOf: channels)
            
            self.news.reloadData()
            UIView.animate(withDuration: 0.8, delay: 1, options: [], animations: {
                self.loadingView.alpha = 0
                self.articlesLoaded = true
            }, completion: nil)
        }
    }
    
    func onStreamsLoaded(streams: [TwitchStreamObject]) {
        if(self.channelRefreshControl.isRefreshing){
            self.channelRefreshControl.endRefreshing()
        }
        
        self.streams = [TwitchStreamObject]()
        self.streams.append(contentsOf: streams)
        
        DispatchQueue.main.async {
            if(!self.streamsSet){
                self.channelCollection.collectionViewLayout = UICollectionViewFlowLayout()
                self.channelCollection.dataSource = self
                self.channelCollection.delegate = self
                
                self.streamsSet = true
                
                UIView.animate(withDuration: 0.8, animations: {
                    self.channelLoading.alpha = 0
                }, completion: { (finished: Bool) in
                    //let manager = SocialMediaManager()
                    //manager.getChannelTopVideos(currentChannel: self.selectedChannel, callbacks: self)
                })
            }
            else{
                UIView.animate(withDuration: 0.8, animations: {
                    self.channelLoading.alpha = 0
                }, completion: { (finished: Bool) in
                    self.channelCollection.reloadData()
                    self.scrollToTop(collectionView: self.channelCollection)
                })
            }
        }
    }
    
    
}
extension String {
    var htmlToAttributedString: NSAttributedString? {
        guard let data = data(using: .utf8) else { return NSAttributedString() }
        do {
            return try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding:String.Encoding.utf8.rawValue], documentAttributes: nil)
        } catch {
            return NSAttributedString()
        }
    }
    var htmlToString: String {
        return htmlToAttributedString?.string ?? ""
    }
}
