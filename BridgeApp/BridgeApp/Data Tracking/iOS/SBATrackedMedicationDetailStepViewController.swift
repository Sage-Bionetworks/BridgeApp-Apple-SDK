//
//  SBATrackedMedicationDetailStepViewController.swift
//  BridgeApp (iOS)
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
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

open class SBATrackedMedicationDetailStepViewController: RSDTableStepViewController, RSDTaskViewControllerDelegate, SBATrackedMedicationNavigationHeaderViewDelegate {
    
    var selectedIndexPath: IndexPath?
    
    override open var isForwardEnabled: Bool {
        if let source = tableData as? SBATrackedMedicationDetailsDataSource {
            return source.allAnswersValid()
        }
        return true
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor.darkPrimaryTintColor
        self.createCustomNavigationHeader()
    }
    
    func createCustomNavigationHeader() {
        let header =  SBATrackedMedicationNavigationHeaderView()
        header.delegate = self
        header.backgroundColor = UIColor.appBackgroundDark
        header.usesLightStyle = true
        header.underlinedButtonText = Localization.localizedString("MEDICATION_REMOVE_MEDICATION")
        self.navigationHeader = header
        self.tableView.tableHeaderView = header
    }
    
    override open func setupNavigationView(_ navigationView: RSDStepNavigationView, placement: RSDColorPlacement) {
        super.setupNavigationView(navigationView, placement: placement)
        if let backImage = UIImage(named: "BackButtonIcon") {
            navigationView.cancelButton?.setImage(backImage, for: .normal)
        }
    }
    
    override open func registerReuseIdentifierIfNeeded(_ reuseIdentifier: String) {
        guard !_registeredIdentifiers.contains(reuseIdentifier) else { return }
        _registeredIdentifiers.insert(reuseIdentifier)
        
        if reuseIdentifier == SBATrackedMedicationDetailsDataSource.FieldIdentifiers.addSchedule.stringValue {
            tableView.register(SBARoundedButtonCell.nib, forCellReuseIdentifier: reuseIdentifier)
            return
        }
        
        let reuseId = RSDFormUIHint(rawValue: reuseIdentifier)
        switch reuseId {
        case .textfield:
            tableView.register(SBATrackedTextfieldCell.nib, forCellReuseIdentifier: reuseIdentifier)
            break
        default:
            if reuseIdentifier == SBATrackedWeeklyScheduleCell.reuseId {
                tableView.register(SBATrackedWeeklyScheduleCell.nib, forCellReuseIdentifier: reuseIdentifier)
            } else {
                super.registerReuseIdentifierIfNeeded(reuseIdentifier)
            }
            break
        }
    }
    private var _registeredIdentifiers = Set<String>()
    
    override open func configure(cell: UITableViewCell, in tableView: UITableView, at indexPath: IndexPath) {
        super.configure(cell: cell, in: tableView, at: indexPath)
        
        guard let source = tableData as? SBATrackedMedicationDetailsDataSource,
            let tableItem = source.tableItem(at: indexPath) else {
            return
        }
        
        if let weeklySchedule = cell as? SBATrackedWeeklyScheduleCell {
            weeklySchedule.delegate = self
            weeklySchedule.inlineTimePicker.isOpen = (indexPath == _activeIndexPath)
            weeklySchedule.tableItem = tableItem
            let isLastScheduleItem = (indexPath.row == (source.schedulesSection.tableItems.count - 1))
            weeklySchedule.atAnytimeHidden = !isLastScheduleItem
        }
        if let dosageCell = cell as? SBATrackedTextfieldCell,
            let textTableItem = tableItem as? RSDTextInputTableItem {
            dosageCell.textField.delegate = self
            dosageCell.textField.text = textTableItem.answerText
        }
        if let buttonCell = cell as? SBARoundedButtonCell {
            if let _ = buttonCell.actionButton as? RSDRoundedButton {
                buttonCell.actionButton.setTitle(Localization.localizedString("ADD_ANOTHER_SCHEDULE_BUTTON"), for: .normal)
            }
            buttonCell.delegate = self
        }
    }
    
    override open func didTapButton(on cell: RSDButtonCell) {
        if let _ = cell.actionButton as? RSDUnderlinedButton {
            removeMedicationTapped()
            return
        }
        if let _ = cell.actionButton as? RSDRoundedButton {
           addAnotherScheduleTapped()
            return
        }
        super.didTapButton(on: cell)
    }
    
