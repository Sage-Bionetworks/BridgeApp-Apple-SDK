//
//  SBATrackedMedicationReviewStepViewController.swift
//  BridgeApp
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

import Foundation

open class SBATrackedMedicationReviewStepViewController: RSDTableStepViewController, RSDTaskViewControllerDelegate {
    
    open var reviewStep: SBATrackedItemsReviewStepObject? {
        return self.step as? SBATrackedItemsReviewStepObject
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // This will clear any selected review cells
        (self.step as? SBATrackedItemsReviewStepObject)?.nextStepIdentifier = nil
    }
    
    override open func registerReuseIdentifierIfNeeded(_ reuseIdentifier: String) {
        guard !_registeredIdentifiers.contains(reuseIdentifier) else { return }
        _registeredIdentifiers.insert(reuseIdentifier)

        if reuseIdentifier == SBATrackedMedicationReviewCell.reuseId {
            tableView.register(SBATrackedMedicationReviewCell.nib, forCellReuseIdentifier: reuseIdentifier)
        } else {
            super.registerReuseIdentifierIfNeeded(reuseIdentifier)
        }
    }
    private var _registeredIdentifiers = Set<String>()
    
    open override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let reviewDataSource = self.tableData as? SBATrackedMedicationReviewDataSource,
        let selectedIdentifier = reviewDataSource.tableItem(at: indexPath)?.identifier {
            reviewDataSource.reviewItemSelected(identifier: selectedIdentifier)
            self.goForward()
        }
    }
    
    override open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = UIColor.rsd_choiceCellBackgroundHighlighted
        cell.selectionStyle = .gray
        return cell
    }
    
    public func taskController(_ taskController: RSDTaskController, didFinishWith reason: RSDTaskFinishReason, error: Error?) {        
        guard let reviewDataSource = self.tableData as? SBATrackedMedicationReviewDataSource else {
            dismiss(animated: true, completion: nil)
            return
        }

        dismiss(animated: true, completion: nil)
    }
    
    public func taskController(_ taskController: RSDTaskController, readyToSave taskPath: RSDTaskPath) {
        // no-op
    }
    
    public func taskController(_ taskController: RSDTaskController, asyncActionControllerFor configuration: RSDAsyncActionConfiguration) -> RSDAsyncActionController? {
        // no-op
        return nil
    }
}

/// Table cell for displayiing medication information to review.
open class SBATrackedMedicationReviewCell: RSDTableViewCell {
    
    public static let reuseId = "medicationReview"
    
    /// The nib to use with this cell. Default will instantiate a `SBATrackedMedicationReviewCell`.
    open class var nib: UINib {
        let bundle = Bundle(for: SBATrackedMedicationReviewCell.self)
        let nibName = String(describing: SBATrackedMedicationReviewCell.self)
        return UINib(nibName: nibName, bundle: bundle)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var cheveronView: UIImageView!
    
    /// Action button that is associated with this cell.
    @IBOutlet open var actionButton: UIButton!
    
    var loggedButton: RSDRoundedButton? {
        return self.actionButton as? RSDRoundedButton
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()

        self.loggedButton?.isSecondaryButton = false
        self.loggedButton?.usesLightStyle = false

        self.actionButton.setTitle(Localization.localizedString("BUTTON_EDIT"), for: .normal)
    }
    
    override open var tableItem: RSDTableItem! {
        didSet {
            guard let medItem = tableItem as? SBATrackedMedicationReviewItem
                else {
                    return
            }
            
            if let dosageUnwrapped = medItem.medication.dosage {
                self.titleLabel.text = String(format: "%@ %@", medItem.medication.identifier, dosageUnwrapped)
                if let schedules = medItem.medication.scheduleItems {
                    if schedules.first?.timeOfDayString == nil {
                        self.detailLabel.text = Localization.localizedString("MEDICATION_ANYTIME")
                    } else {
                        let formatter = RSDWeeklyScheduleFormatter()
                        formatter.style = .medium
                        self.detailLabel.text = formatter.string(from: Array(schedules))
                    }
                }
                self.actionButton.isHidden = false
                self.cheveronView.isHidden = true
            } else {
                self.titleLabel.text = medItem.medication.identifier
                self.detailLabel.text = nil
                self.actionButton.isHidden = true
                self.cheveronView.isHidden = false
            }
        }
    }
}
