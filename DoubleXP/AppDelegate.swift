//
//  AppDelegate.swift
//  DoubleXP
//
//  Created by Peterson, Toussaint on 2/2/19.
//  Copyright © 2019 Peterson, Toussaint. All rights reserved.
//

import UIKit
import CoreData
import Firebase
import TwitterKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {

    var window: UIWindow?
    var appProperties: NSDictionary = [:]
    var gcGames: [GamerConnectGame]!
    var freeAgentProfiles: [FreeAgentObject]!
    var selectedGCGame: GamerConnectGame?
    var currentUser: User?
    var currentLanding: LandingActivity?
    var currentFrag: String = ""
    var interviewManager = InterviewManager()
    var mediaManager = MediaManager()
    var navStack = [UIViewController]()
    var mediaCache = MediaCache()
    
    private var apnsToken: String = ""
    private var fcmToken: String = ""

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        gcGames = [GamerConnectGame]()
        freeAgentProfiles = [FreeAgentObject]()
        // Override point for customization after application launch.
        
        FirebaseApp.configure()
        
        Messaging.messaging().delegate = self
        
        
        TWTRTwitter.sharedInstance().start(withConsumerKey: "sEWJZFZjZAIaxwZUrzdd2JPeI", consumerSecret: "K2yk5yy8AHmyC4mMFHecB1WBoowFnf4uMs4ET7zEjFe06hWmCm")
        
        if #available(iOS 10.0, *) {
          // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
            }
            else {
                    let settings: UIUserNotificationSettings =
                    UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
                    application.registerUserNotificationSettings(settings)
        }

        application.registerForRemoteNotifications()
        
        getToken()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "DoubleXP")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func getToken(){
        InstanceID.instanceID().instanceID { (result, error) in
          if let error = error {
            print("Error fetching remote instance ID: \(error)")
          } else if let result = result {
            print("Remote instance ID token: \(result.token)")
            
            //self.instanceIDTokenMessage.text  = "Remote InstanceID token: \(result.token)"
          }
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
         Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        //if let messageID = userInfo[gcmMessageIDKey] {
       //     print("Message ID: \(messageID)")
        //}

        // Print full message.
        print(userInfo)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // With swizzling disabled you must let Messaging know about the message, for Analytics
         Messaging.messaging().appDidReceiveMessage(userInfo)
        // Print message ID.
        //if let messageID = userInfo[gcmMessageIDKey] {
        //    print("Message ID: \(messageID)")
        //}

        // Print full message.
        print(userInfo)

        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        print("Received data message: \(remoteMessage.appData)")

    }
    // [END ios_10_data_message]

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")

        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        //  Register.
        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        print("deviceTokenString: \(deviceTokenString)")
        self.apnsToken = deviceTokenString

        //set apns token in messaging
        Messaging.messaging().apnsToken = deviceToken

        //get FCM token
        if let token = Messaging.messaging().fcmToken {
            self.fcmToken = token
            print("FCM token: \(token)")
        }

        //subscribe to topic to send message to multiple device
        //self.subscribeToTopic()
    }
}

