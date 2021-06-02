//
//  EventSetupViewController.swift
//  Date Dots
//
//  Created by Aaron Williamson on 5/3/20.
//  Copyright © 2020 Aaron Williamson. All rights reserved.
//

import UIKit
import CoreData

enum EventSetupType {
    case add
    case edit
}

class EventSetupViewController: UIViewController {
    
    // MARK: Constants
    
    private enum Constant {
        static let title = "New Event"
        static let keyboardHeight: CGFloat = 216
    }
    
    // MARK: UI
    
    private lazy var saveBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveEvent))
    }()
    
    private lazy var baseView: EventSetupView = {
        let view = EventSetupView()
        view.delegate = self
        return view
    }()
    
    // MARK: Properties
    
//    var eventSetupDelegate: EventSetupDelegate?
    private let viewModel = EventSetupViewModel()

    var event: Event?
    
    // MARK: Lifecycle
 
    override func loadView() {
        view = baseView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        if let event = event {
            baseView.populate(with: viewModel.generateEditContent(for: event))
        } else {
            baseView.populate(with: viewModel.generateAddContent())
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }
    
    private func configureView() {
        title = Constant.title
        navigationItem.rightBarButtonItem = saveBarButtonItem
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: User Actions

    @objc
    func saveEvent() {
        saveContext()
    }
    
    private func saveContext() {
        guard
            // Deprecated
            let eventName = viewModel.eventName,
            let eventNameAbbreviated = viewModel.eventNameAbbreviated,
            
            let eventGivenName = viewModel.givenName,
            let eventType = viewModel.eventType,
            let eventDate = viewModel.eventDate,
            let eventDateString = viewModel.eventDateString,
            let eventEntity = NSEntityDescription.entity(forEntityName: "Event", in: CoreDataManager.shared.viewContext),
            let addressEntity = NSEntityDescription.entity(forEntityName: "Address", in: CoreDataManager.shared.viewContext)
        else {
            return
        }
        
        let event = self.event ?? Event(entity: eventEntity, insertInto: CoreDataManager.shared.viewContext)
        // Deprecated
        event.name = eventName
        event.abbreviatedName = eventNameAbbreviated
        
        event.givenName = eventGivenName
        event.familyName = viewModel.familyName
        event.type = eventType.rawValue
        event.date = eventDate
        event.equalizedDate = eventDateString
        
        let address = Address(entity: addressEntity, insertInto: CoreDataManager.shared.viewContext)
        address.street = viewModel.eventAddressOne
        address.region = viewModel.eventAddressTwo
        
        event.address = address
        
        do {
            try CoreDataManager.save()
            viewModel.rescheduleNotificationIfNeeded {
                // TODO: Update event (with `Event`)
                self.navigationController?.popViewController(animated: true)
            }
        } catch {
            showAlert(withError: error.localizedDescription)
        }
    }
    
    @objc
    func keyboardWillShow(_ notification: NSNotification) {
        let adjustedViewHeight = viewModel.adjustedViewHeight(willShow: true, yOrigin: view.frame.origin.y, for: notification)

        view.frame.origin.y += adjustedViewHeight
    }

    @objc
    func keyboardWillHide(_ notification: NSNotification) {
        let adjustedViewHeight = viewModel.adjustedViewHeight(willShow: false, yOrigin: view.frame.origin.y, for: notification)

        view.frame.origin.y += adjustedViewHeight
    }

    private func showAlert(withError errorDescription: String) {
        let alert = UIAlertController(title: "Save Failed", message: errorDescription, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - EventSetupViewDelegate

extension EventSetupViewController: EventSetupViewDelegate {
    
    func didBeginEditingFor(inputType: EventSetupInputType, currentText: String?, _ completion: (String?, UIColor) -> Void) {
        let input = viewModel.inputValuesFor(inputType, currentText: currentText, isEditing: true)
        completion(input.text, input.textColor)
    }
    
    func didEndEditingFor(inputType: EventSetupInputType, currentText: String?, _ completion: (String?, UIColor) -> Void) {
        let input = viewModel.inputValuesFor(inputType, currentText: currentText, isEditing: false)
        completion(input.text, input.textColor)
    }
    
    func textDidChange(inputType: EventSetupInputType, currentText: String?) {
        guard let currentText = currentText, !currentText.isEmpty else { return }
        viewModel.setValueFor(inputType: inputType, currentText: currentText)
    }
    
    func firstNameDidChange(text: String?) {
        title = text.isEmptyOrNil ? Constant.title : text
    }
    
    func eventTypeSelected(eventType: EventType, isSelected: Bool) {
        if isSelected {
            viewModel.eventType = eventType
        } else {
            viewModel.eventType = nil
        }
    }
    
    func datePickerValueChangedTo(date: Date) {
        viewModel.eventDate = date
    }
}