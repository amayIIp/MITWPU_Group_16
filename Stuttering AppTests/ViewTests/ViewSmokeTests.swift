import XCTest
import UIKit
@testable import Stuttering_App

@MainActor
final class ViewSmokeTests: XCTestCase {

    private var appBundle: Bundle {
        Bundle(for: AppDelegate.self)
    }

    func testStoryboardResourcesLoadForEveryFeature() {
        let storyboardNames = [
            "Main",
            "LaunchScreen",
            "Home",
            "Onboarding",
            "Awards",
            "Conversation",
            "Exercise",
            "Profile",
            "Reading",
            "Summary"
        ]

        for name in storyboardNames {
            XCTAssertNotNil(appBundle.url(forResource: name, withExtension: "storyboardc"), "\(name).storyboard should be present in the app bundle")
        }
    }

    func testNibBackedViewsLoadForEveryFeature() {
        XCTAssertTrue(loadNib("AwardCollectionViewCell", as: AwardCollectionViewCell.self) != nil)
        XCTAssertTrue(loadNib("AwardStandardCell", as: AwardStandardCell.self) != nil)
        XCTAssertTrue(loadNib("WeeklyChallengeCell", as: WeeklyChallengeCell.self) != nil)
        XCTAssertTrue(loadNib("ExerciseCollectionViewCell", as: ExerciseCollectionViewCell.self) != nil)
        XCTAssertTrue(loadNib("FunExerciseCollectionViewCell", as: FunExerciseCollectionViewCell.self) != nil)
        XCTAssertTrue(loadNib("TableViewCell", as: TableViewCell.self) != nil)
    }

    func testProgrammaticViewsInitializeAndUpdateState() {
        let progressBar = ProgressBarView(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        progressBar.progress = 1.4
        XCTAssertEqual(progressBar.progress, 1.0)
        progressBar.setProgress(-0.5, animated: false)
        XCTAssertEqual(progressBar.progress, 0.0)

        let radialView = RadialProgressView(frame: CGRect(x: 0, y: 0, width: 180, height: 180))
        radialView.chartData = [RadialData(title: "Daily Tasks", color: .systemBlue, progress: 0.2, radius: 60, lineWidth: 10, order: 0)]
        radialView.updateProgress(for: "Daily Tasks", to: 2.0)
        XCTAssertEqual(radialView.chartData.first?.progress, 1.0)
        radialView.updateProgress(for: "Daily Tasks", to: -1.0)
        XCTAssertEqual(radialView.chartData.first?.progress, 0.0)

        let onboardingWaveform = BarWaveformView(frame: CGRect(x: 0, y: 0, width: 160, height: 80))
        onboardingWaveform.amplitudes = [0.0, 0.4, 1.0, 1.7]
        onboardingWaveform.layoutIfNeeded()
        XCTAssertEqual(onboardingWaveform.layer.sublayers?.count, 1)

        let conversationWaveform = AudioWaveformView(frame: CGRect(x: 0, y: 0, width: 160, height: 80))
        conversationWaveform.update(with: 0.7)
        let stack = conversationWaveform.subviews.compactMap { $0 as? UIStackView }.first
        XCTAssertEqual(stack?.arrangedSubviews.count, 15)

        let feature = OnboardingFeature(iconName: "mic.fill", title: "Practice", description: "Guided session")
        let featureRow = FeatureRowView(feature: feature)
        XCTAssertFalse(featureRow.subviews.isEmpty)

        let overlay = ModuleOnboardingOverlayView(subtitle: "Start", features: [feature], footerText: "Progress is saved")
        var didContinue = false
        overlay.onContinue = { didContinue = true }
        overlay.firstButton(withTitle: "Continue")?.sendActions(for: .touchUpInside)
        XCTAssertTrue(didContinue)
    }

    func testTextAndSelectionViewsUpdateVisibleState() {
        let placeholderTextView = PlaceholderTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 120))
        placeholderTextView.placeholderText = "Enter text"
        let placeholderLabel = placeholderTextView.subviews.compactMap { $0 as? UILabel }.first
        XCTAssertEqual(placeholderLabel?.text, "Enter text")
        XCTAssertEqual(placeholderLabel?.isHidden, false)
        placeholderTextView.text = "Hello"
        XCTAssertEqual(placeholderLabel?.isHidden, true)