    @objc func removeMedicationTapped() {
        let removeStep = SBARemoveMedicationStepObject(identifier: step.identifier)
        removeStep.actions = [.navigation(.goForward): RSDUIActionObject(buttonTitle: Localization.localizedString("MEDICATION_REMOVE_BUTTON_TEXT"))]
        var navigator = RSDConditionalStepNavigatorObject(with: [removeStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: step.identifier, stepNavigator: navigator)
        let taskVc = RSDTaskViewController(task: task)
        taskVc.delegate = self
        self.present(taskVc, animated: true, completion: nil)
    }
    
    func addAnotherScheduleTapped() {
        guard let source = tableData as? SBATrackedMedicationDetailsDataSource else { return }
        if let indexPathOfNewCell = source.addScheduleItem() {
            self.tableView.beginUpdates()
            self.tableView.insertRows(at: [indexPathOfNewCell], with: .left)
            // The previous row item will hide the check box now, so we also must reload it
            self.tableView.reloadRows(at: [IndexPath(item: indexPathOfNewCell.item - 1, section: indexPathOfNewCell.section)], with: .none)
            self.tableView.endUpdates()
        } else {
            self.tableView.reloadData()
        }
    }
    
    override open func textFieldDidEndEditing(_ textField: UITextField) {
        // TODO: mdephillips 6/25/18 figure out why this isnt being done automatically
        if let source = tableData as? SBATrackedMedicationDetailsDataSource {
            try? source.dosageTableItem?.setAnswer(textField.text)
        }
        self.answersDidChange(in: SBATrackedMedicationDetailsDataSource.FieldIdentifiers.dosage.sectionIndex())
        super.textFieldDidEndEditing(textField)
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {
        
        // the user selected the "remove notification" instead of an indexPath schedule cell
        if self.selectedIndexPath == nil {
            if reason == .completed {
                if let source = tableData as? SBATrackedMedicationDetailsDataSource {
                    source.appendRemoveMedicationToTaskPath()
                }
                super.jumpForward()
            }
        } else {
            self.selectedIndexPath = nil
            if reason == .completed {
                weak var weakSelf = self
                dismiss(animated: true, completion: {
                    weakSelf?.tableView.reloadData()
                })
                return
            }
        }
        dismiss(animated: true, completion: nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        if let source = tableData as? SBATrackedMedicationDetailsDataSource,
            let indexPath = self.selectedIndexPath,
            let selectedTableItem = source.sections[indexPath.section].tableItems[indexPath.row] as? SBATrackedWeeklyScheduleTableItem {
            if taskPath.result.stepHistory.count > 0,
                let collectionResult = taskPath.result.stepHistory[0] as? RSDCollectionResultObject {
                var weekdaysSelected = [RSDWeekday]()
                for weekdayResult in collectionResult.inputResults {
                    if let weekdayAnswerResult = weekdayResult as? RSDAnswerResultObject,
                        let weekdayValueArray = weekdayAnswerResult.value as? [Int] {
                        for weekdayInt in weekdayValueArray {
                            if let weekday = RSDWeekday(rawValue: weekdayInt) {
                                weekdaysSelected.append(weekday)
                            }
                        }
                    }
                }
                selectedTableItem.weekdays = weekdaysSelected
            }
        }
    }
    
    override open func actionTapped(with actionType: RSDUIActionType) -> Bool {
        if actionType == .navigation(.goForward),
            let source = tableData as? SBATrackedMedicationDetailsDataSource {
            source.appendStepResultToTaskPathAndFinish(with: self)
        } else if actionType == .navigation(.cancel) {
            super.goBack()
            return true
        }
        return super.actionTapped(with: actionType)
    }
    
    public func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        return nil
    }
    
    private var _activeIndexPath: IndexPath?
    
    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        _endTimeEditingIfNeeded()
        super.tableView(tableView, didSelectRowAt: indexPath)
    }
    
    open func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        _endTimeEditingIfNeeded()
        return indexPath.section == 0 ? nil : indexPath
    }
    
    open override func goForward() {
        _endTimeEditingIfNeeded(false)
        super.goForward()
    }
    
    public func underlinedButtonTapped() {
        removeMedicationTapped()
    }
}

