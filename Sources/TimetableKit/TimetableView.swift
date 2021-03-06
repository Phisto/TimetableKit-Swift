//
//  File.swift
//
//  Created by Simon Gaus on 20.05.20.
//

import UIKit

#warning("Remove and make delegate default")
/// The style of the timetable view.
public enum TimetableStyle {
    /// A dark timetable view style.
    case dark
    /// A light timetable view style.
    case light
    /// Style is based on system settings.
    case system
    /// The timetable view style is determined by the brightness of the screen.
    case automatic
    /// The timetable view style is determined the appearance delegate of the timetable.
    case custom
}

/// The brightness value of the screen under which the screen is considered "dark".
let kBrightnessTreshold: CGFloat = 0.35

/**
 
 An object that manages an ordered collection of event items and presents them in the planned order.
 
 ## Overview
 
 When adding a timetable view to your user interface, your app’s main job is to manage the event data associated with that timetable view. The timetable view gets its data from the data source object, which is an object that conforms to the 'SGTimetableViewDataSource' protocol and is provided by your app. Data in the timetable view is organized into individual event items, which can then be grouped into locations and sections for presentation. An event item is the elementary data for the timetable view.
 
 A timetable view is made up of zero or more sections, each with its own locations. Sections are identified by their index number within the timetable view, and locations are identified by their index number within a section. Each row has one ore more tiles. Tiles are  identified by their index number within the location.
 
 ## Data Structure
 
 The structure of the timetable includes following components:
 
 * Event          Events are the elementary data for the timetable. An event is basically an entity which is defined by it's occurence in time specified by a time interval and a name attribute and a location where it occures.
 * Location     A group of events associated with the same location where they occure.
 * Section       A number of locations which are grouped together by theme or motto. This can be anything, for a festival there could be one section for the stages and one for the food shops.
 
 ## Limitations
 
 * The timetable view is not able to display overlapping or simultan occuring events at the same location, you have to split these locations into sub-locations if this happens in your scenario.
 * The timetable view is meant for displaying events that have a duration of hours not days. If you need to display lengthy events please consider to use a calendar view.
 
 */
public class TimetableView: TimetableBaseView {

    public weak var dataSource: TimetableDataSource?
    public weak var appearanceDelegate: TimetableAppearanceDelegate?
    public weak var delegate: TimetableDelegate?
    public weak var clock: TimetableClock?
    
    private(set) var style: TimetableStyle = .automatic
    private var automaticStyle: TimetableStyle = .automatic
    private var proxyAppearanceDelegate: TimetableAppearanceDelegate! {
        didSet {
            tableView.backgroundColor = proxyAppearanceDelegate.timetabelBackgroundColor()
            timescale.backgroundColor = proxyAppearanceDelegate.timetabelBackgroundColor()
            horizontalControl.backgroundColor = proxyAppearanceDelegate.timetabelBackgroundColor()
        }
    }
    
    private var clockProxy: TimetableClock = TimetableClockProxy()
    private var scrollingCoordinator: ScrollingCoordinator!
    private var scaleCoordinator: ScaleCoordinator!
    
    private var reloadCoverView: UIImageView!

