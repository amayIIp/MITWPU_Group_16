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
    
    // MARK: - Outlets
    @IBOutlet weak var calendarContainerView: UIView!
    
    // MARK: - Properties
    weak var delegate: CalendarDateDelegate?
    var selectedDate: Date = Date()
        
    private var temporaryDateSelection: Date?
    private var calendarView: UICalendarView!
        
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
            
        temporaryDateSelection = selectedDate
        setupCalendar()
    }
        
    // MARK: - UI Setup
    private func setupCalendar() {
        guard let container = calendarContainerView else { return }
            
        // Initialize and style the calendar directly (No extra cardView needed)
        calendarView = UICalendarView()
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.calendar = Calendar(identifier: .gregorian)
        calendarView.fontDesign = .rounded
        calendarView.backgroundColor = .systemBackground
        calendarView.layer.cornerRadius = 24
        calendarView.clipsToBounds = true
            
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1))!
            
        calendarView.availableDateRange = DateInterval(start: startDate, end: today)
            
        container.addSubview(calendarView)
            
        // Pin 0 on all 4 sides. UICalendarView provides its own intrinsic content size,
        // meaning your container will now naturally wrap it without needing a fixed height constraint.
        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            calendarView.topAnchor.constraint(equalTo: container.topAnchor),
            calendarView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
            
        let selection = UICalendarSelectionSingleDate(delegate: self)
        let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        selection.selectedDate = components
            
        calendarView.selectionBehavior = selection
    }
        
    // MARK: - Actions
    @IBAction private func didTapCancel(_ sender: UIButton) {
        dismiss(animated: true)
    }
        
    @IBAction private func didTapDone(_ sender: UIButton) {
        if let dateToReturn = temporaryDateSelection {
            delegate?.didSelectDate(dateToReturn)
        }
        dismiss(animated: true)
    }
        
    // MARK: - UICalendarSelectionSingleDateDelegate
    func dateSelection(_ selection: UICalendarSelectionSingleDate,
                       didSelectDate dateComponents: DateComponents?) {
            
        guard let dateComponents = dateComponents,
              let date = Calendar.current.date(from: dateComponents) else { return }
            
        temporaryDateSelection = date
    }
}
