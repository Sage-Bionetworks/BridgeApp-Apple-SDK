//
//  SBAAppDelegate.swift
//  BridgeApp (iOS)
//
//  Copyright © 2016-2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import UIKit

/// `SBAAppDelegate` is an optional class that can be used as the appDelegate for an application.
open class SBAAppDelegate : RSDAppDelegate, SBBBridgeErrorUIDelegate {
    
    public final class var shared: SBAAppDelegate? {
        return UIApplication.shared.delegate as? SBAAppDelegate
    }
    
    // MARK: UIApplicationDelegate
    
    open func instantiateBridgeConfiguration() -> SBABridgeConfiguration {
        return SBABridgeConfiguration()
    }
    
    open override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        guard super.application(application, willFinishLaunchingWithOptions: launchOptions)
            else {
                return false
        }
        
        // Set up bridge.
        BridgeSDK.setErrorUIDelegate(self)
        SBABridgeConfiguration.shared = instantiateBridgeConfiguration()
        SBABridgeConfiguration.shared.setupBridge(with: instantiateFactory())
        
        // Replace the launch root view controller with an SBARootViewController
        // This allows transitioning between root view controllers while a lock screen
        // or onboarding view controller is being presented modally.
        self.window?.rootViewController = SBARootViewController(rootViewController: self.window?.rootViewController)
        
        return true
    }
    
    open func applicationDidBecomeActive(_ application: UIApplication) {
        // Make sure that the content view controller is not hiding content.
        rootViewController?.contentHidden = false
    }
    
    open func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if identifier == kBackgroundSessionIdentifier {
            BridgeSDK.restoreBackgroundSession(identifier, completionHandler: completionHandler)
        }
    }

    // ------------------------------------------------
    // MARK: RootViewController management
    // ------------------------------------------------
    
    /// The root view controller for this app. By default, this is set up in `willFinishLaunchingWithOptions`
    /// as the root view controller for the key window. This container view controller allows presenting
    /// onboarding flow or a passcode modally while transitioning the underlying view controller for the
    /// appropriate app state.
    open var rootViewController: SBARootViewController? {
        return window?.rootViewController as? SBARootViewController
    }
    
    /// Current "state" of the app.
    public var currentState: SBAApplicationState {
        return rootViewController?.state ?? _currentState ?? .launch
    }
    private var _currentState: SBAApplicationState?
    
    /// Convenience method for transitioning to the given view controller as the main window
    /// rootViewController.
    /// - parameters:
    ///     - viewController: View controller to transition to.
    ///     - state: State of the app.
    ///     - animated: Should the transition be animated?
    open func transition(to viewController: UIViewController, state: SBAApplicationState, animated: Bool) {
        // Do not continue if this is called before the app has finished launching.
        guard let window = self.window, currentState != state else { return }
        
        // Do not continue if there is a catastrophic error and this is **not** transitioning to that state.
        guard !hasCatastrophicError || (state == .catastrophicError) else {
            if currentState != .catastrophicError {
                showCatastrophicStartupErrorViewController(animated: animated)
            }
            return
        }
        _currentState = state
        
        if let root = self.rootViewController {
            root.set(viewController: viewController, state: state, animated: animated)
        }
        else {
            if (animated) {
                UIView.transition(with: window,
                                  duration: 0.3,
                                  options: .transitionCrossDissolve,
                                  animations: {
                                    window.rootViewController = viewController
                },
                                  completion: nil)
            }
            else {
                window.rootViewController = viewController
            }
        }
    }
    
    
    // ------------------------------------------------
    // MARK: Catastrophic startup errors
    // ------------------------------------------------
    
    private var catastrophicStartupError: Error?
    
    /// Catastrophic Errors are errors from which the system cannot recover. By default,
    /// this will display a screen that blocks all activity. The user is then asked to
    /// update their app.
    ///
    /// - parameter animated:  Should the transition be animated?
    open func showCatastrophicStartupErrorViewController(animated: Bool) {
        
        guard self.rootViewController?.state != .catastrophicError else { return }
        
        // If we cannot open the catastrophic error view controller (for some reason)
        // then this is a fatal error
        guard let vc = SBACatastrophicErrorViewController.instantiateWithMessage(catastrophicErrorMessage) else {
            fatalError(catastrophicErrorMessage)
        }
        
        // Present the view controller
        transition(to: vc, state: .catastrophicError, animated: animated)
    }
    
    /// Is there a catastrophic error?
    public final var hasCatastrophicError: Bool {
        return (catastrophicStartupError != nil)
    }
    
    /// Register a catastrophic error. Once launch is complete, this will trigger showing
    /// the error.
    public final func registerCatastrophicStartupError(_ error: Error) {
        self.catastrophicStartupError = error
    }
    
    /// The error message to display for a catastrophic error.
    open var catastrophicErrorMessage: String {
        return catastrophicStartupError?.localizedDescription ??
            Localization.localizedString("CATASTROPHIC_FAILURE_MESSAGE")
    }
    
    
    // ------------------------------------------------
    // MARK: SBBBridgeErrorUIDelegate
    // ------------------------------------------------
    
    /// Default implementation for handling a user who is not consented (because consent has been revoked
    /// by the server).
    open func handleUserNotConsentedError(_ error: Error, sessionInfo: Any, networkManager: SBBNetworkManagerProtocol?) -> Bool {
        // TODO: syoung 05/08/2018 Handle unconsented user.
        return true
    }
    
    /// Default implementation for handling an unsupported app version is to display a catastrophic error.
    open func handleUnsupportedAppVersionError(_ error: Error, networkManager: SBBNetworkManagerProtocol?) -> Bool {
        registerCatastrophicStartupError(error)
        DispatchQueue.main.async {
            if let _ = self.window?.rootViewController {
                self.showCatastrophicStartupErrorViewController(animated: true)
            }
        }
        return true
    }
}