extension SBATrackedMedicationDetailStepViewController : SBATrackedWeeklyScheduleCellDelegate {
    public func didTapDay(for cell: SBATrackedWeeklyScheduleCell) {
        if !_endTimeEditingIfNeeded() {
            guard let scheduleItem = cell.tableItem as? SBATrackedWeeklyScheduleTableItem,
                let source = tableData as? SBATrackedMedicationDetailsDataSource
            else {
                assertionFailure("Cannot handle the button tap.")
                return
            }
            self.selectedIndexPath = cell.indexPath
            let step = source.step(for: scheduleItem)
            
            // Create the result to give the weekdays their pre-populated state
            var previousResult = RSDCollectionResultObject(identifier: step.identifier)
            var answerResult = RSDAnswerResultObject(identifier: step.identifier, answerType: RSDAnswerResultType(baseType: .string, sequenceType: .array, formDataType: .collection(.multipleChoice, .string), dateFormat: nil, unit: nil, sequenceSeparator: nil))
            answerResult.value = scheduleItem.weekdays?.map({ $0.rawValue })
            previousResult.inputResults = [answerResult]
            
            var navigator = RSDConditionalStepNavigatorObject(with: [step])
            navigator.progressMarkers = []
            let task = RSDTaskObject(identifier: step.identifier, stepNavigator: navigator)
            let path = RSDTaskPath(task: task)
            path.appendStepHistory(with: previousResult)
            let taskVc = RSDTaskViewController(task: task)
            taskVc.taskPath = path
            taskVc.delegate = self
            self.present(taskVc, animated: true, completion: nil)
        }
    }
    
    public func didChangeTiming(for cell: SBATrackedWeeklyScheduleCell, selected: Int) {
        _endTimeEditingIfNeeded()
    }
    
    public func didTapTime(for cell: SBATrackedWeeklyScheduleCell) {
        _endTimeEditingIfNeeded()
        _activeIndexPath = cell.indexPath
        self.tableView.reloadRows(at: [cell.indexPath], with: .none)
    }
    
    public func didChangeScheduleAtAnytimeSelection(for cell: SBATrackedWeeklyScheduleCell, selected: Bool) {
        if !_endTimeEditingIfNeeded() {
            cell.atAnytimeCheckbox.isSelected = selected
            if let source = tableData as? SBATrackedMedicationDetailsDataSource {
                let tableViewUpdates = source.scheduleAtAnytimeChanged(selected: selected)
                self.tableView.beginUpdates()
                if let lastSectionAdded = tableViewUpdates?.sectionAdded {
                    if lastSectionAdded {
                        self.tableView.insertSections(IndexSet.init(integer: SBATrackedMedicationDetailsDataSource.FieldIdentifiers.addSchedule.sectionIndex()), with: .left)
                    } else {
                        self.tableView.deleteSections(IndexSet.init(integer: SBATrackedMedicationDetailsDataSource.FieldIdentifiers.addSchedule.sectionIndex()), with: .right)
                    }
                }
                if let itemsRemoved = tableViewUpdates?.itemsRemoved {
                    self.tableView.deleteRows(at: itemsRemoved, with: .right)
                }
                self.tableView.reloadRows(at: [IndexPath(item: 0, section: SBATrackedMedicationDetailsDataSource.FieldIdentifiers.schedules.sectionIndex())], with: .none)
                self.tableView.endUpdates()
            }
        }
    }
    
    /// @return true if time editing was closed, false if nothing was done
    @discardableResult private func _endTimeEditingIfNeeded(_ shouldCollapse: Bool = true) -> Bool {
        guard let indexPath = _activeIndexPath,
            let cell = tableView.cellForRow(at: indexPath) as? SBATrackedWeeklyScheduleCell
            else {
                return false
        }
        _activeIndexPath = nil
        if shouldCollapse {
            self.tableView.reloadRows(at: [cell.indexPath], with: .none)
        }
        return true
    }
}

public protocol SBATrackedWeeklyScheduleCellDelegate : class, NSObjectProtocol {
    
    func didTapDay(for cell: SBATrackedWeeklyScheduleCell)
    
    func didTapTime(for cell: SBATrackedWeeklyScheduleCell)
    
    func didChangeScheduleAtAnytimeSelection(for cell: SBATrackedWeeklyScheduleCell, selected: Bool)
    
    func didChangeTiming(for cell: SBATrackedWeeklyScheduleCell, selected: Int)
}

open class SBATrackedTextfieldCell : RSDTableViewCell {
    
