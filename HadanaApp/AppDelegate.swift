import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        application.registerForRemoteNotifications()

        // التطبيق كان مسكر وفُتح بسبب الإشعار
        if let notifInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleNotificationData(notifInfo)
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        NotificationCenter.default.post(name: .fcmTokenRefreshed, object: token)
    }

    // التطبيق مفتوح أو بالـ background — المستخدم ضغط على الإشعار
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        handleNotificationData(info)
        handler()
    }

    // التطبيق مفتوح — يعرض الإشعار كـ banner
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }

    private func handleNotificationData(_ info: [AnyHashable: Any]) {
        // FCM يحط الـ data في المستوى الأعلى مباشرة
        let type       = info["type"]       as? String ?? ""
        let sessionId  = info["session_id"] as? String

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .parentNotificationTapped,
                object: nil,
                userInfo: ["type": type, "session_id": sessionId ?? ""]
            )
        }
    }
}

extension Notification.Name {
    static let fcmTokenRefreshed       = Notification.Name("fcmTokenRefreshed")
    static let parentNotificationTapped = Notification.Name("parentNotificationTapped")
}
