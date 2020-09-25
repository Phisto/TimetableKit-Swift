//
//  File.swift
//
//  Created by Simon Gaus on 20.05.20.
//

import UIKit

#warning("Remove and make delegate default")
/// The style of the timetable view.
enum TimetableStyle {
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
class TimetableView: TimetableBaseView {
    
    var style: TimetableStyle = .automatic

    init(_ frame: CGRect, with style: TimetableStyle) {
        
        self.style = style
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .blue
        
        
    }
    
    /// Reloads the rows, tiles and sections of the timetable view.
    ///
    /// Call this method to reload all the data that is used to construct the timetable, including cells, section headers, index arrays, tiles and so on.
    func reloadData() {
        
    }
    
    /// Transitions to the specified timetable view style.
    /// - Parameters:
    ///   - style: The new timtable view stlye.
    ///   - animated: If `true`, the style is changed using an animation. Defaults to `true`.
    func transition(to style: TimetableStyle, animated: Bool = true) {
        
    }
}

extension Notification.Name {

    static let tapWasRegistered = Notification.Name("SGTapWasRegisteredNotification")
    static let longPressWasRegistered = Notification.Name("SGLongPressWasRegisteredNotification")
}

class TimetableBaseView: UIView {
    
    var horizontalControl: HorizontalControl!
    var timescale: UIView!
    var tableView: UITableView!
    var navigationScrollView: UIScrollView!
    
    var tapGestureRecognizer: UITapGestureRecognizer!
    var longPressGestureRecognizer: UILongPressGestureRecognizer!
    
    var rowController = [UIViewController]()
    var unusedRowController = [UIViewController]()
    var rowControllerByIndexPath: [IndexPath: UIViewController]!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
     
    private func setupView() {
        backgroundColor = .red
        
        tableView = SGTableView.init(frame: .infinite, style: .grouped)
        tableView.register(TimetableRow.self, forCellReuseIdentifier: TimetableRow.cellIdentifier)
        tableView.allowsSelection = false
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
        tableView.sectionFooterHeight = 0.0
        tableView.backgroundView = nil
        self.addSubview(tableView)
        let _ = tableView.fit(to: self, leading: 0.0, trailing: 0.0, top: 88.0, bottom: 0.0)
        
        horizontalControl = HorizontalControl.init(frame: .infinite)
        horizontalControl.font = UIFont.systemFont(ofSize: 17.0, weight: .light)
        self.addSubview(horizontalControl)
        let _ = horizontalControl.stickToTop(of: self, height: 44.0, topMargin: 0.0)
        
        timescale = TimescaleView.init(frame: .infinite)
        self.addSubview(timescale)
        let _ = timescale.stickToTop(of: self, height: 44.0, topMargin: 44.0)
        
        navigationScrollView = UIScrollView.init(frame: .infinite)
        navigationScrollView.backgroundColor = .clear
        navigationScrollView.showsVerticalScrollIndicator = false
        navigationScrollView.showsHorizontalScrollIndicator = false
        navigationScrollView.isOpaque = false
        navigationScrollView.decelerationRate = .fast
        navigationScrollView.panGestureRecognizer.maximumNumberOfTouches = 1
        self.addSubview(navigationScrollView)
        let _ = navigationScrollView.fit(to: self, leading: 0, trailing: 0, top: 88.0, bottom: 0)
        
        tapGestureRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(TimetableBaseView.tapped(recognizer:)))
        longPressGestureRecognizer = UILongPressGestureRecognizer.init(target: self, action: #selector(TimetableBaseView.longPress(recognizer:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        self.addGestureRecognizer(longPressGestureRecognizer)
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
    
    @objc func longPress(recognizer: UILongPressGestureRecognizer) {
        
        // views (or their controllers) that could be long pressed should register
        // as observers for the 'SGLongPressWasRegisteredNotification' notification and
        // test if the touch event happend inside their bounds.
        //
        // let recognizer = notification.object as! UILongPressGestureRecognizer
        // let touchPoint = recognizer.location(in: self.myTappableView)
        // let wasTapped = self.myTappableView.bounds.contains(touchPoint)
        //
        switch recognizer.state {
        case .began:
            NotificationCenter.default.post(name: .longPressWasRegistered, object: recognizer)
        case .ended:
            NotificationCenter.default.post(name: .longPressWasRegistered, object: recognizer)
        default:
            break
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // hide seperators
        // doing it in setUpSubviews won't suffice...
        tableView.separatorStyle = .none
    }
}

/**
 The 'SGTableView' class adds the ability to synchronously reload the tabel view to the 'UITableView' class.
 
 There was the problem that when i tried to set the content offset of some collection views inside the table view cells directly after a call to -reloadData: the frame wont update and the collection views had still an offset of 0.
 
 - seealso: https://stackoverflow.com/questions/16071503/how-to-tell-when-uitableview-has-completed-reloaddata
 */
class SGTableView: UITableView {
    
    private var completionBlock: (()->Void)?
    
    /// Reloads the rows and sections of the table view and executes the completionBlock when finished.
    ///
    /// Call this method to reload all the data that is used to construct the table, including cells, section headers and footers, index arrays, and so on. For efficiency, the table view redisplays only those rows that are visible. It adjusts offsets if the table shrinks as a result of the reload. The table view’s delegate or data source calls this method when it wants the table view to completely reload its data. It should not be called in the methods that insert or delete rows, especially within an animation block implemented with calls to beginUpdates and endUpdates.
    ///
    /// - Warning: If you call this method before a previous invocation finished, the old completion block won't be executed.
    /// - seealso: https://stackoverflow.com/questions/16071503/how-to-tell-when-uitableview-has-completed-reloaddata
    /// - Parameter completion: The block to execute after the reload finished.
    func reloadData(calling completion:  @escaping () -> (Void)) {
        
        #if DEBUG
        if self.completionBlock != nil {
            print("Warning: Called before old completion block was executed! \(#file) Line \(#line) \(#function)")
        }
        #endif
        
        completionBlock = completion
        super.reloadData()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let block = self.completionBlock else { return }
        block()
    }
}