    /// The text field associated with this cell.
    @IBOutlet weak var textField: RSDStepTextField!
    /// The label used to display the prompt for the input field.
    @IBOutlet weak var fieldLabel: UILabel!
    /// A line show below the text field.
    @IBOutlet weak var ruleView: UIView!
    
    /// The nib to use with this cell. Default will instantiate a `SBATrackedMedicationDetailCell`.
    open class var nib: UINib {
        let bundle = Bundle(for: SBATrackedTextfieldCell.self)
        let nibName = String(describing: SBATrackedTextfieldCell.self)
        return UINib(nibName: nibName, bundle: bundle)
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.backgroundColor = UIColor.darkPrimaryTintColor
    }
}

open class TrackedTextField: RSDStepTextField {
    
    let padding = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24);
    
    override open func textRect(forBounds bounds: CGRect) -> CGRect {
        return UIEdgeInsetsInsetRect(bounds, padding)
    }
    
    override open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return UIEdgeInsetsInsetRect(bounds, padding)
    }
    
    override open func editingRect(forBounds bounds: CGRect) -> CGRect {
        return UIEdgeInsetsInsetRect(bounds, padding)
    }
}

open class SBARoundedButtonCell: RSDButtonCell {
    
    /// The nib to use with this cell. Default will instantiate a `SBARoundedButtonCell`.
    open class var nib: UINib {
        let bundle = Bundle(for: SBARoundedButtonCell.self)
        let nibName = String(describing: SBARoundedButtonCell.self)
        return UINib(nibName: nibName, bundle: bundle)
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.backgroundColor = UIColor.darkPrimaryTintColor
    }
}

/// Table view cell for selecting time of day and weekdays that the user should take their medication
open class SBATrackedWeeklyScheduleCell: RSDTableViewCell {
    
    public static let reuseId = "weeklySchedule"
    
    public weak var delegate: SBATrackedWeeklyScheduleCellDelegate?
    
    /// The nib to use with this cell. Default will instantiate a `SBATrackedMedicationDetailCell`.
    open class var nib: UINib {
        let bundle = Bundle(for: SBATrackedWeeklyScheduleCell.self)
        let nibName = String(describing: SBATrackedWeeklyScheduleCell.self)
        return UINib(nibName: nibName, bundle: bundle)
    }
    
    @IBOutlet open var titleLabel: UILabel!
    @IBOutlet open var timeButton: UIButton!
    @IBOutlet open var timePicker: UIDatePicker!
    @IBOutlet open var dayButtonContainer: UIView!
    @IBOutlet open var dayButton: UIButton!
    @IBOutlet open var atAnytimeContainer: UIView!
    @IBOutlet open var atAnytimeCheckbox: RSDCheckboxButton!
    
    @IBOutlet open var separatorLines: [UIView]!
    @IBOutlet open var labels: [UILabel]!
    @IBOutlet var inlineTimePicker: RSDToggleConstraintView!
    
    /// Override to set the content view background color to the color of the table background.
    override open var tableBackgroundColor: UIColor! {
        didSet {
            self.contentView.backgroundColor = tableBackgroundColor
        }
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.backgroundColor = UIColor.darkPrimaryTintColor
        self.titleLabel.textColor = UIColor.rsd_headerTitleLabel
        for label in self.labels {
            label.textColor = UIColor.rsd_headerTitleLabel
        }
        for line in self.separatorLines {
            line.backgroundColor = UIColor.rsd_cellSeparatorLine
        }
    }
    
    var atAnytimeHidden: Bool = false {
        didSet {
            atAnytimeContainer.isHidden = atAnytimeHidden
        }
    }
    
    override open var tableItem: RSDTableItem! {
        didSet {
            refreshUI()
        }
    }
    
    func refreshUI() {
        guard let scheduleItem = weeklyScheduleTableItem else { return }
        if scheduleItem.time == nil {
            dayButtonContainer.isHidden = true
            inlineTimePicker.isHidden = true
            self.atAnytimeCheckbox.isSelected = true
        } else {
            dayButtonContainer.isHidden = false
            inlineTimePicker.isHidden = false
            self.atAnytimeCheckbox.isSelected = false
            let timePickerDate = scheduleItem.time ?? Calendar.current.date(bySetting: .hour, value: 7, of: Date()) ?? Date()
            timeButton?.setTitle(DateFormatter.localizedString(from: timePickerDate, dateStyle: .none, timeStyle: .short), for: .normal)
            timePicker.date = timePickerDate
            self.weeklyScheduleTableItem?.time = timePickerDate
            if scheduleItem.weekdays?.count ?? 0 == RSDWeekday.all.count {                    dayButton.setTitle(Localization.localizedString("MEDICATION_SCHEDULE_EVERYDAY"), for: .normal)
            } else {
                if let weekdays = scheduleItem.weekdays {
                    dayButton.setTitle(RSDWeeklyScheduleFormatter().string(from: Set(weekdays)), for: .normal)
                }
            }
        }
    }
    
