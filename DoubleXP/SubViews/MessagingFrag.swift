//
//  MessagingFrag.swift
//  DoubleXP
//
//  Created by Toussaint Peterson on 12/7/19.
//  Copyright © 2019 Peterson, Toussaint. All rights reserved.
//

import UIKit
import Firebase
import moa
import MSPeekCollectionViewDelegateImplementation
import SendBirdSDK
import SwiftNotificationCenter
import SwiftyGif
import FBSDKCoreKit

class MessagingFrag: ParentVC, MessagingCallbacks, SearchCallbacks, UITableViewDelegate, UITableViewDataSource {
    
    var currentUser: User?
    var groupChannelUrl: String?
    var team: TeamObject?
    var manager: MessagingManager?
    var otherUserId: String?
    var chatMessages = [Any]()
    var mentionedUsers = [String]()

    @IBOutlet weak var tapInstruc: UILabel!
    @IBOutlet weak var emptyTeam: UIView!
    @IBOutlet weak var emptyUser: UIView!
    @IBOutlet weak var emptyHeader: UILabel!
    @IBOutlet weak var emptyOverlay: UIView!
    @IBOutlet weak var messagingView: UITableView!
    @IBOutlet weak var errorOverlay: UIView!
    @IBOutlet weak var errorText: UILabel!
    //@IBOutlet weak var sendButton: UIButton!
    
    var estimatedHeight: CGFloat?
    private var emptyShowing = false
    private var messagesSet = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = MessagingManager()
        
        let delegate = UIApplication.shared.delegate as! AppDelegate
        let currentUser = delegate.currentUser
        
        manager!.setup(sendBirdId: currentUser!.sendBirdId, currentUser: currentUser!, messagingCallbacks: self)
        
        Broadcaster.register(SearchCallbacks.self, observer: self)
        
