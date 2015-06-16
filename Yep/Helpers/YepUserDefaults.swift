//
//  YepUserDefaults.swift
//  Yep
//
//  Created by NIX on 15/3/17.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import RealmSwift

let v1AccessTokenKey = "v1AccessToken"
let userIDKey = "userID"
let nicknameKey = "nickname"
let introductionKey = "introduction"
let avatarURLStringKey = "avatarURLString"
let pusherIDKey = "pusherID"

let areaCodeKey = "areaCode"
let mobileKey = "mobile"


struct Listener<T>: Hashable {
    let name: String

    typealias Action = T -> Void
    let action: Action

    var hashValue: Int {
        return name.hashValue
    }
}

func ==<T>(lhs: Listener<T>, rhs: Listener<T>) -> Bool {
    return lhs.name == rhs.name
}

class Listenable<T> {
    var value: T {
        didSet {
            setterAction(value)

            for listener in listenerSet {
                listener.action(value)
            }
        }
    }

    typealias SetterAction = T -> Void
    var setterAction: SetterAction

    var listenerSet = Set<Listener<T>>()

    func bindListener(name: String, action: Listener<T>.Action) {
        let listener = Listener(name: name, action: action)

        listenerSet.insert(listener)
    }

    func bindAndFireListener(name: String, action: Listener<T>.Action) {
        bindListener(name, action: action)

        action(value)
    }

    func removeListenerWithName(name: String) {
        for listener in listenerSet {
            if listener.name == name {
                listenerSet.remove(listener)
            }
        }
    }

    init(_ v: T, setterAction action: SetterAction) {
        value = v
        setterAction = action
    }
}

class YepUserDefaults {

    // MARK: ReLogin

    class func cleanAllUserDefaults() {
        let defaults = NSUserDefaults.standardUserDefaults()

        defaults.removeObjectForKey(v1AccessTokenKey)
        defaults.removeObjectForKey(userIDKey)
        defaults.removeObjectForKey(nicknameKey)
        defaults.removeObjectForKey(introductionKey)
        defaults.removeObjectForKey(avatarURLStringKey)
        defaults.removeObjectForKey(pusherIDKey)

        defaults.removeObjectForKey(areaCodeKey)
        defaults.removeObjectForKey(mobileKey)
    }

    class func userNeedRelogin() {

        cleanRealmAndCaches()

        cleanAllUserDefaults()

        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            if let rootViewController = appDelegate.window?.rootViewController {
                YepAlert.alert(title: NSLocalizedString("Sorry", comment: ""), message: NSLocalizedString("User authentication error, you need to login again!", comment: ""), dismissTitle: NSLocalizedString("Relogin", comment: ""), inViewController: rootViewController, withDismissAction: { () -> Void in

                    appDelegate.startIntroStory()
                })
            }
        }
    }

    static var v1AccessToken: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let v1AccessToken = defaults.stringForKey(v1AccessTokenKey)

        return Listenable<String?>(v1AccessToken) { v1AccessToken in
            defaults.setObject(v1AccessToken, forKey: v1AccessTokenKey)

            if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
                // 注册或初次登录时同步数据的好时机
                appDelegate.sync()

                // 也是注册或初次登录时启动 Faye 的好时机
                appDelegate.startFaye()
            }
        }
        }()

    static var userID: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let userID = defaults.stringForKey(userIDKey)

        return Listenable<String?>(userID) { userID in
            defaults.setObject(userID, forKey: userIDKey)
        }
        }()

    static var nickname: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let nickname = defaults.stringForKey(nicknameKey)

        return Listenable<String?>(nickname) { nickname in
            defaults.setObject(nickname, forKey: nicknameKey)

            let realm = Realm()

            if let
                nickname = nickname,
                myUserID = YepUserDefaults.userID.value,
                me = userWithUserID(myUserID, inRealm: realm) {
                    realm.beginWrite()
                    me.nickname = nickname
                    realm.commitWrite()
            }
        }
        }()

    static var introduction: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let introduction = defaults.stringForKey(introductionKey)

        return Listenable<String?>(introduction) { introduction in
            defaults.setObject(introduction, forKey: introductionKey)

            let realm = Realm()

            if let
                introduction = introduction,
                myUserID = YepUserDefaults.userID.value,
                me = userWithUserID(myUserID, inRealm: realm) {
                    realm.beginWrite()
                    me.introduction = introduction
                    realm.commitWrite()
            }
        }
        }()

    static var avatarURLString: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let avatarURLString = defaults.stringForKey(avatarURLStringKey)

        return Listenable<String?>(avatarURLString) { avatarURLString in
            defaults.setObject(avatarURLString, forKey: avatarURLStringKey)

            let realm = Realm()

            if let
                avatarURLString = avatarURLString,
                myUserID = YepUserDefaults.userID.value,
                me = userWithUserID(myUserID, inRealm: realm) {
                    let realm = Realm()
                    realm.beginWrite()
                    me.avatarURLString = avatarURLString
                    realm.commitWrite()
            }
        }
        }()

    static var pusherID: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let pusherID = defaults.stringForKey(pusherIDKey)

        return Listenable<String?>(pusherID) { pusherID in
            defaults.setObject(pusherID, forKey: pusherIDKey)

            // 注册推送的好时机
            if let
                pusherID = pusherID,
                appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
                    if appDelegate.notRegisteredPush {
                        appDelegate.notRegisteredPush = false

                        if let deviceToken = appDelegate.deviceToken {
                            appDelegate.registerThirdPartyPushWithDeciveToken(deviceToken, pusherID: pusherID)
                        }
                    }
            }
        }
        }()

    static var areaCode: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let areaCode = defaults.stringForKey(areaCodeKey)

        return Listenable<String?>(areaCode) { areaCode in
            defaults.setObject(areaCode, forKey: areaCodeKey)
        }
        }()

    static var mobile: Listenable<String?> = {
        let defaults = NSUserDefaults.standardUserDefaults()
        let mobile = defaults.stringForKey(mobileKey)

        return Listenable<String?>(mobile) { mobile in
            defaults.setObject(mobile, forKey: mobileKey)
        }
        }()

}


