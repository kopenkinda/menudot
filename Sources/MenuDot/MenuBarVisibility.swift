import Foundation
import ObjectiveC
import Darwin

/// The only private API boundary. No preference writes, injection, or process restarts.
@MainActor
final class MenuBarVisibility {
    private var assertion: NSObject?
    private var generation = 0
    private var timeout: DispatchWorkItem?
    private let configurationClass: AnyClass?
    private let assertionClass: AnyClass?

    private static let configurationSelector = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
    private static let activationSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
    private static let invalidationSelector = NSSelectorFromString("invalidate")

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_LAZY)
        configurationClass = handle == nil ? nil : NSClassFromString("MBAssessmentModeConfiguration")
        assertionClass = handle == nil ? nil : NSClassFromString("MBAssessmentModeAssertion")
        // Keep the framework loaded for the lifetime of objects and their IMPs.
    }

    var isAvailable: Bool {
        guard let configurationClass, let assertionClass else { return false }
        return class_getInstanceMethod(configurationClass, Self.configurationSelector) != nil
            && class_getInstanceMethod(assertionClass, Self.activationSelector) != nil
            && class_getInstanceMethod(assertionClass, Self.invalidationSelector) != nil
    }

    func restore() {
        generation += 1
        timeout?.cancel()
        timeout = nil
        if let assertion {
            typealias Invalidate = @convention(c) (AnyObject, Selector) -> Void
            let method = class_getMethodImplementation(type(of: assertion), Self.invalidationSelector)!
            unsafeBitCast(method, to: Invalidate.self)(assertion, Self.invalidationSelector)
        }
        assertion = nil
    }

    func apply(apps: [String], systemItems: [Int], completion: @escaping @MainActor (String?) -> Void) {
        restore()
        guard isAvailable, let configurationClass, let assertionClass else {
            completion("Hiding is unavailable on this macOS build. All icons remain unchanged.")
            return
        }

        // These signatures were checked against this OS's Objective-C runtime.
        typealias Allocate = @convention(c) (AnyClass, Selector) -> Unmanaged<NSObject>
        typealias Configure = @convention(c) (AnyObject, Selector, NSArray, NSArray) -> Unmanaged<NSObject>?
        typealias Initialize = @convention(c) (AnyObject, Selector) -> Unmanaged<NSObject>?
        typealias Callback = @convention(block) (NSError?) -> Void
        typealias Activate = @convention(c) (AnyObject, Selector, AnyObject, Callback) -> Void

        let alloc = NSSelectorFromString("alloc")
        func allocate(_ cls: AnyClass) -> NSObject {
            let implementation = class_getMethodImplementation(object_getClass(cls), alloc)!
            return unsafeBitCast(implementation, to: Allocate.self)(cls, alloc).takeUnretainedValue()
        }
        let configIMP = class_getMethodImplementation(configurationClass, Self.configurationSelector)!
        guard let configuration = unsafeBitCast(configIMP, to: Configure.self)(
            allocate(configurationClass), Self.configurationSelector,
            systemItems.map(NSNumber.init(value:)) as NSArray, apps as NSArray
        )?.takeRetainedValue() else {
            completion("macOS could not create a visibility configuration.")
            return
        }
        let initializer = NSSelectorFromString("init")
        let initIMP = class_getMethodImplementation(assertionClass, initializer)!
        guard let current = unsafeBitCast(initIMP, to: Initialize.self)(
            allocate(assertionClass), initializer
        )?.takeRetainedValue() else {
            completion("macOS could not create a visibility session.")
            return
        }
        assertion = current
        let token = generation
        let deadline = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            self.restore()
            completion("macOS did not respond. Hiding has been stopped.")
        }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: deadline)
        let callback: Callback = { [weak self] error in
            let message = error?.localizedDescription
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.timeout?.cancel()
                self.timeout = nil
                if message != nil { self.restore() }
                completion(message)
            }
        }
        let implementation = class_getMethodImplementation(assertionClass, Self.activationSelector)!
        unsafeBitCast(implementation, to: Activate.self)(current, Self.activationSelector, configuration, callback)
    }
}