    public init(_ frame: CGRect, with style: TimetableStyle) {
        
        super.init(frame: frame)
        self.style = style
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        //self.tableView.prefetchDataSource = self
        
        self.scrollingCoordinator = ScrollingCoordinator.init(with: self)
        self.navigationScrollView.delegate = self.scrollingCoordinator
        
        self.automaticStyle = (UIScreen.main.brightness > kBrightnessTreshold) ? .light : .dark
        
        self.proxyAppearanceDelegate = AppearanceDelegateProxy.init(with: self)
        
        self.scaleCoordinator = ScaleCoordinator.init(with: self, and: self.scrollingCoordinator)
        self.scrollingCoordinator.scaleCoordinator = self.scaleCoordinator

        NotificationCenter.default.addObserver(self, selector: #selector(TimetableView.eventTileWasTapped(with:)), name: .eventTileWasTapped, object: nil)
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        automaticStyle = (UIScreen.main.brightness > kBrightnessTreshold) ? .light : .dark
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let dataSource = dataSource else { return }

        let timetableInterval = scaleCoordinator.intervalOfTimetable
        let height = tableView.contentSize.height
        let widht = timetableInterval.duration.minutes.floaty * scaleCoordinator.pointsPerMinute
        
        navigationScrollView.contentSize = CGSize(width: widht, height: height)
        currentTimeScrollView.contentSize = CGSize(width: widht, height: height)
        
        tableView.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: dataSource.bottomPadding(for: self), right: 0)
        navigationScrollView.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: dataSource.bottomPadding(for: self), right: 0)
        currentTimeScrollView.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: dataSource.bottomPadding(for: self), right: 0)
        
        let offset = (clockProxy.currentDate(self).timeIntervalSince1970 - timetableInterval.start.timeIntervalSince1970)
        if offset > 0 {
            if offset <= timetableInterval.duration {
                let currentTimeOffset = scaleCoordinator.pointsPerMinute * offset.minutes.floaty
                timeIndicator.frame = CGRect(x: currentTimeOffset, y: 0, width: 1, height: currentTimeScrollView.frame.height)
                timeIndicator.isHidden = false
            }
            else {
                timeIndicator.isHidden = true
            }
        }
        else {
            timeIndicator.isHidden = true
        }
    }
    
    public func scrollToCurrentDate() {
            
        guard let dataSource = dataSource else { return }
        
        let timetableInterval = dataSource.interval(for: self)
        let pointsPerMinute = scaleCoordinator.pointsPerMinute
        let halfTimetabelWidth = frame.size.width/2.0
        let currentDate = clockProxy.currentDate(self)
        
        // scroll to current date if possible
        let nowIsInsideTimtable = timetableInterval.contains(currentDate)
        if nowIsInsideTimtable {
            let numberOfDays = dataSource.numberOfDays(in: self)
            for index in 0 ..< numberOfDays {
                let intervalForSelectedDay = dataSource.timetableView(self, intervalForDayAt: index)
                let nowIsInsideSelectedDay = intervalForSelectedDay.contains(currentDate)
                if nowIsInsideSelectedDay {
                    var currentTimeOffset = DateInterval.safely(start: timetableInterval.start, end: currentDate).duration.minutes.floaty*pointsPerMinute
                    currentTimeOffset = currentTimeOffset - halfTimetabelWidth
                    if currentTimeOffset < 0 { currentTimeOffset = 0 }
                    scrollingCoordinator.set(CGPoint(x: currentTimeOffset.round(nearest: 0.5), y: tableView.contentOffset.y), animated: false)
                    return
                }
            }
        }
    }
    
    /// Reloads the rows, tiles and sections of the timetable view.
    ///
    /// Call this method to reload all the data that is used to construct the timetable, including cells, section headers, index arrays, tiles and so on.
    public func reloadData() {
        
        reloadData(animated: false)
    }
    
    public func reloadData(animated: Bool = false) {
        
        guard let dataSource = dataSource else { return }
        
        var muteTitleArray = [String]()
        for index in 0..<dataSource.numberOfDays(in: self) {
            muteTitleArray.append(dataSource.timetableView(self, titleForDayAt: index))
        }
        
        horizontalControl.configure(with: muteTitleArray)
        horizontalControl.backgroundColor = proxyAppearanceDelegate.timetabelBackgroundColor()
        horizontalControl.textColor = proxyAppearanceDelegate.timetabelBackgroundColor().contrastingColor()
        horizontalControl.highlightTextColor = proxyAppearanceDelegate.timetabelEventTileHighlightColor()
        horizontalControl.font = UIFont.systemFont(ofSize: 16.0, weight: .light)
        let days = dataSource.numberOfDays(in: self)
        horizontalControl.numberOfSegmentsToDisplay = (days > 3 ) ? 3 : days
        horizontalControl.delegate = self
        
        rowController = [TimetableRowController]()
        rowControllerByIndexPath = [IndexPath : TimetableRowController]()
        unusedRowController = Set.init()
        
        if animated {
            
            reloadCoverView = UIImageView(frame: bounds)
            reloadCoverView.image = self.capture()
            addSubview(reloadCoverView)
            
            tableView.backgroundColor = proxyAppearanceDelegate.timetabelSectionHeaderColor()
            
            timescale.interval = dataSource.interval(for: self)
            timescale.timescaleColor = proxyAppearanceDelegate.timetabelBackgroundColor()
            timescale.timescaleStrokeColor = proxyAppearanceDelegate.timetabelBackgroundColor().contrastingColor()
            timescale.reloadData()
            
            tableView.reloadData {
                self.scrollingCoordinator.set(self.navigationScrollView.contentOffset, animated: false)
                UIView.animate(withDuration: 0.5) {
                    self.reloadCoverView.alpha = 0.0
                } completion: { success in
                    self.reloadCoverView.removeFromSuperview()
                    self.reloadCoverView = nil
                }
            }
        }
        else {
            
            tableView.backgroundColor = proxyAppearanceDelegate.timetabelSectionHeaderColor()
            
            timescale.interval = dataSource.interval(for: self)
            timescale.timescaleColor = proxyAppearanceDelegate.timetabelBackgroundColor()
            timescale.timescaleStrokeColor = proxyAppearanceDelegate.timetabelBackgroundColor().contrastingColor()
            timescale.reloadData()
            
            tableView.reloadData {
                self.scrollingCoordinator.set(self.navigationScrollView.contentOffset, animated: false)
            }
        }
        
        self.setNeedsLayout()
    }
    
    /// Transitions to the specified timetable view style.
    /// - Parameters:
    ///   - style: The new timtable view stlye.
    ///   - animated: If `true`, the style is changed using an animation. Defaults to `true`.
    public func transition(to style: TimetableStyle, animated: Bool = true) {
        
        self.style = style
        reloadData(animated: animated)
    }
    
    func recycledOrNewRowController() -> TimetableRowController {
        if unusedRowController.count > 1 {
            let reusedController = unusedRowController.randomElement()!
            unusedRowController.remove(reusedController)
            return reusedController
        }
        
        let layout = UICollectionViewFlowLayout.init()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0.0
        layout.minimumLineSpacing = 0.0
        
        let contentViewController = TimetableRowController.init(collectionViewLayout: layout)
        contentViewController.layoutDelegate = scaleCoordinator
        contentViewController.appearanceDelegate = proxyAppearanceDelegate
        rowController.append(contentViewController)
        return contentViewController
    }
}

