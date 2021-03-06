//
//  WebViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/10/17.
//  Copyright © 2017 Robbie Trencheny. All rights reserved.
//

import UIKit
import WebKit
import KeychainAccess
import PromiseKit

class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, ConnectionInfoChangedDelegate {

    var webView: WKWebView!

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        let statusBarView: UIView = UIView(frame: .zero)
        statusBarView.tag = 111
        if let themeColor = prefs.string(forKey: "themeColor") {
            statusBarView.backgroundColor = UIColor.init(hex: themeColor)
        } else {
            statusBarView.backgroundColor = UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)
        }
        view.addSubview(statusBarView)

        statusBarView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        statusBarView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        statusBarView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        statusBarView.bottomAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true

        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        config.userContentController = userContentController

        webView = WKWebView(frame: self.view!.frame, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        self.updateWebViewSettings()
        self.view!.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false

        webView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: self.topLayoutGuide.bottomAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: self.bottomLayoutGuide.topAnchor).isActive = true

        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        HomeAssistantAPI.sharedInstance.Setup(baseURLString: keychain["baseURL"], password: keychain["apiPassword"],
                                              deviceID: keychain["deviceID"])
        if HomeAssistantAPI.sharedInstance.Configured {
            HomeAssistantAPI.sharedInstance.Connect().then { _ -> Void in
                if HomeAssistantAPI.sharedInstance.notificationsEnabled {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                print("Connected!")
                if let baseURL = HomeAssistantAPI.sharedInstance.baseURL {
                    let myRequest = URLRequest(url: baseURL)
                    self.webView.load(myRequest)
                }
                return
            }.catch {err -> Void in
                print("Error on connect!!!", err)
                let settingsView = SettingsViewController()
                settingsView.showErrorConnectingMessage = true
                settingsView.showErrorConnectingMessageError = err
                settingsView.doneButton = true
                settingsView.delegate = self
                let navController = UINavigationController(rootViewController: settingsView)
                self.present(navController, animated: true, completion: nil)
            }
        } else {
            let settingsView = SettingsViewController()
            settingsView.doneButton = true
            settingsView.delegate = self
            let navController = UINavigationController(rootViewController: settingsView)
            self.present(navController, animated: true, completion: nil)
        }
    }

    // Workaround for webview rotation issues: https://github.com/Telerik-Verified-Plugins/WKWebView/pull/263
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.webView?.setNeedsLayout()
            self.webView?.layoutIfNeeded()
        }, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        var toolbarItems: [UIBarButtonItem] = []

        var tabBarIconColor = UIColor(red: 0.01, green: 0.66, blue: 0.96, alpha: 1.0)

        if let themeColor = prefs.string(forKey: "themeColor") {
            tabBarIconColor = UIColor.init(hex: themeColor)
            if let statusBarView = self.view.viewWithTag(111) {
                statusBarView.backgroundColor = UIColor.init(hex: themeColor)
            }
        }

        if HomeAssistantAPI.sharedInstance.locationEnabled {

            let uploadIcon = getIconForIdentifier("mdi:upload",
                                                  iconWidth: 30, iconHeight: 30,
                                                  color: tabBarIconColor)

            toolbarItems.append(UIBarButtonItem(image: uploadIcon,
                                                style: .plain,
                                                target: self,
                                                action: #selector(sendCurrentLocation(_:))
                )
            )

            let mapIcon = getIconForIdentifier("mdi:map", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)

            toolbarItems.append(UIBarButtonItem(image: mapIcon,
                                                style: .plain,
                                                target: self,
                                                action: #selector(openMapView(_:))))
        }

        toolbarItems.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))

        let refreshIcon = getIconForIdentifier("mdi:reload", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)

        toolbarItems.append(UIBarButtonItem(image: refreshIcon,
                                            style: .plain,
                                            target: self,
                                            action: #selector(refreshWebView(_:))))

        let settingsIcon = getIconForIdentifier("mdi:settings", iconWidth: 30, iconHeight: 30, color: tabBarIconColor)

        toolbarItems.append(UIBarButtonItem(image: settingsIcon,
                                            style: .plain,
                                            target: self,
                                            action: #selector(openSettingsView(_:))))

        self.setToolbarItems(toolbarItems, animated: false)
        self.navigationController?.toolbar.tintColor = tabBarIconColor

        if HomeAssistantAPI.sharedInstance.Configured {
            if let baseURL = HomeAssistantAPI.sharedInstance.baseURL {
                let myRequest = URLRequest(url: baseURL)
                self.webView.load(myRequest)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            openURLInBrowser(urlToOpen: navigationAction.request.url!)
        }
        return nil
    }

    @objc func refreshWebView(_ sender: UIButton) {
        self.webView.reload()
    }

    @objc func openSettingsView(_ sender: UIButton) {
        let settingsView = SettingsViewController()
        settingsView.doneButton = true
        settingsView.hidesBottomBarWhenPushed = true
        settingsView.delegate = self

        let navController = UINavigationController(rootViewController: settingsView)
        self.present(navController, animated: true, completion: nil)
    }

    @objc func openMapView(_ sender: UIButton) {
        let devicesMapView = DevicesMapViewController()

        let navController = UINavigationController(rootViewController: devicesMapView)
        self.present(navController, animated: true, completion: nil)
    }

    @objc func sendCurrentLocation(_ sender: UIButton) {
        HomeAssistantAPI.sharedInstance.getAndSendLocation(trigger: .Manual).then { _ -> Void in
            let alert = UIAlertController(title: L10n.ManualLocationUpdateNotification.title,
                                          message: L10n.ManualLocationUpdateNotification.message,
                                          preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            }.catch {error in
                let nserror = error as NSError
                let message = L10n.ManualLocationUpdateFailedNotification.message(nserror.localizedDescription)
                let alert = UIAlertController(title: L10n.ManualLocationUpdateFailedNotification.title,
                                              message: message,
                                              preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
        }
    }

    func userReconnected() {
        print("User reconnected! Reset the web view!")
        updateWebViewSettings()
    }

    func updateWebViewSettings() {
        self.webView.configuration.userContentController.removeAllUserScripts()
        if let apiPass = keychain["apiPassword"] {
            let scriptStr = "window.hassConnection = createHassConnection(\"\(apiPass)\");"
            let script = WKUserScript(source: scriptStr, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            self.webView.configuration.userContentController.addUserScript(script)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