    var weeklyScheduleTableItem: SBATrackedWeeklyScheduleTableItem? {
        return tableItem as? SBATrackedWeeklyScheduleTableItem
    }
    
    @IBAction func timeTapped(_ sender: Any) {
        self.delegate?.didTapTime(for: self)
    }
    
    @IBAction func timeChanged(_ sender: Any) {
        self.weeklyScheduleTableItem?.time = timePicker.date
    }
    
    @IBAction func dayTapped(_ sender: Any) {
        self.delegate?.didTapDay(for: self)
    }
    
    @IBAction func atAnytimeTapped(_ sender: RSDCheckboxButton) {
        self.delegate?.didChangeScheduleAtAnytimeSelection(for: self, selected: !sender.isSelected)
    }
}

open class SBAInstructionImage: RSDEmbeddedIconVendor, RSDImageThemeElement, RSDFetchableImageThemeElement {
    
    public var imageIdentifier: String
    
    public var placementType: RSDImagePlacementType?
    
    public var size: CGSize
    
    public var bundle: Bundle?
    
    public var icon: RSDImageWrapper?
    
    public init (icon: RSDImageWrapper?) {
        self.imageIdentifier = icon?.imageIdentifier ?? ""
        self.icon = icon
        self.size = CGSize(width: 200.0, height: 200.0)
    }
    
    public func fetchImage(for size: CGSize, callback: @escaping ((String?, UIImage?) -> Void)) {
        let image = UIImage(named: self.imageIdentifier)
        callback(self.imageIdentifier, image)
    }
}

public protocol SBATrackedMedicationNavigationHeaderViewDelegate {
    func underlinedButtonTapped()
}

open class SBATrackedMedicationNavigationHeaderView: RSDTableStepHeaderView {
    
    private var _underlinedButtonContraints: [NSLayoutConstraint] = []
    
    var delegate: SBATrackedMedicationNavigationHeaderViewDelegate?
    var underlinedButtonText: String?
    /// The label for displaying step detail text.
    @IBOutlet open var underlinedButton: RSDUnderlinedButton?
    
    override open func updateVerticalConstraints(currentLastView: UIView?) -> (firstView: UIView?, lastView: UIView?) {
        addUnderlinedButtonIfNeeded()
        var results = super.updateVerticalConstraints(currentLastView: currentLastView)
        
        // Remove existing constraints for the underlined button
        NSLayoutConstraint.deactivate(_underlinedButtonContraints)
        _underlinedButtonContraints.removeAll()
        
        // Add the underlined button under the title label
        if let underlinedButtonUnwrapped = self.underlinedButton,
            let titleLabelUnwrapped = super.titleLabel {
            _underlinedButtonContraints.append(contentsOf:
                underlinedButtonUnwrapped.rsd_alignBelow(view: titleLabelUnwrapped, padding: constants.verticalSpacing))
        }
        
        results.lastView = underlinedButton
        return results
    }
    
    func addUnderlinedButtonIfNeeded() {
        guard underlinedButton == nil else { return }
        underlinedButton = addUnderlinedButton(font: UIFont.rsd_headerTextLabel, color: UIColor.rsd_headerTextLabel)
    }
    
    /// Convenience method for adding an underlined button.
    open func addUnderlinedButton(font: UIFont, color: UIColor) -> RSDUnderlinedButton {
        let button = RSDUnderlinedButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = font
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.preferredMaxLayoutWidth = constants.labelMaxLayoutWidth
        button.setTitle(underlinedButtonText, for: .normal)
        button.addTarget(self, action: #selector(self.underlineButtonTapped), for: .touchUpInside)
        self.addSubview(button)
        
        button.rsd_alignToSuperview([.leading, .trailing], padding: constants.sideMargin)
        button.rsd_makeHeight(.greaterThanOrEqual, 60.0)
        
        return button
    }
    
    @objc func underlineButtonTapped() {
        self.delegate?.underlinedButtonTapped()
    }
}