// MARK: Selection Handling

extension TimetableView {
    
    @objc func eventTileWasTapped(with notification: NSNotification) {

        guard let delegate = delegate else { return }
        guard let event = (notification.object as? EventTile)?.event else { return }
        delegate.timetableView(self, didSelectEventWith: event.uniqueIdentifier)
    }
}

// MARK: Horizontal Control Delegate

extension TimetableView: HorizontalControlDelegate {
    
    public func selectedSegment(at index: Int) {
        
        guard let dataSource = dataSource else { return }
        
        let timetableInterval = dataSource.interval(for: self)
        let intervalForSelectedDay = dataSource.timetableView(self, intervalForDayAt: index)
        let pointsPerMinute = scaleCoordinator.pointsPerMinute
        let currentOffset = navigationScrollView.contentOffset.x
        let halfTimetabelWidth = frame.size.width/2.0
        let currentDate = clockProxy.currentDate(self)
        
        // scroll to current date if possible
        let nowIsInsideTimtable = timetableInterval.contains(currentDate)
        if nowIsInsideTimtable {
            let nowIsInsideSelectedDay = intervalForSelectedDay.contains(currentDate)
            if nowIsInsideSelectedDay {
                var currentTimeOffset = DateInterval.safely(start: timetableInterval.start, end: currentDate).duration.minutes.floaty*pointsPerMinute
                currentTimeOffset = currentTimeOffset - halfTimetabelWidth
                if currentTimeOffset < 0 { currentTimeOffset = 0 }
                scrollingCoordinator.set(CGPoint(x: currentTimeOffset.round(nearest: 0.5), y: tableView.contentOffset.y), animated: true)
                return
            }
        }
        
        // get offsets of the selected day
        var dayStartOffset = DateInterval.safely(start: timetableInterval.start, end: intervalForSelectedDay.start).duration.minutes.floaty*pointsPerMinute
        var dayEndOffset = DateInterval.safely(start: timetableInterval.start, end: intervalForSelectedDay.end).duration.minutes.floaty*pointsPerMinute
        
        // if we set the dayOffset now the timetable would scroll so that the offset is at the screen edge.
        // but we want the offset to be in the middle of the screen.
        dayStartOffset = dayStartOffset - halfTimetabelWidth
        dayEndOffset = dayEndOffset - halfTimetabelWidth

        let rightFromDayStart = currentOffset >= dayStartOffset
        let leftFromDayEnd = currentOffset <= dayEndOffset+halfTimetabelWidth
        let isInsideSelectedDay = rightFromDayStart && leftFromDayEnd
        
        if (!isInsideSelectedDay) {
        
            // scroll to left bound of the day or to the end
            var offsetToScrollTo = (currentOffset <= dayStartOffset) ? dayStartOffset : dayEndOffset
            if offsetToScrollTo < 0 { offsetToScrollTo = 0 }
            scrollingCoordinator.set(CGPoint(x: offsetToScrollTo.round(nearest: 0.5), y: tableView.contentOffset.y), animated: true)
        }
    }
}