        animateView()
        self.emptyShowing = true
    }
    
    private func animateView(){
        self.emptyShowing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let currentLanding = appDelegate.currentLanding!
            let top = CGAffineTransform(translationX: 0, y: -10)
            let top2 = CGAffineTransform(translationX: 0, y: -currentLanding.bottomNavHeight + 80)
            UIView.animate(withDuration: 0.8, animations: {
                self.emptyOverlay.alpha = 1
            }, completion: { (finished: Bool) in
                UIView.animate(withDuration: 0.5, delay: 0.2, options: [], animations: {
                    self.emptyHeader.transform = top
                    self.emptyHeader.alpha = 1
                    
                    if(self.groupChannelUrl != nil){
                        self.emptyTeam.alpha = 1
                        self.emptyTeam.transform = top
                    }
                    else{
                        self.emptyUser.transform = top
                        self.emptyUser.alpha = 1
                    }
                }, completion: { (finished: Bool) in
                    UIView.animate(withDuration: 0.8, delay: 0.8, options: [], animations: {
                        self.tapInstruc.alpha = 1
                        self.tapInstruc.transform = top2
                    }, completion: nil)
                })
            })
        }
    }
    
    func connectionSuccessful() {
        if(groupChannelUrl != nil){
            manager?.loadGroupChannel(channelUrl: groupChannelUrl!, team: true, callbacks: self)
        }
        else if(groupChannelUrl == nil && otherUserId == nil){
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let currentUser = appDelegate.currentUser
            manager?.createTeamChannel(userId: currentUser!.uId, callbacks: self)
        }
        else{
            seeIfChannelExists()
        }
    }
    
    func connectionFailed() {
        showError(string: "there was an error connecting to the chat client.")
    }
    
    func seeIfChannelExists(){
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let currentUser = appDelegate.currentUser
        let ref = Database.database().reference().child("Users").child(currentUser!.uId)
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            if(snapshot.exists()){
                var legacy = false
                var array = [ChatObject]()
                let messagingArray = snapshot.childSnapshot(forPath: "messaging")
                for channel in messagingArray.children{
                    let currentObj = channel as! DataSnapshot
                    let dict = currentObj.value as? [String: Any]
                    let channelUrl = dict?["channelUrl"] as? String ?? ""
                    let otherUser = dict?["otherUser"] as? String ?? ""
                    let legacyUser = dict?["legacy"] as? String ?? ""
                    let otherUserId = dict?["otherUserId"] as? String ?? ""
                    if(legacyUser == "true"){
                        legacy = true
                        break
                    }
                    
                    let chatObj = ChatObject(chatUrl: channelUrl, otherUser: otherUser)
                    chatObj.otherUserId = otherUserId
                    array.append(chatObj)
                }
                
                if(legacy){
                    self.convertChatObjects()
                    return
                }
                
                if(!array.isEmpty){
                    var contained = false
                    for object in array{
                        if(object.otherUserId == self.otherUserId){
                            self.manager?.loadGroupChannel(channelUrl: object.chatUrl, team: false, callbacks: self)
                            contained = true
                            break
                        }
                    }
                    
                    if(!contained){
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        let currentUser = appDelegate.currentUser
                        self.manager?.createTeamChannel(userId: currentUser!.uId, callbacks: self)
                    }
                }
                else{
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    let currentUser = appDelegate.currentUser
                    self.manager?.createTeamChannel(userId: currentUser!.uId, callbacks: self)
                }
            }
            
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    private func convertChatObjects(){
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let currentUser = appDelegate.currentUser
        let ref = Database.database().reference().child("Users").child(currentUser!.uId)
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            if(snapshot.exists()){
                var array = [ChatObject]()
                let messagingArray = snapshot.childSnapshot(forPath: "messaging")
                for channel in messagingArray.children{
                    let currentObj = channel as! DataSnapshot
                    let dict = currentObj.value as? [String: Any]
                    let channelUrl = dict?["channelUrl"] as? String ?? ""
                    let otherUser = dict?["otherUser"] as? String ?? ""
                    
                    let chatObj = ChatObject(chatUrl: channelUrl, otherUser: otherUser)
                    chatObj.otherUserId = self.otherUserId!
                    
                    array.append(chatObj)
                }
                
                if(!array.isEmpty){
                    ref.child("messaging").removeValue()
                    
                    var newArray = [[String: Any]]()
                    for chatObj in array{
                        let newOject = ["channelUrl": chatObj.chatUrl, "otherUser": chatObj.otherUserId, "otherUserId": chatObj.otherUserId, "legacy": "false"] as [String : Any]
                        newArray.append(newOject)
                    }
                    ref.child("messaging").setValue(newArray)
                    
                    self.seeIfChannelExists()
                }
                else{
                    //show error
                }
            }
            
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    func reload(tableView: UITableView) {
        let contentOffset = tableView.contentOffset
        tableView.reloadData()
        tableView.layoutIfNeeded()
        tableView.setContentOffset(contentOffset, animated: false)
    }
    
    private func convertMessages(messages: [SBDUserMessage]){
        let count = messages.count
        
        if(count == 0){
            
        }
        else{
            if(self.emptyShowing){
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIView.animate(withDuration: 0.5, animations: {
                        self.emptyOverlay.alpha = 0
                    }, completion: nil)
                }
                self.emptyShowing = false
            }
            
            chatMessages = [ChatMessage]()
            chatMessages.append(1)
            for message in messages{
                 //Message created time in millisecond(UTC).
                let date = NSDate(timeIntervalSince1970: TimeInterval(message.createdAt))
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd-yyyy HH:mm:ss"
                let result = formatter.string(from: date as Date)
                
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let currentUser = appDelegate.currentUser
                
                let chatMessage = ChatMessage(message: message.message!, timeStamp: result)
                chatMessage.data = message.data ?? ""
                chatMessage.senderString = chatMessage.data
                chatMessage.timeStampMillis = message.createdAt
                
                chatMessages.append(chatMessage)
            }
            
            chatMessages.append(0)
            
            messagingView.delegate = self
            messagingView.dataSource = self
            
            self.messagesSet = true
            
            messagingView.reloadData()
            messagingView.layoutIfNeeded()
            messagingView.heightAnchor.constraint(equalToConstant: messagingView.contentSize.height).isActive = true
            
            reload(tableView: messagingView)
            
            scrollToBottom()
        }
    }
    
    func createTeamChannelSuccessful(groupChannel: SBDGroupChannel) {
        AppEvents.logEvent(AppEvents.Name(rawValue: "Messaging: Create Channel Successful"))
        
        if(team != nil){
            //team channel was empty, attempted to make a new one.
            for user in team!.teammateIds{
                let ref = Database.database().reference().child("Users").child(user)
                    ref.observeSingleEvent(of: .value, with: { (snapshot) in
                        if(snapshot.exists()){
                            var teams = [TeamObject]()
                            let teamsArray = snapshot.childSnapshot(forPath: "teams")
                            for teamObj in teamsArray.children {
                                let currentObj = teamObj as! DataSnapshot
                                let dict = currentObj.value as? [String: Any]
                                let teamName = dict?["teamName"] as? String ?? ""
                                let teamId = dict?["teamId"] as? String ?? ""
                                let games = dict?["games"] as? [String] ?? [String]()
                                let consoles = dict?["consoles"] as? [String] ?? [String]()
                                let teammateTags = dict?["teammateTags"] as? [String] ?? [String]()
                                let teammateIds = dict?["teammateIds"] as? [String] ?? [String]()
                                let captainId = dict?["teamCaptainId"] as? String ?? String()
                                
                                var invites = [TeamInviteObject]()
                                let teamInvites = snapshot.childSnapshot(forPath: "teamInvites")
                                for invite in teamInvites.children{
                                    let currentObj = invite as! DataSnapshot
                                    let dict = currentObj.value as? [String: Any]
                                    let gamerTag = dict?["gamerTag"] as? String ?? ""
                                    let date = dict?["date"] as? String ?? ""
                                    let uid = dict?["uid"] as? String ?? ""
                                    let teamName = dict?["teamName"] as? String ?? ""
                                    
                                    let newInvite = TeamInviteObject(gamerTag: gamerTag, date: date, uid: uid, teamName: teamName)
                                    invites.append(newInvite)
                                }
                                
                                let teamInvitetags = dict?["teamInviteTags"] as? [String] ?? [String]()
                                let captain = dict?["teamCaptain"] as? String ?? ""
                                let imageUrl = dict?["imageUrl"] as? String ?? ""
                                let teamChat = dict?["teamChat"] as? String ?? String()
                                let teamNeeds = dict?["teamNeeds"] as? [String] ?? [String]()
                                let selectedTeamNeeds = dict?["selectedTeamNeeds"] as? [String] ?? [String]()
                                
                                let currentTeam = TeamObject(teamName: teamName, teamId: teamId, games: games, consoles: consoles, teammateTags: teammateTags, teammateIds: teammateIds, teamCaptain: captain, teamInvites: invites, teamChat: teamChat, teamInviteTags: teamInvitetags, teamNeeds: teamNeeds, selectedTeamNeeds: selectedTeamNeeds, imageUrl: imageUrl, teamCaptainId: captainId)
                                
                                var teammateArray = [TeammateObject]()
                                if(currentObj.hasChild("teammates")){
                                    let teammates = currentObj.childSnapshot(forPath: "teammates")
                                    for teammate in teammates.children{
                                        let currentTeammate = teammate as! DataSnapshot
                                        let dict = currentTeammate.value as? [String: Any]
                                        let gamerTag = dict?["gamerTag"] as? String ?? ""
                                        let date = dict?["date"] as? String ?? ""
                                        let uid = dict?["uid"] as? String ?? ""
                                        
                                        let teammate = TeammateObject(gamerTag: gamerTag, date: date, uid: uid)
                                        teammateArray.append(teammate)
                                    }
                                    currentTeam.teammates = teammateArray
                                    teams.append(currentTeam)
                                }
                            }
                            
                            var sendUp = [[String: Any]]()
                            for team in teams{
                                if(team.teamChat.isEmpty){
                                    team.teamChat = groupChannel.channelUrl
                                }
                                
                                let current = ["teamName": team.teamName, "teamId": team.teamId, "games": team.games, "consoles": team.consoles, "teammateTags": team.teammateTags, "teammateIds": team.teammateIds, "teamCaptain": team.teamCaptain, "teamInvites": team.teamInvites, "teamChat": team.teamChat, "teamInviteTags": team.teamInviteTags, "teamNeeds": team.teamNeeds, "selectedTeamNeeds": team.selectedTeamNeeds, "imageUrl": team.imageUrl] as [String : Any]
                                
                                sendUp.append(current)
                            }
                            ref.child("teams").setValue(sendUp)
                        }
                    })
                { (error) in
                    print(error.localizedDescription)
                    self.showError(string: "error initializing team chat.")
                }
            }
        }
        else{
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let currentUser = appDelegate.currentUser
            let ref = Database.database().reference().child("Users").child(currentUser!.uId)
            ref.observeSingleEvent(of: .value, with: { (snapshot) in
                if(snapshot.exists()){
                    var array = [ChatObject]()
                    let messagingArray = snapshot.childSnapshot(forPath: "messaging")
                    for channel in messagingArray.children{
                        let currentObj = channel as! DataSnapshot
                        let dict = currentObj.value as? [String: Any]
                        let channelUrl = dict?["channelUrl"] as? String ?? ""
                        let otherUser = dict?["otherUser"] as? String ?? ""
                        let otherUserId = dict?["otherUserId"] as? String ?? ""
                        
                        let chatObj = ChatObject(chatUrl: channelUrl, otherUser: otherUser)
                        chatObj.otherUserId = otherUserId
                        array.append(chatObj)
                    }
                    
                    let current = ChatObject(chatUrl: groupChannel.channelUrl, otherUser: self.otherUserId!)
                    array.append(current)
                    
                    var sendUp = [[String: String]]()
                    for channel in array{
                        let currentOne = ["channelUrl": channel.chatUrl, "otherUser": channel.otherUser, "otherUserId": self.otherUserId ?? ""]
                        
                        sendUp.append(currentOne)
                    }
                    
                    ref.child("messaging").setValue(sendUp)
                    
                    let ref = Database.database().reference().child("Users").child(self.otherUserId!)
                    ref.observeSingleEvent(of: .value, with: { (snapshot) in
                        if(snapshot.exists()){
                            var array = [ChatObject]()
                            let messagingArray = snapshot.childSnapshot(forPath: "messaging")
                            for channel in messagingArray.children{
                                let currentObj = channel as! DataSnapshot
                                let dict = currentObj.value as? [String: Any]
                                let channelUrl = dict?["channelUrl"] as? String ?? ""
                                let otherUser = dict?["otherUser"] as? String ?? ""
                                let otherUserId = dict?["otherUserId"] as? String ?? ""
                                
                                let chatObj = ChatObject(chatUrl: channelUrl, otherUser: otherUser)
                                chatObj.otherUserId = otherUserId
                                array.append(chatObj)
                            }
                            
                            let current = ChatObject(chatUrl: groupChannel.channelUrl, otherUser: appDelegate.currentUser!.uId)
                            array.append(current)
                            
                            var sendUp = [[String: String]]()
                            for channel in array{
                                let currentOne = ["channelUrl": channel.chatUrl, "otherUser": currentUser!.uId, "otherUserId": currentUser!.uId]
                                
                                sendUp.append(currentOne)
                            }
                            
                            ref.child("messaging").setValue(sendUp)
                            
                        }
                    })
                }
            }) { (error) in
                print(error.localizedDescription)
                self.showError(string: "error initializing chat.")
            }
        }
    }
    
    func createTeamChannelFailed() {
        AppEvents.logEvent(AppEvents.Name(rawValue: "Messaging: Create Channel Failed"))
        
        if(emptyShowing){
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIView.animate(withDuration: 0.5, animations: {
                    self.emptyOverlay.alpha = 0
                }, completion: { (finished: Bool) in
                    self.emptyShowing = false
                    self.showError(string: "there was an issue loading your channel.")
                })
            }
        }
        else{
            self.showError(string: "there was an issue loading your channel.")
        }
    }
    
    private func showError(string: String){
        self.errorText.text = string
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIView.animate(withDuration: 0.5, animations: {
                self.errorOverlay.alpha = 1
            }, completion: nil)
        }
    }
    
    func messageSuccessfullyReceived(message: SBDUserMessage) {
        let date = NSDate(timeIntervalSince1970: TimeInterval(message.createdAt))
                   let formatter = DateFormatter()
                   formatter.dateFormat = "MMMM.dd.yyyy"
                   let result = formatter.string(from: date as Date)
        
        let chatMessage = ChatMessage(message: message.message!, timeStamp: result)
        //let currentUser = appDelegate.currentUser
        //let chatMessage1 = MockMessage(text: message.message!, user: currentUser!, messageId: "", date: Date.init())
        //chatMessage.data = message.data ?? ""
        
        self.addMessage(chatMessage: chatMessage)
    }
    
    func onMessagesLoaded(messages: [SBDUserMessage]) {
        convertMessages(messages: messages)
    }
    
    func successfulLeaveChannel() {
    }
    
    func errorLoadingChannel() {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        let currentUser = delegate.currentUser
        AppEvents.logEvent(AppEvents.Name(rawValue: "Messaging: Error Loading Channel " + currentUser!.uId))
        
        if(emptyShowing){
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIView.animate(withDuration: 0.5, animations: {
                    self.emptyOverlay.alpha = 0
                }, completion: { (finished: Bool) in
                    self.emptyShowing = false
                    self.showError(string: "there was an issue loading your chat.")
                })
            }
        }
        else{
            self.showError(string: "there was an issue loading your chat.")
        }
    }
    
    func errorLoadingMessages() {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        let currentUser = delegate.currentUser
        AppEvents.logEvent(AppEvents.Name(rawValue: "Messaging: Error Loading Messages " + currentUser!.uId))
        
        if(emptyShowing){
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIView.animate(withDuration: 0.5, animations: {
                    self.emptyOverlay.alpha = 0
                }, completion: { (finished: Bool) in
                    self.emptyShowing = false
                    self.showError(string: "there was an issue loading your messages.")
                })
            }
        }
        else{
            self.showError(string: "there was an issue loading your messages.")
        }
    }
    
    func messageSentSuccessfully(chatMessage: ChatMessage, sender: SBDSender) {
        self.addMessage(chatMessage: chatMessage)
    }
    
    private func addMessage(chatMessage: ChatMessage){
        if(self.emptyShowing){
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIView.animate(withDuration: 0.5, animations: {
                    self.emptyOverlay.alpha = 0
                }, completion: nil)
            }
            self.emptyShowing = false
        }
        
        if(!self.chatMessages.isEmpty){
            self.chatMessages.remove(at: self.chatMessages.count - 1)
        }
        self.chatMessages.append(chatMessage)
        self.chatMessages.append(0)
        
        if(self.messagesSet){
            self.messagingView.reloadData()
            scrollToBottom()
        }
        else{
            messagingView.delegate = self
            messagingView.dataSource = self
            reload(tableView: messagingView)
            
            self.messagesSet = true
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
       return self.chatMessages.count
    }

    // There is just one row in every section
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clear
        return headerView
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let current = self.chatMessages[indexPath.section]
        if(current is Int){
            if(current as! Int == 0){
                let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath) as! TestCell
                return cell
            }
            else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath) as! TestCell
                return cell
            }
        }
        else{
            let message = current as! ChatMessage
            if(message.senderString == self.currentUser!.uId){
                if(message.message.contains("DXPGif")){
                    let bit = "DXPGif"
                    let strippedUrl = message.message.substring(from: bit.count, length: message.message.count)
                    
                    let cell = tableView.dequeueReusableCell(withIdentifier: "userGif", for: indexPath) as! GifCellUser
                    let manager = SwiftyGifManager(memoryLimit: 5)
                    cell.gifImage.setGifFromURL(URL(string: strippedUrl)!)
                    manager.addImageView(cell.gifImage)
                    
                    cell.gifImage.contentMode = .scaleAspectFit
                    cell.gifImage.layer.masksToBounds = true
                    cell.gifImage.layer.cornerRadius = 15
                    
                
                    return cell
                }
                else{
                    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TestCell
                    cell.message.text = message.message
                    
                    cell.message.layer.masksToBounds = true
                    cell.message.layer.cornerRadius = 15
                    
                    return cell
                }
            }
            else{
                if(message.message.contains("DXPGif")){
                    let bit = "DXPGif"
                    let strippedUrl = message.message.substring(from: bit.count, length: message.message.count)
                    
                    let cell = tableView.dequeueReusableCell(withIdentifier: "otherGif", for: indexPath) as! GifCellUser
                    let manager = SwiftyGifManager(memoryLimit: 5)
                    cell.gifImage.setGifFromURL(URL(string: strippedUrl)!)
                    manager.addImageView(cell.gifImage)
                    
                    for friend in currentUser!.friends{
                        if(friend.uid == self.otherUserId){
                            cell.gifImageSender.text = "@" + friend.gamerTag
                        }
                    }
                    
                    //cell.gifImage.contentMode = .scaleAspectFit
                    cell.gifImage.layer.masksToBounds = true
                    cell.gifImage.layer.cornerRadius = 15
                    
                
                    return cell
                }
                else{
                    let cell = tableView.dequeueReusableCell(withIdentifier: "otherCell", for: indexPath) as! TestCell
                    cell.message.text = message.message
                    
                    cell.message.layer.masksToBounds = true
                    cell.message.layer.cornerRadius = 15
                    
                    for friend in currentUser!.friends{
                        if(friend.uid == self.otherUserId){
                            cell.tagLabel.text = "@" + friend.gamerTag
                        }
                    }
                    
                    return cell
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if self.messagingView.layer.mask == nil {

            //If you are using auto layout
            //self.view.layoutIfNeeded()

            let maskLayer: CAGradientLayer = CAGradientLayer()

            maskLayer.locations = [0.0, 0.2, 0.8, 1.0]
            let width = self.messagingView.frame.size.width
            let height = self.messagingView.frame.size.height
            maskLayer.bounds = CGRect(x: 0.0, y: 0.0, width: width, height: height)
            maskLayer.anchorPoint = CGPoint.zero

            self.messagingView.layer.mask = maskLayer
        }

        scrollViewDidScroll(self.messagingView)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        let outerColor = UIColor(named: "whiteBackToDarkGrey")?.cgColor
        let innerColor = UIColor(named: "whiteBackToDarkGrey")?.cgColor

        var colors = [CGColor]()

        if scrollView.contentOffset.y + scrollView.contentInset.top <= 0 {
            colors = [(innerColor ?? UIColor.white.cgColor), innerColor ?? UIColor.white.cgColor, innerColor ?? UIColor.white.cgColor, outerColor ?? UIColor.white.cgColor]
        } else if scrollView.contentOffset.y + scrollView.frame.size.height >= scrollView.contentSize.height {
            colors = [outerColor ?? UIColor.white.cgColor, innerColor ?? UIColor.white.cgColor, innerColor ?? UIColor.white.cgColor, innerColor ?? UIColor.white.cgColor]
        } else {
            colors = [outerColor ?? UIColor.white.cgColor, innerColor ?? UIColor.white.cgColor, innerColor ?? UIColor.white.cgColor, outerColor ?? UIColor.white.cgColor]
        }

        if let mask = scrollView.layer.mask as? CAGradientLayer {
            mask.colors = colors

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            mask.position = CGPoint(x: 0.0, y: scrollView.contentOffset.y)
            CATransaction.commit()
        }

    }
    
    func scrollToBottom(){
        DispatchQueue.main.async {
            self.messagingView.scrollToRow(at: NSIndexPath(row: 0, section: self.chatMessages.count - 1) as IndexPath, at: .bottom, animated: true)
        }
    }
    
    func searchSubmitted(searchString: String) {
    }
    
    func messageTextSubmitted(string: String, list: [String]?) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM.dd.yyyy"
        let result = formatter.string(from: date)
        
        let message = ChatMessage(message: string, timeStamp: result)
        message.senderString = currentUser!.uId
        message.data = currentUser!.uId
        
        if(otherUserId != nil){
            message.recipientId = otherUserId!
            message.type = "user"
        }
        else{
            message.recipientId = groupChannelUrl!
            message.type = "team"
        }
        
        
        manager?.sendMessage(chatMessage: message, list: list, team: self.groupChannelUrl != nil)
        /*let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM.dd.yyyy"
        let result = formatter.string(from: date)
        let chatMessage = ChatMessage(message: string, timeStamp: result)
        chatMessage.senderString = currentUser!.uId
        chatMessage.data = list?[0] ?? ""
        
        //self.chatMessages.append(chatMessage)
        //chatMessages.append(0)
        
        addMessage(chatMessage: chatMessage)*/
    }
}

extension UITableView {
    func scrollToBottomRow() {
        DispatchQueue.main.async {
            guard self.numberOfSections > 0 else { return }

            // Make an attempt to use the bottom-most section with at least one row
            var section = max(self.numberOfSections - 1, 0)
            var row = max(self.numberOfRows(inSection: section) - 1, 0)
            var indexPath = IndexPath(row: row, section: section)

            // Ensure the index path is valid, otherwise use the section above (sections can
            // contain 0 rows which leads to an invalid index path)
            while !self.indexPathIsValid(indexPath) {
                section = max(section - 1, 0)
                row = max(self.numberOfRows(inSection: section) - 1, 0)
                indexPath = IndexPath(row: row, section: section)

                // If we're down to the last section, attempt to use the first row
                if indexPath.section == 0 {
                    indexPath = IndexPath(row: 0, section: 0)
                    break
                }
            }

            // In the case that [0, 0] is valid (perhaps no data source?), ensure we don't encounter an
            // exception here
            guard self.indexPathIsValid(indexPath) else { return }

            self.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    func indexPathIsValid(_ indexPath: IndexPath) -> Bool {
        let section = indexPath.section
        let row = indexPath.row
        return section < self.numberOfSections && row < self.numberOfRows(inSection: section)
    }
}
