//
//  WalletMode.swift
//  StripePaymentSheet
//
//  Created by John Woo on 1/26/23.
//

import Foundation
import UIKit
@_spi(STP) import StripeCore
@_spi(STP) import StripePayments
@_spi(STP) import StripePaymentsUI
@_spi(STP) import StripeUICore

public class WalletMode {
    let configuration: WalletMode.Configuration

    private var walletModeViewController: WalletModeViewController?

    lazy var bottomSheetViewController: BottomSheetViewController = {
        let isTestMode = configuration.apiClient.isTestmode
        let loadingViewController = LoadingViewController(
            delegate: self,
            appearance: configuration.appearance,
            isTestMode: isTestMode
        )

        let vc = BottomSheetViewController(
            contentViewController: loadingViewController,
            appearance: configuration.appearance,
            isTestMode: isTestMode,
            didCancelNative3DS2: { [weak self] in
                // TODO: Probably needed due to.. 3ds2 w/ cards
//                self?.paymentHandler.cancel3DS2ChallengeFlow()
            }
        )

        if #available(iOS 13.0, *) {
            configuration.style.configure(vc)
        }
        return vc
    }()

    public init(configuration: WalletMode.Configuration) {
        self.configuration = configuration
    }

    @available(iOSApplicationExtension, unavailable)
    @available(macCatalystApplicationExtension, unavailable)
    public func present(from presentingViewController: UIViewController) {
        // Retain self when being presented, it is not guarnteed that WalletMode instance
        // will be retained by caller
        let completion: () -> Void = {
            if let presentingViewController = self.bottomSheetViewController.presentingViewController {
                // Calling `dismiss()` on the presenting view controller causes
                // the bottom sheet and any presented view controller by
                // bottom sheet (i.e. Link) to be dismissed all at the same time.
                presentingViewController.dismiss(animated: true)
            }
            self.completion = nil
        }
        self.completion = completion

        guard presentingViewController.presentedViewController == nil else {
            assertionFailure("presentingViewController is already presenting a view controller")
            let error = WalletModeError.unknown(
                debugDescription: "presentingViewController is already presenting a view controller"
            )
            configuration.delegate?.didError(error)
            return
        }
        loadPaymentMethods() { result in
            switch(result) {
            case .success(let savedPaymentMethods):
                self.present(from: presentingViewController, savedPaymentMethods: savedPaymentMethods)
            case .failure(let error):
                self.configuration.delegate?.didError(.errorFetchingSavedPaymentMethods(error))
                return
            }
        }
        presentingViewController.presentAsBottomSheet(bottomSheetViewController,
                                                      appearance: configuration.appearance)
    }

    @available(iOSApplicationExtension, unavailable)
    @available(macCatalystApplicationExtension, unavailable)
    public func load() {
        let loadSpecsPromise = Promise<Void>()

        AddressSpecProvider.shared.loadAddressSpecs {
            loadSpecsPromise.resolve(with: ())
        }
        loadPaymentMethods() { loadResult in
            loadSpecsPromise.observe { _ in
                switch(loadResult) {
                case .success(let savedPaymentMethods):
                    let flowController = FlowController(savedPaymentMethods: savedPaymentMethods,
                                                        configuration: self.configuration)

                    if let paymentOption = flowController.paymentOption {
                        _ = paymentOption.displayData.image
                        let paymentOptionSelection = PaymentOptionSelection(paymentMethodId: paymentOption.paymentMethodId,
                                                                            displayData: PaymentOptionSelection.PaymentOptionDisplayData(image: paymentOption.displayData.image,
                                                                                                                                         label: paymentOption.displayData.label))
                        self.configuration.delegate?.didLoadWith(paymentOptionSelection: paymentOptionSelection)
                    } else {
                        self.configuration.delegate?.didLoadWith(paymentOptionSelection: nil)
                    }
                case .failure(let error):
                    self.configuration.delegate?.didError(.errorFetchingSavedPaymentMethods(error))
                }
            }
        }
    }

    @available(iOSApplicationExtension, unavailable)
    @available(macCatalystApplicationExtension, unavailable)
    func present(from presentingViewController: UIViewController,
                 savedPaymentMethods: [STPPaymentMethod]) {
        let loadSpecsPromise = Promise<Void>()

        AddressSpecProvider.shared.loadAddressSpecs {
            loadSpecsPromise.resolve(with: ())
        }
        loadSpecsPromise.observe { _ in
            DispatchQueue.main.async {
                let walletViewController = WalletModeViewController(savedPaymentMethods: savedPaymentMethods,
                                                                    configuration: self.configuration,
                                                                    delegate: self)
                self.bottomSheetViewController.contentStack = [walletViewController]
            }
        }
    }
    // MARK: - Internal Properties
    var completion: (() -> Void)?
}

extension WalletMode {
    func loadPaymentMethods(completion: @escaping (Result<[STPPaymentMethod], WalletModeError>) -> Void) {
//        TODO: Implement savedPaymentMethodTypes filtering!
//        let savedPaymentMethodTypes: [STPPaymentMethodType] = [.card]
        configuration.customerContext.listPaymentMethodsForCustomer {
            paymentMethods, error in
            guard let paymentMethods = paymentMethods, error == nil else {
                // TODO: Pass errors from the customerContext
                let error = PaymentSheetError.unknown(debugDescription: "Failed to retrieve PaymentMethods for the customer")
//                let error = error ?? PaymentSheetError.unknown(
//                    debugDescription: "Failed to retrieve PaymentMethods for the customer"
//                )
                completion(.failure(.errorFetchingSavedPaymentMethods(error)))
                return
            }
            completion(.success(paymentMethods))
        }

    }

}

extension WalletMode: WalletModeViewControllerDelegate {
    func walletModeViewControllerDidCancel(_ walletModeViewController: WalletModeViewController) {
        walletModeViewController.dismiss(animated: true) {
            self.completion?()
        }
    }

    func walletModeViewControllerDidFinish(_ walletModeViewController: WalletModeViewController) {
        walletModeViewController.dismiss(animated: true) {
            self.completion?()
        }
    }
}

extension WalletMode: LoadingViewControllerDelegate {
    func shouldDismiss(_ loadingViewController: LoadingViewController) {
        loadingViewController.dismiss(animated: true) {
            self.completion?()
        }
    }
}


extension STPCustomerContext {
    /// Returns the currently selected Payment Option for this customer context.
    /// You can use this to obtain the selected payment method without loading the WalletMode sheet.
    public func retrieveSelectedPaymentOption(
        completion: @escaping (WalletMode.PaymentOptionSelection?, Error?) -> Void
    ) {
//        TODO: Implement this!
        self.retrieveSelectedPaymentMethodID { _, _ in
            completion(nil, nil)
        }
    }
}