extension CGFloat {
    
    func round(nearest: CGFloat) -> CGFloat {
            let n = 1/nearest
            let numberToRound = self * n
            return numberToRound.rounded() / n
    }
}

// MARK: Tableview Delegate

let kTimetableSectionHeaderHeight: CGFloat = 40

extension TimetableView: UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching {
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let dataSource = dataSource else { return UITableViewCell() }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: TimetableRow.cellIdentifier, for: indexPath) as! TimetableRow

        let rowController = recycledOrNewRowController()
        rowController.events = dataSource.timetableView(self, eventsForRowAt: indexPath)
        rowControllerByIndexPath[indexPath] = rowController
        
        cell.backgroundColor = proxyAppearanceDelegate.timetabelBackgroundColor()
        cell.contentView.backgroundColor = proxyAppearanceDelegate.timetabelRowHeaderColor()
        cell.titleLabel.textColor = proxyAppearanceDelegate.timetabelRowHeaderColor().contrastingColor()
        cell.hostedView = rowController.view
        cell.titleLabel.text = dataSource.timetableView(self, titleForRowAt: indexPath)
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let dataSource = dataSource else { return 0 }
        return dataSource.timetableView(self, numberOfRowsIn: section)
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        guard let dataSource = dataSource else { return 0 }
        return dataSource.numberOfSections(in: self)
    }
    
    public func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let rowController = rowControllerByIndexPath[indexPath]
        if rowController != nil {
            rowController!.view = nil
            rowControllerByIndexPath.removeValue(forKey: indexPath)
            unusedRowController.insert(rowController!)
        }
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return kDefaultTableViewCellHeigth
    }
    
    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return tableView.numberOfSections == 1 ? 0.0 : kTimetableSectionHeaderHeight
    }
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        guard let dataSource = dataSource else { return nil }
        
        let label = UILabel.init()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20.0, weight: .semibold)
        label.text = dataSource.timetableView(self, titleForHeaderOf: section)
        label.backgroundColor = proxyAppearanceDelegate.timetabelSectionHeaderColor()
        label.textColor = proxyAppearanceDelegate.timetabelBackgroundColor().contrastingColor()//.withAlphaComponent(0.5)
        return label
    }
    
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
        guard let dataSource = dataSource else { return }
        
        for indexPath in indexPaths {
            let rowController = recycledOrNewRowController()
            rowController.events = dataSource.timetableView(self, eventsForRowAt: indexPath)
            rowControllerByIndexPath[indexPath] = rowController
        }
    }
}

