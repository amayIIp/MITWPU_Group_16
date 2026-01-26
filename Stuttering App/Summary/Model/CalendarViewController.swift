//
//  CalendarViewController.swift
//  Spasht
//
//  Created by Prathamesh Patil on 23/11/25.
//

import UIKit

protocol CalendarDateDelegate: AnyObject {
    func didSelectDate(_ date: Date)
}

class CalendarViewController: UIViewController, UICalendarSelectionSingleDateDelegate {
    
    @IBOutlet weak var calendarContainerView: UIView!
    
    weak var delegate: CalendarDateDelegate?
    var selectedDate: Date = Date()

    private var temporaryDateSelection: Date?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        temporaryDateSelection = selectedDate
        setupCustomHeader()
        setupCalendar()
    }
    
    private func setupCustomHeader() {
        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        
        navBar.backgroundColor = .bg
        view.addSubview(navBar)
        
        let navItem = UINavigationItem(title: "Select Date")
        let cancelBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancel))
        let doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
        
        navItem.leftBarButtonItem = cancelBarButton
        navItem.rightBarButtonItem = doneBarButton
        navBar.setItems([navItem], animated: false)
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    private func setupCalendar() {
        guard let container = calendarContainerView else { return }
        
        let cardView = UIView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 24
        cardView.clipsToBounds = true
        
        let calendarView = UICalendarView()
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.calendar = Calendar(identifier: .gregorian)
        calendarView.fontDesign = .rounded
        calendarView.backgroundColor = .clear

        container.addSubview(cardView)
        cardView.addSubview(calendarView)
        
        let outerMargin: CGFloat = 20.0
        let innerGap: CGFloat = 16.0

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: outerMargin),
            cardView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -outerMargin),
            cardView.topAnchor.constraint(equalTo: container.topAnchor, constant: outerMargin),
            cardView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -outerMargin),

            calendarView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: innerGap),
            calendarView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -innerGap),
            calendarView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: innerGap),
            calendarView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -innerGap)
        ])
        
        let selection = UICalendarSelectionSingleDate(delegate: self)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        selection.selectedDate = components
        calendarView.selectionBehavior = selection
    }
    
    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
    
    @objc private func didTapDone() {
        if let dateToReturn = temporaryDateSelection {
            delegate?.didSelectDate(dateToReturn)
        }
        dismiss(animated: true)
    }
    
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let dateComponents = dateComponents,
              let date = Calendar.current.date(from: dateComponents) else { return }
        
        temporaryDateSelection = date
    }
}
