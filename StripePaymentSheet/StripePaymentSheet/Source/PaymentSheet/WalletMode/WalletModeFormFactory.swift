//
//  WalletModeFormFactory.swift
//  StripePaymentSheet
//

@_spi(STP) import StripeCore
@_spi(STP) import StripePayments
@_spi(STP) import StripePaymentsUI
@_spi(STP) import StripeUICore
import SwiftUI
import UIKit

class WalletModeFormFactory {

    let paymentMethod: PaymentSheet.PaymentMethodType
    let intent: Intent
    let configuration: WalletMode.Configuration
    let addressSpecProvider: AddressSpecProvider

    var theme: ElementsUITheme {
        return configuration.appearance.asElementsTheme
    }

    init(
        intent: Intent,
        configuration: WalletMode.Configuration,
        addressSpecProvider: AddressSpecProvider = .shared,
        paymentMethod: PaymentSheet.PaymentMethodType
    ) {
        self.intent = intent
        self.configuration = configuration
        self.paymentMethod = paymentMethod
        self.addressSpecProvider = addressSpecProvider
    }

    func make() -> PaymentMethodElement {
        if paymentMethod == .card {
            return makeCard(theme: theme)
        }
        assert(false, "Currently only support cards")
    }

    func makeCard(theme: ElementsUITheme = .default) -> PaymentMethodElement {
//        let saveCheckbox = makeSaveCheckbox(
//            label: String.Localized.save_this_card_for_future_$merchant_payments(
//                merchantDisplayName: configuration.merchantDisplayName
//            )
//        )
//        let shouldDisplaySaveCheckbox: Bool = saveMode == .userSelectable && !canSaveToLink
        let cardFormElement = FormElement(elements: [
            CardSection(theme: theme),
            //shouldDisplaySaveCheckbox ? saveCheckbox : nil,
        ], theme: theme)
//        if isLinkEnabled {
//            return LinkEnabledPaymentMethodElement(
//                type: .card,
//                paymentMethodElement: cardFormElement,
//                configuration: configuration,
//                linkAccount: nil,
//                country: intent.countryCode
//            )
//        } else {
            return cardFormElement
//        }
    }
}