// MARK: Base View

extension Notification.Name {

    static let tapWasRegistered = Notification.Name("SGTapWasRegisteredNotification")
}

public class TimetableBaseView: UIView {
    
    var horizontalControl: HorizontalControl!
    var timescale: TimescaleView!
    var tableView: SGTableView!
    var currentTimeScrollView: UIScrollView!
    var timeIndicator: UIView!
    var leadingTimeIndicatorConstraint: NSLayoutConstraint!
    var navigationScrollView: UIScrollView!
    
    var tapGestureRecognizer: UITapGestureRecognizer!
    
    var rowController = [TimetableRowController]()
    var unusedRowController: Set<TimetableRowController> = Set.init()
    lazy var rowControllerByIndexPath: [IndexPath: TimetableRowController] = { return [IndexPath: TimetableRowController]() }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        TimeFormatter.prepare()
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        TimeFormatter.prepare()
        setupView()
    }
     
    private func setupView() {
        
        tableView = SGTableView.init(frame: .infinite, style: .grouped)
        tableView.register(TimetableRow.self, forCellReuseIdentifier: TimetableRow.cellIdentifier)
        tableView.allowsSelection = false
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.sectionFooterHeight = 0.0
        tableView.backgroundView = nil
        tableView.insetsContentViewsToSafeArea = false
        tableView.automaticallyAdjustsScrollIndicatorInsets = false
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0.1))
        self.addSubview(tableView)
        tableView.fit(to: self, leading: 0.0, trailing: 0.0, top: 88.0, bottom: 0.0)
        
        horizontalControl = HorizontalControl.init(frame: .zero)
        horizontalControl.font = UIFont.systemFont(ofSize: 17.0, weight: .light)
        self.addSubview(horizontalControl)
        horizontalControl.stickToTop(of: self, height: 44.0, sideMargin: 8.0)
        
        timescale = TimescaleView.init(frame: .zero)
        self.addSubview(timescale)
        timescale.stickToTop(of: self, height: 44.0, topMargin: 44.0)
        
        currentTimeScrollView = UIScrollView.init(frame: .infinite)
        currentTimeScrollView.backgroundColor = .clear
        currentTimeScrollView.showsVerticalScrollIndicator = false
        currentTimeScrollView.showsHorizontalScrollIndicator = false
        currentTimeScrollView.automaticallyAdjustsScrollIndicatorInsets = false
        currentTimeScrollView.isOpaque = false
        currentTimeScrollView.isUserInteractionEnabled = false
        currentTimeScrollView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(currentTimeScrollView)
        currentTimeScrollView.fit(to: self, leading: 0, trailing: 0, top: 44.0, bottom: 0)
    
        
        timeIndicator = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 500))
        timeIndicator.backgroundColor = UIColor.red.withAlphaComponent(0.5)
        timeIndicator.isHidden = false
        currentTimeScrollView.addSubview(timeIndicator)
        //leadingTimeIndicatorConstraint = timeIndicator.stickToLeft(of: currentTimeContentView, leftMargin: 50.0, width: 1)
        //timeIndicator.stickToTop(of: currentTimeScrollView, height: 100, topMargin: 40)
        
        navigationScrollView = UIScrollView.init(frame: .infinite)
        navigationScrollView.backgroundColor = .clear
        navigationScrollView.showsVerticalScrollIndicator = false
        navigationScrollView.showsHorizontalScrollIndicator = false
        navigationScrollView.automaticallyAdjustsScrollIndicatorInsets = false
        navigationScrollView.isOpaque = false
        navigationScrollView.decelerationRate = .fast
        navigationScrollView.panGestureRecognizer.maximumNumberOfTouches = 1
        self.addSubview(navigationScrollView)
        navigationScrollView.fit(to: self, leading: 0, trailing: 0, top: 88.0, bottom: 0)
        
        tapGestureRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(TimetableBaseView.tapped(recognizer:)))
        self.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func tapped(recognizer: UIPinchGestureRecognizer) {
        
        // views (or their controllers) that could be tapped should register
        // as observers for the 'Notification.tapWasRegistered' notification and
        // test if the touch event happend inside their bounds.
        //
        // let recognizer = notification.object as! UIPinchGestureRecognizer
        // let touchPoint = recognizer.location(in: self.myTappableView)
        // let wasTapped = self.myTappableView.bounds.contains(touchPoint)
        //
        NotificationCenter.default.post(name: .tapWasRegistered, object: recognizer)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // hide seperators
        // doing it in setUpSubviews won't suffice...
        tableView.separatorStyle = .none
    }
}