        let customCard = CustomCardCell(frame: CGRect(x: 0, y: 0, width: 320, height: 360))
        customCard.updateSelectionState(isSelected: true)
        XCTAssertNotNil(customCard.headerRadio.image)
        customCard.setExpanded(true, animated: false)
        XCTAssertFalse(customCard.collapsedHeightConstraint.isActive)

        let randomCard = RandomCardCell(frame: CGRect(x: 0, y: 0, width: 320, height: 360))
        randomCard.updateHeaderSelection(isSelected: true)
        randomCard.updateSubcategorySelection(selectedIndex: 2)
        XCTAssertEqual(randomCard.rowViews.count, 5)
        XCTAssertNotNil(randomCard.headerRadio.image)

        let subcategory = SubcategoryRowView(title: "Science", index: 0)
        subcategory.setRadioSelected(true)
        XCTAssertEqual(subcategory.titleLabel.text, "Science")
        XCTAssertNotNil(subcategory.radioImageView.image)
    }

    func testCellsConfigureWithModels() {
        let exercise = Exercise(id: "breathing", name: "Breathing", description: "Steady airflow", short_time: 90)
        let task = DailyTask(id: 1, name: "Daily Voice", description: "Warm up", duration: 45, isCompleted: true)
        let award = AwardModel(id: "FirstStep", name: "First Step", description: "Completed first task", status: "Done", progress: 1.0, completionDate: Date(timeIntervalSince1970: 0), groupType: "achieved")

        let exerciseCell = ExerciseCell()
        exerciseCell.nameLabel = retained(UILabel(), in: exerciseCell.contentView)
        exerciseCell.descriptionLabel = retained(UILabel(), in: exerciseCell.contentView)
        exerciseCell.timeLabel = retained(UILabel(), in: exerciseCell.contentView)
        exerciseCell.configure(with: exercise)
        XCTAssertEqual(exerciseCell.nameLabel.text, "Breathing")
        XCTAssertEqual(exerciseCell.timeLabel.text, "2m")

        let dailyTasksCell = DailyTasksCell()
        dailyTasksCell.nameLabel = retained(UILabel(), in: dailyTasksCell.contentView)
        dailyTasksCell.descriptionLabel = retained(UILabel(), in: dailyTasksCell.contentView)
        dailyTasksCell.timeLabel = retained(UILabel(), in: dailyTasksCell.contentView)
        dailyTasksCell.playButton = retained(UIButton(type: .system), in: dailyTasksCell.contentView)
        dailyTasksCell.configure(with: task)
        XCTAssertEqual(dailyTasksCell.nameLabel.text, "Daily Voice")
        XCTAssertEqual(dailyTasksCell.timeLabel.text, "45s")

        let tableViewCell = TableViewCell()
        tableViewCell.nameLabel = retained(UILabel(), in: tableViewCell.contentView)
        tableViewCell.descriptionLabel = retained(UILabel(), in: tableViewCell.contentView)
        tableViewCell.timeLabel = retained(UILabel(), in: tableViewCell.contentView)
        tableViewCell.playButton = retained(UIButton(type: .system), in: tableViewCell.contentView)
        tableViewCell.configureForWarmUp(with: exercise)
        XCTAssertEqual(tableViewCell.timeLabel.text, "2m")

        let funExerciseCell = FunExerciseCollectionViewCell()
        funExerciseCell.titleLabel = retained(UILabel(), in: funExerciseCell.contentView)
        funExerciseCell.descriptionLabel = retained(UILabel(), in: funExerciseCell.contentView)
        funExerciseCell.exerciseThumbnail = retained(UIImageView(), in: funExerciseCell.contentView)
        funExerciseCell.configure(with: exercise)
        XCTAssertEqual(funExerciseCell.titleLabel.text, "Breathing")

        let exerciseCollectionCell = ExerciseCollectionViewCell()
        exerciseCollectionCell.titleLabel = retained(UILabel(), in: exerciseCollectionCell.contentView)
        exerciseCollectionCell.captionLabel = retained(UILabel(), in: exerciseCollectionCell.contentView)
        exerciseCollectionCell.timeLabel = retained(UILabel(), in: exerciseCollectionCell.contentView)
        exerciseCollectionCell.actionButton = retained(UIButton(type: .system), in: exerciseCollectionCell.contentView)
        exerciseCollectionCell.configure(with: exercise)
        XCTAssertEqual(exerciseCollectionCell.timeLabel.text, "2m")

        let awardCell = AwardCollectionViewCell()
        awardCell.nameLabel = retained(UILabel(), in: awardCell.contentView)
        awardCell.dateLabel = retained(UILabel(), in: awardCell.contentView)
        awardCell.awardImageView = retained(UIImageView(), in: awardCell.contentView)
        awardCell.progressBar = retained(UIProgressView(), in: awardCell.contentView)
        awardCell.configure(with: award)
        XCTAssertEqual(awardCell.nameLabel.text, "First Step")
        XCTAssertTrue(awardCell.progressBar.isHidden)

        let achievedCell = AwardStandardCell()
        achievedCell.cardTitleLabel = retained(UILabel(), in: achievedCell.contentView)
        achievedCell.awardImage = retained(UIImageView(), in: achievedCell.contentView)
        achievedCell.awardName = retained(UILabel(), in: achievedCell.contentView)
        achievedCell.awardDescription = retained(UILabel(), in: achievedCell.contentView)
        achievedCell.showAllButton = retained(UIButton(type: .system), in: achievedCell.contentView)
        achievedCell.configureAsAchieved(with: award)
        XCTAssertEqual(achievedCell.cardTitleLabel.text, "Achieved")

        let weeklyCell = WeeklyChallengeCell()
        weeklyCell.cardTitleLabel = retained(UILabel(), in: weeklyCell.contentView)
        weeklyCell.weeklyChallengeImage = retained(UIImageView(), in: weeklyCell.contentView)
        weeklyCell.weeklyChallengeName = retained(UILabel(), in: weeklyCell.contentView)
        weeklyCell.weeklyChallengeDescription = retained(UILabel(), in: weeklyCell.contentView)
        weeklyCell.showAllButton = retained(UIButton(type: .system), in: weeklyCell.contentView)
        weeklyCell.configure(with: award)
        XCTAssertEqual(weeklyCell.cardTitleLabel.text, "Weekly Challenges")

        let customWorkspaceCell = CustomWorkspaceCell()
        customWorkspaceCell.inputTextView = retained(UITextView(), in: customWorkspaceCell.contentView)
        XCTAssertNotNil(customWorkspaceCell.inputTextView)

        let logCell = LogSummaryCell()
        logCell.exerciseNameLabel = retained(UILabel(), in: logCell.contentView)
        logCell.durationLabel = retained(UILabel(), in: logCell.contentView)
        XCTAssertNotNil(logCell.exerciseNameLabel)
    }

    private func loadNib<T>(_ nibName: String, as type: T.Type) -> T? {
        UINib(nibName: nibName, bundle: appBundle)
            .instantiate(withOwner: nil)
            .compactMap { $0 as? T }
            .first
    }

    private func retained<T: UIView>(_ view: T, in container: UIView) -> T {
        container.addSubview(view)
        return view
    }
}

private extension UIView {
    func firstButton(withTitle title: String) -> UIButton? {
        if let button = self as? UIButton, button.title(for: .normal) == title {
            return button
        }

        for subview in subviews {
            if let button = subview.firstButton(withTitle: title) {
                return button
            }
        }

        return nil
    }
}