/**
 The `SGTableView` class adds the ability to synchronously reload the tabel view to the 'UITableView' class.
 
 There was the problem that when i tried to set the content offset of some collection views inside the table view cells directly after a call to -reloadData: the frame wont update and the collection views had still an offset of 0.
 
 - seealso: https://stackoverflow.com/questions/16071503/how-to-tell-when-uitableview-has-completed-reloaddata
 */
class SGTableView: UITableView {
    
    /// The completion block to execute after reload.
    private var completionBlock: ( () -> Void )?
    
    /// Reloads the rows and sections of the table view and executes the completionBlock when finished.
    ///
    /// Call this method to reload all the data that is used to construct the table, including cells, section headers and footers, index arrays, and so on.
    /// For efficiency, the table view redisplays only those rows that are visible. It adjusts offsets if the table shrinks as a result of the reload.
    /// The table view’s delegate or data source calls this method when it wants the table view to completely reload its data.
    /// It should not be called in the methods that insert or delete rows, especially within an animation block implemented with calls to beginUpdates and endUpdates.
    ///
    /// - Warning: If you call this method before a previous invocation finished, the old completion block won't be executed.
    /// - seealso: https://stackoverflow.com/questions/16071503/how-to-tell-when-uitableview-has-completed-reloaddata
    /// - Parameter completion: The block to execute after the reload finished.
    func reloadData(calling completion:  @escaping () -> Void) {
        
        #if DEBUG
        if self.completionBlock != nil {
            print("Warning: Called before old completion block was executed! \(#file) Line \(#line) \(#function)")
        }
        #endif
        
        completionBlock = completion
        super.reloadData()
    }
    
    /// Layouts the subviews and then calls the completionBlock one time.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let block = self.completionBlock else { return }
        block()
        self.completionBlock = nil
    }
}

/// A default `TimetableClock` implementation returning default values if the timetableView has no `clock` set.
class TimetableClockProxy: TimetableClock {
    
    /// Returns the default value or asks the clock for the current date.
    /// - Parameter timetableView: The timetable asaking for the date.
    /// - Returns: The current date.
    func currentDate(_ timetableView: TimetableView) -> Date {
        if let clock = timetableView.clock {
            return clock.currentDate(timetableView)
        }
        return Date()
    }
}

/// Adding the capability to create screenshots of a view.
extension UIView {
    
    /// Creates a UIImage of the receiver.
    /// - Returns: The image
    func capture() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        return renderer.image { ctx in
            drawHierarchy(in: bounds, afterScreenUpdates: false)
        }
    }
}
