//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


// MARK: - Delegate

public protocol VersoViewDelegate : class {
    /// This is triggered whenever the centered pages change.
    func currentPageIndexesChanged(verso:VersoView, pageIndexes:IndexSet, added:IndexSet, removed:IndexSet)
    /// This is triggered whenever the centered pages change, but only once any scrolling or re-layout animation finishes.
    func currentPageIndexesFinishedChanging(verso:VersoView, pageIndexes:IndexSet, added:IndexSet, removed:IndexSet)
    /// This is triggered whenever the visible pages change, whilst the user is scrolling, or after a relayout. This will be called before `currentPageIndexesFinishedChanging` callback is triggered.
    func visiblePageIndexesChanged(verso:VersoView, pageIndexes:IndexSet, added:IndexSet, removed:IndexSet)
    
    /// The user started zooming in/out of the spread containing the specified pages. ZoomScale is the how zoomed in we are when zooming started.
    func didStartZoomingPages(verso:VersoView, zoomingPageIndexes:IndexSet, zoomScale:CGFloat)
    /// ZoomScale changed - the user is in the process of zooming in/out of the spread containing the specified pages.
    func didZoomPages(verso:VersoView, zoomingPageIndexes:IndexSet, zoomScale:CGFloat)
    /// The user finished zooming in/out of the spread containing the specified pages. ZoomScale is the how zoomed in we are when zooming finishes.
    func didEndZoomingPages(verso:VersoView, zoomingPageIndexes:IndexSet, zoomScale:CGFloat)
}

/// Default implementation of delegate does nothing. This makes the delegate methods optional.
public extension VersoViewDelegate {
    func currentPageIndexesChanged(verso:VersoView, pageIndexes:IndexSet, added:IndexSet, removed:IndexSet) {}
    func currentPageIndexesFinishedChanging(verso:VersoView, pageIndexes:IndexSet, added:IndexSet, removed:IndexSet) {}
    func visiblePageIndexesChanged(verso:VersoView, pageIndexes:IndexSet, added:IndexSet, removed:IndexSet) {}
    func didStartZoomingPages(verso:VersoView, zoomingPageIndexes:IndexSet, zoomScale:CGFloat) {}
    func didZoomPages(verso:VersoView, zoomingPageIndexes:IndexSet, zoomScale:CGFloat) {}
    func didEndZoomingPages(verso:VersoView, zoomingPageIndexes:IndexSet, zoomScale:CGFloat) {}
}




// MARK: - DataSource

public protocol VersoViewDataSource : VersoViewDataSourceOptional {
    
    /// The SpreadConfiguration that defines the page count, and layout of the pages, within this verso.
    func spreadConfiguration(verso:VersoView, size:CGSize) -> VersoSpreadConfiguration
    
    /// Gives the dataSource a chance to configure the pageView. 
    /// This must not take a long time, as it is called during scrolling.
    /// The pageView's `pageIndex` property will have been set, but its size will not be correct
    func configurePage(verso:VersoView, pageView:VersoPageView)
    
    
    /// What subclass of VersoPageView should be used.
    func pageViewClass(verso:VersoView, pageIndex:Int) -> VersoPageViewClass
    
}

public protocol VersoViewDataSourceOptional : class {
    /// How many pages before the currently visible pageIndexes to preload. 
    /// Ignored if `preloadPageIndexesForVerso` does not return nil.
    func previousPageCountToPreload(verso:VersoView, visiblePageIndexes:IndexSet) -> Int
    
    /// How many pages after the currently visible pageIndexes to preload.
    /// Ignored if `preloadPageIndexesForVerso` does not return nil.
    func nextPageCountToPreload(verso:VersoView, visiblePageIndexes:IndexSet) -> Int
    
    /// Gives you a chance to modify the page indexes to preload around the visible page indexes.
    /// This is for more advanced customization of the preloading indexes.
    /// The `preloadPageIndexes` property is based on the prev/nextPageCount dataSource results.
    /// If nil (default), set that is passed as `preloadPageIndexes` will be used unmodified
    func adjustPreloadPageIndexes(verso:VersoView, visiblePageIndexes:IndexSet, preloadPageIndexes:IndexSet) -> IndexSet?
    
    /// What color should the background fade to when zooming.
    func zoomBackgroundColor(verso:VersoView, zoomingPageIndexes:IndexSet) -> UIColor
    
    /// Return a view to overlay over the currently visible pages. 
    /// This is called every time the layout changes, or the user finishes scrolling.
    func spreadOverlayView(verso:VersoView, overlaySize:CGSize, pageFrames:[Int:CGRect]) -> UIView?
}

/// Default Values for Optional DataSource
public extension VersoViewDataSourceOptional {
    
    func previousPageCountToPreload(verso:VersoView, visiblePageIndexes:IndexSet) -> Int {
        return 2
    }
    func nextPageCountToPreload(verso:VersoView, visiblePageIndexes:IndexSet) -> Int {
        return 6
    }
    func adjustPreloadPageIndexes(verso:VersoView, visiblePageIndexes:IndexSet, preloadPageIndexes:IndexSet) -> IndexSet? {
        return nil
    }
    func zoomBackgroundColor(verso:VersoView, zoomingPageIndexes:IndexSet) -> UIColor {
        return UIColor(white: 0, alpha: 0.7)
    }
    func spreadOverlayView(verso:VersoView, overlaySize:CGSize, pageFrames:[Int:CGRect]) -> UIView? {
        return nil
    }
}
/// Have VersoView as the source of the default optional values, for when dataSource is nil.
extension VersoView : VersoViewDataSourceOptional {}



// MARK: -

/// The class that should be sub-classed to build your own pages
open class VersoPageView : UIView {
    public fileprivate(set) var pageIndex:Int = NSNotFound
    
    /// make init(frame:) required
    required override public init(frame: CGRect) { super.init(frame: frame) }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return size
    }
}
public typealias VersoPageViewClass = VersoPageView.Type




// MARK: -

public class VersoView : UIView {
    
    // MARK: UIView subclassing
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(pageScrollView)
        
        pageScrollView.addSubview(zoomView)
        
        setNeedsLayout()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    fileprivate var performingLayout:Bool = false
    
    override public func layoutSubviews() {
        assert(dataSource != nil, "You must provide a VersoDataSource")
        
        super.layoutSubviews()
        
        _regenerateSpreadLayout(targetPageIndex: centeredSpreadPageIndexes.first ?? 0)
    }
    
    override public func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // When Verso is moved to a new superview, reload all the pages.
        // This is basically a 'first-run' event
        if superview != nil {
            reloadPages()
        }
    }
    
    

    
    
    
    /// The datasource for this VersoView. You must set this.
    public weak var dataSource:VersoViewDataSource?
    
    /// The delegate for this Veros. This is optional.
    public weak var delegate:VersoViewDelegate?
    
    
    
    /// The page indexes of the spread that was centered when scrolling animations last ended
    public fileprivate(set) var currentPageIndexes:IndexSet = IndexSet()
    
    /// The page indexes of all the pageViews that are currently visible
    public fileprivate(set) var visiblePageIndexes:IndexSet = IndexSet()
    
    /// The spreadConfiguration provided by the dataSource
    public fileprivate(set) var spreadConfiguration:VersoSpreadConfiguration?
    
    
    public var panGestureRecognizer:UIPanGestureRecognizer {
        return pageScrollView.panGestureRecognizer
    }
    public var zoomDoubleTapGestureRecognizer:UITapGestureRecognizer? {
        return zoomView.sgn_doubleTapGesture
    }
    
    
    /// This triggers a refetch of info from the dataSource, and all the pageViews are re-configured.
    public func reloadPages(targetPageIndex:Int? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            
            let actualTargetPageIndex = targetPageIndex ?? self?.centeredSpreadPageIndexes.first ?? 0
            
            for (_, pageView) in self!.pageViewsByPageIndex {
                pageView.removeFromSuperview()
            }
            self?.pageViewsByPageIndex = [:]
            
            self?.currentSpreadIndex = nil
            self?.currentPageIndexes = IndexSet()
            self?.centeredSpreadIndex = nil
            self?.visiblePageIndexes = IndexSet()
            self?.centeredSpreadIndex = nil
            self?.centeredSpreadPageIndexes = IndexSet()
            
            self?.spreadConfiguration = nil
            
            self?._regenerateSpreadLayout(targetPageIndex: actualTargetPageIndex)
        }
    }
    
    
    /// Scrolls the VersoView to point to a specific page. This is a no-op if the page doesnt exist.
    public func jump(toPageIndex:Int, animated:Bool) {
        DispatchQueue.main.async { [weak self] in
            
            guard self?.spreadConfiguration != nil else {
                return
            }
            
            let clampedIndex = max(min((self?.spreadConfiguration?.pageCount ?? 0) - 1, toPageIndex), 0)
            
            if let spreadIndex = self?.spreadConfiguration?.spreadIndex(forPageIndex:clampedIndex) {
                self?.pageScrollView.setContentOffset(VersoView.calc_scrollOffset(spreadIndex: spreadIndex, spreadFrames:self!.spreadFrames, versoSize: self!.versoSize), animated: animated)
                
                if !animated {
                    self?._didFinishScrolling()
                }
            }
        }
    }
    
    
    /// This causes all the preloaded pages to be reconfigured by the dataSource
    public func reconfigureVisiblePages() {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            for (_, pageView) in self!.pageViewsByPageIndex {
                self!._configure(pageView:pageView)
            }
        }
    }
    
    
    /// Return the VersoPageView for a pageIndex, or nil if the pageView is not in memory
    public func getPageViewIfLoaded(_ pageIndex:Int) -> VersoPageView? {
        return pageViewsByPageIndex[pageIndex]
    }
    
    public func reconfigureSpreadOverlay() {
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            
            self?._updateSpreadOverlay()
        }
    }
    
    
    
    
    
    
    
    // MARK: - Private Proprties
    
    /// The current size of this VersoView
    fileprivate var versoSize:CGSize = CGSize.zero
    
    /// Precalculated frames for all spreads
    fileprivate var spreadFrames:[CGRect] = []
    
    /// Precalculated initial (non-resized) frames for all pages
    fileprivate var pageFrames:[CGRect] = []
    
    /// the pageIndexes that are embedded in the zoomView
    fileprivate var zoomingPageIndexes:IndexSet = IndexSet()
    
    
    /// the pageViews that are currently being used
    fileprivate var pageViewsByPageIndex = [Int:VersoPageView]()

    /// the spreadIndex under the center of the verso (with some magic for first/last spreads)
    fileprivate var centeredSpreadIndex:Int?
    fileprivate var centeredSpreadPageIndexes:IndexSet = IndexSet()

    /// the `centeredSpreadIndex` when animation ended
    fileprivate var currentSpreadIndex:Int?

    /// the centeredSpreadIndex when we started dragging
    fileprivate var dragStartSpreadIndex:Int = 0
    /// the visibleRect when the drag starts
    fileprivate var dragStartVisibleRect:CGRect = CGRect.zero
    
    /// The background color provided by the datasource when we started zooming.
    fileprivate var zoomTargetBackgroundColor:UIColor?
    
    /// A neat trick to allow pure-swift optional protocol methods: http://blog.stablekernel.com/optional-protocol-methods-in-pure-swift
    fileprivate var dataSourceOptional: VersoViewDataSourceOptional {
        return dataSource ?? self
    }

    
    
    // MARK: - Spread & PageView Layout
    
    /**
     Re-calc all the spread frames.
     Then recalculates the contentSize & offset of the pageScrollView.
     Finally re-position all the pageViews
     */
    fileprivate func _regenerateSpreadLayout(targetPageIndex:Int) {
        
        let newVersoSize = bounds.size
        var newSpreadConfig = spreadConfiguration
        
        
        // get a new spread configuration
        if spreadConfiguration == nil || versoSize != newVersoSize {
            newSpreadConfig = dataSource?.spreadConfiguration(verso:self, size: newVersoSize)
        }
        
        let willRelayout = versoSize != newVersoSize || spreadConfiguration != newSpreadConfig
        
        
        if willRelayout {
            // move pageViews out of zoomView (without side-effects)
            UIView.performWithoutAnimation { [weak self] in
                self?._resetZoomView()
            }
        }
        
        
        pageScrollView.frame = bounds
        versoSize = newVersoSize
        spreadConfiguration = newSpreadConfig
        
        
        // there was a change in size or configuration ... 
        // recalc all layout states, and update spreads
        guard willRelayout == true else {
            return
        }
        
        guard let config = spreadConfiguration else {
            assert(spreadConfiguration != nil, "You must provide a VersoSpreadConfiguration")
            return
        }
        
        
        CATransaction.begin() // start a transaction, so we get a completion handler
        
        performingLayout = true
        
        
        // when the layout is complete, move the active page views into the zoomview
        CATransaction.setCompletionBlock { [weak self] in
            
            self?.pageScrollView.isScrollEnabled = true
            
            self?._enableZoomingForCurrentPageViews(force: true)
            
            self?.performingLayout = false
            
        }
        
        // remove the overlay
        spreadOverlayView?.removeFromSuperview()
        spreadOverlayView = nil

        
        // disable scrolling
        pageScrollView.isScrollEnabled = false
        
        
        // (p)recalculate new frames for all spreads & pages
        spreadFrames = VersoView.calc_spreadFrames(versoSize: versoSize, spreadConfig: config)
        pageFrames = VersoView.calc_pageFrames(spreadFrames: spreadFrames, spreadConfig: config)
        
        
        // update the contentSize to match the new spreadFrames
        pageScrollView.contentSize = VersoView.calc_contentSize(spreadFrames: spreadFrames)
        

        // insta-scroll to that spread
        let targetSpreadIndex = config.spreadIndex(forPageIndex:targetPageIndex)
        pageScrollView.setContentOffset(VersoView.calc_scrollOffset(spreadIndex:targetSpreadIndex ?? 0, spreadFrames:spreadFrames, versoSize: versoSize), animated: false)
        
        
        _updateVisiblePageIndexes()
        
        // generate/config any extra pageviews that we might need
        // these will be added/positioned in the pagingScrollView
        _preparePageViews()
        
        
        // update to the current & visible spread index now we have updated the content offset & spreadFrames
        _updateCurrentSpreadIndex()
        
        
        CATransaction.commit()

    }
    
    fileprivate func _frameForPageViews(_ pageIndexes:IndexSet) -> CGRect {
        
        var combinedFrame:CGRect?
        if pageIndexes.count > 0 {
            for pageIndex in pageIndexes {
                if let pageView = pageViewsByPageIndex[pageIndex] {
                    let pageFrame = pageView.frame
                
                    combinedFrame = combinedFrame?.union(pageFrame) ?? pageFrame
                }
            }
        }
        
        return combinedFrame ?? CGRect.zero
    }
    
    
    /// This handles the creation/re-use and configuration of pageViews. This is triggered whilst the user scrolls.
    fileprivate func _preparePageViews() {

        let visibleFrame = pageScrollView.bounds
        
        // generate/config any extra pageviews that we might need
        // these will be added/positioned in the pagingScrollView
        let pageIndexesToPrepare = _pageIndexesToPreloadAround(visiblePageIndexes)
        
        var preparedPageViews = [Int:VersoPageView]()
        
        // page indexes that dont have a view
        var missingPageViewIndexes = pageIndexesToPrepare
        // page views that aren't needed anymore
        var recyclablePageViews = [VersoPageView]()
        
        
        // go through all the page views we have, and find out what we need
        for (pageIndex, pageView) in pageViewsByPageIndex {
            
            if pageIndexesToPrepare.contains(pageIndex) == false && zoomingPageIndexes.contains(pageIndex) == false {
                // we have a page view that can be recycled
                recyclablePageViews.append(pageView)
            } else {
                missingPageViewIndexes.remove(pageIndex)
                preparedPageViews[pageIndex] = pageView
            }
        }
    
        
        if missingPageViewIndexes.count > 0 {
            // get pageviews for all the missing indexes
            for pageIndex in missingPageViewIndexes {
                
                var pageView:VersoPageView? = nil
                
                // get the class of the page at that index
                let pageViewClass:VersoPageViewClass = dataSource?.pageViewClass(verso:self, pageIndex: pageIndex) ?? VersoPageView.self
                
                // try to find a pageView of the correct type from the recycle bin
                if let recycleIndex = recyclablePageViews.index(where: { (recyclablePageView:VersoPageView) -> Bool in
                    return type(of: recyclablePageView) === pageViewClass
                }) {
                    pageView = recyclablePageViews.remove(at: recycleIndex)
                }
                
                // nothing in the bin - make a new one
                if pageView == nil {
                    // need to give new PageViews an initial frame otherwise they fly in from 0,0
                    let initialFrame = pageFrames[verso_safe:pageIndex] ?? CGRect.zero
                    
                    pageView = pageViewClass.init(frame:initialFrame)
                    pageScrollView.insertSubview(pageView!, belowSubview: zoomView)
                }
                
                pageView!.pageIndex = pageIndex
                _configure(pageView:pageView!)
                
                preparedPageViews[pageIndex] = pageView!
            }
        }
        
        // clean up any unused recyclables
        for pageView in recyclablePageViews {
            pageView.removeFromSuperview()
        }
        
        
        // do final re-positioning of the pageViews
        for (pageIndex, pageView) in preparedPageViews {
            
            if zoomingPageIndexes.contains(pageIndex) == true {
                continue
            }

            pageView.transform = CGAffineTransform.identity
            pageView.frame = _resizedFrame(pageView:pageView)
            pageView.alpha = 1
            
            
            // find out how far the pageView is from the visible pages
            var indexDist = 0
            if pageView.pageIndex > visiblePageIndexes.last {
                indexDist = pageView.pageIndex - visiblePageIndexes.last!
            } else if pageView.pageIndex < visiblePageIndexes.first {
                indexDist = pageView.pageIndex - visiblePageIndexes.first!
            }
            
            // style the non-visible pages
            if indexDist != 0 {
                pageView.alpha = 0
                pageView.transform = CGAffineTransform(translationX: visibleFrame.width/2 * CGFloat(indexDist), y: 0)
            }
        }

        pageViewsByPageIndex = preparedPageViews
    }
    
    /// Asks the datasource for which pageIndexes around the specified set we should pre-load.
    fileprivate func _pageIndexesToPreloadAround(_ pageIndexes:IndexSet)->IndexSet {
        guard let config = spreadConfiguration else {
            return IndexSet()
        }
        
        guard pageIndexes.count > 0 && config.pageCount > 0 else {
            return IndexSet()
        }
        
        // get all the page indexes we are going to config and position, based on delegate callbacks
        var preloadPageIndexes = pageIndexes
        
        let beforeCount = dataSourceOptional.previousPageCountToPreload(verso:self, visiblePageIndexes: pageIndexes)
        let afterCount = dataSourceOptional.nextPageCountToPreload(verso:self, visiblePageIndexes: pageIndexes)
        
        let newFirstIndex = max(pageIndexes.first!-beforeCount, 0)
        let newLastIndex = min(pageIndexes.last!+afterCount, config.pageCount-1)
        
        preloadPageIndexes.insert(integersIn:newFirstIndex...newLastIndex)
        
        if let adjustedPreloadIndexes = dataSourceOptional.adjustPreloadPageIndexes(verso:self, visiblePageIndexes: pageIndexes, preloadPageIndexes: preloadPageIndexes) {
            preloadPageIndexes = adjustedPreloadIndexes
        }
        
        if preloadPageIndexes.last! >= config.pageCount {
            preloadPageIndexes.remove(integersIn:config.pageCount ... preloadPageIndexes.last!)
        }
        if preloadPageIndexes.first! < 0 {
            preloadPageIndexes.remove(integersIn:preloadPageIndexes.first! ..< 0)
        }
        
        return preloadPageIndexes
    }
    
    /// Asks the datasource to configure its pageview (done from preparePageView
    fileprivate func _configure(pageView:VersoPageView) {
        if pageView.pageIndex != NSNotFound {
            dataSource?.configurePage(verso:self, pageView: pageView)
        }
    }
    
    /// ask the pageView for the size that it wants to be (within a max page frame size)
    fileprivate func _resizedFrame(pageView:VersoPageView) -> CGRect {
        
        let maxFrame = pageFrames[pageView.pageIndex]
        let pageSize = pageView.sizeThatFits(maxFrame.size)
        
        
        var pageFrame = maxFrame
        pageFrame.size = pageSize
        pageFrame.origin.y = round(maxFrame.midY - pageSize.height/2)
        
        
        let alignment = spreadConfiguration?.pageAlignment(forPageIndex:pageView.pageIndex) ?? .center
        
        switch alignment {
        case .left:
            pageFrame.origin.x = maxFrame.minX
        case .right:
            pageFrame.origin.x = maxFrame.maxX - pageSize.width
        case .center:
            pageFrame.origin.x = round(maxFrame.midX - pageSize.width/2)
        }
        
        return pageFrame
    }
    
    
    
    
    
    
    
    // MARK: Spread index state
    
    /**
        Do the calculations to figure out which spread we are currently looking at.
        This will also update the centeredSpreadPageIndexes
        This is called while the user scrolls
     */
    fileprivate func _updateCenteredSpreadIndex() {
        guard let config = spreadConfiguration else {
            return
        }
        

        var newCenteredSpreadIndex:Int?
        
        // to avoid skipping frames with rounding errors, expand by a few pxs
        let visibleRect = pageScrollView.bounds.insetBy(dx: -2, dy: -2)
        
        if spreadFrames.count == 0 {
            newCenteredSpreadIndex = nil
        }
        else if visibleRect.contains(spreadFrames.first!) {
            // first page is visible - assume first
            newCenteredSpreadIndex = 0
        }
        else if visibleRect.contains(spreadFrames.last!) {
            // last page is visible - assume last
            newCenteredSpreadIndex = spreadFrames.count-1
        }
        else {
            let visibleMid = CGPoint(x:visibleRect.midX, y:visibleRect.midY)
            
            var minIndex = 0
            var maxIndex = spreadFrames.count-1
            
            // binary search which spread is under the center of the visible rect
            var spreadIndex:Int = 0
            while (true) {
                spreadIndex = (minIndex + maxIndex)/2
                
                let spreadFrame = spreadFrames[spreadIndex]
                if spreadFrame.contains(visibleMid) {
                    newCenteredSpreadIndex = spreadIndex
                    break
                } else if (minIndex > maxIndex) {
                    break
                } else {
                    if visibleMid.x < spreadFrame.midX {
                        maxIndex = spreadIndex - 1
                    } else {
                        minIndex = spreadIndex + 1
                    }
                }
            }
            
            if newCenteredSpreadIndex == nil {
                newCenteredSpreadIndex = spreadIndex
            }
        }
        
        centeredSpreadIndex = newCenteredSpreadIndex
        
        
        let newCenteredSpreadPageIndexes = centeredSpreadIndex != nil ? config.pageIndexes(forSpreadIndex:centeredSpreadIndex!) : IndexSet()
        guard newCenteredSpreadPageIndexes != centeredSpreadPageIndexes else {
            return
        }
        
        // calc diff
        let addedIndexes = newCenteredSpreadPageIndexes.subtracting(centeredSpreadPageIndexes)
        let removedIndexes = centeredSpreadPageIndexes.subtracting(newCenteredSpreadPageIndexes)
        
        centeredSpreadPageIndexes = newCenteredSpreadPageIndexes
        
        // notify delegate of changes to current page
        delegate?.currentPageIndexesChanged(verso:self, pageIndexes: centeredSpreadPageIndexes, added: addedIndexes, removed: removedIndexes)
    }
    
    
    /**
        Updates a separate cache of the centeredSpreadIndex.
        This is called whenever scrolling animations finish.
        Will notify the delegate if there is a change
     */
    fileprivate func _updateCurrentSpreadIndex() {
        guard let config = spreadConfiguration else {
            return
        }
        
        _updateCenteredSpreadIndex()
        
        currentSpreadIndex = centeredSpreadIndex
        
        
        // update currentPageIndexes
        let newCurrentPageIndexes = currentSpreadIndex != nil ? config.pageIndexes(forSpreadIndex: currentSpreadIndex!) : IndexSet()
        
        guard newCurrentPageIndexes != currentPageIndexes else {
            return
        }
        
        
        // calc diff
        let addedIndexes = newCurrentPageIndexes.subtracting(currentPageIndexes)
        let removedIndexes = currentPageIndexes.subtracting(newCurrentPageIndexes)
        
        currentPageIndexes = newCurrentPageIndexes
        
        // notify delegate of changes to current page
        delegate?.currentPageIndexesFinishedChanging(verso:self, pageIndexes: currentPageIndexes, added: addedIndexes, removed: removedIndexes)
    }
    
    
    
    fileprivate func _updateVisiblePageIndexes() {
        
        let visibleFrame = pageScrollView.bounds
        
        let newVisiblePageIndexes = VersoView.calc_visiblePageIndexes(in: visibleFrame, pageFrames: pageFrames, fullyVisible: false)

        guard newVisiblePageIndexes != visiblePageIndexes else {
            return
        }
        
        // calc diff
        let addedIndexes = newVisiblePageIndexes.subtracting(visiblePageIndexes)
        let removedIndexes = visiblePageIndexes.subtracting(newVisiblePageIndexes)
        
        visiblePageIndexes = newVisiblePageIndexes
        
        // notify delegate of changes to current page
        delegate?.visiblePageIndexesChanged(verso:self, pageIndexes: visiblePageIndexes, added: addedIndexes, removed: removedIndexes)

    }
    
    
    
    
    
    
    
    
    // MARK: - Scrolling Pages
    
    fileprivate func _didStartScrolling() {
        // disable scrolling
        zoomView.maximumZoomScale = 1.0
    }
    @objc fileprivate func _didFinishScrolling() {
        // dont do any post-scrolling layout if the user rotated the device while scroll-animations were being performed.
        if performingLayout == false {
            
            _updateVisiblePageIndexes()
            
            _preparePageViews()
            
            _updateCurrentSpreadIndex()
            
            _enableZoomingForCurrentPageViews(force: false)
            
            _updateMaxZoomScale()
        }
    }
    
    
    fileprivate func _updateSpreadOverlay() {
        
        var spreadPageFrames:[Int:CGRect] = [:]
        if zoomingPageIndexes.count > 0 {
            for pageIndex in zoomingPageIndexes {
                if let pageView = pageViewsByPageIndex[pageIndex] {
                    
                    let pageViewFrame = pageView.convert(pageView.bounds, to: zoomViewContents)
                    
                    spreadPageFrames[pageIndex] = pageViewFrame
                }
            }
        }

        let newSpreadOverlayView = spreadPageFrames.count > 0 ? dataSourceOptional.spreadOverlayView(verso:self, overlaySize:zoomViewContents.bounds.size, pageFrames:spreadPageFrames) : nil
        
        if newSpreadOverlayView != spreadOverlayView {
            spreadOverlayView?.removeFromSuperview()
            spreadOverlayView = newSpreadOverlayView
            spreadOverlayView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        
        
        if spreadOverlayView != nil {
            zoomViewContents.addSubview(spreadOverlayView!)
            spreadOverlayView?.frame = zoomViewContents.bounds
        }
    }
    
    
    
    
    // MARK: - Zooming
    
    fileprivate func _updateMaxZoomScale() {
        // update zoom scale based on the current spread
        if let spreadIndex = currentSpreadIndex,
            let zoomScale = spreadConfiguration?.spreadProperty(forSpreadIndex:spreadIndex)?.maxZoomScale {
            
            zoomView.maximumZoomScale = zoomScale
        } else {
            zoomView.maximumZoomScale = 1.0
        }

    }
    /// Remove all pageViews that are in the zoomView, placing them correctly back in the pageScrollView
    fileprivate func _resetZoomView() {
        
        // reset previous zooming pageViews
        if zoomingPageIndexes.count > 0 {
            for pageIndex in zoomingPageIndexes {
                if let pageView = pageViewsByPageIndex[pageIndex] {
                    pageScrollView.insertSubview(pageView, belowSubview: zoomView)
                    
                    pageView.transform = CGAffineTransform.identity
                    pageView.frame = _resizedFrame(pageView:pageView)
                    pageView.alpha = 1
                }
            }
        }
    
        if zoomView.zoomScale != 1 && zoomingPageIndexes.count > 0 {
            _didStartZooming()
            zoomView.zoomScale = 1.0
            _didEndZooming()
        }
        
        zoomView.maximumZoomScale = 1.0
        zoomView.backgroundColor = UIColor.clear
        zoomingPageIndexes = IndexSet()
    }
    
    fileprivate var spreadOverlayView:UIView?
    
    /**
     Resets the zoomView to correct location and adds pageviews that will be zoomed
     If `force` is false we will only enable zooming when the page indexes to zoom have changed.
     */
    fileprivate func _enableZoomingForCurrentPageViews(force:Bool) {
        
        guard zoomingPageIndexes != currentPageIndexes || force else {
            return
        }
        
        _resetZoomView()
        
        _updateMaxZoomScale()
        
        // update which pages are zooming
        zoomingPageIndexes = currentPageIndexes
        
        
        // reset the zoomview
        zoomView.zoomScale = 1.0
        zoomView.contentInset = UIEdgeInsets.zero
        zoomView.contentOffset = CGPoint.zero
        
        // move zoomview visible frame
        zoomView.frame = pageScrollView.bounds
        
        
        // reset the zoomContents to fill the zoomView
        zoomViewContents.frame = zoomView.bounds
        
        
        // get the PageViews that will be in zoomview, and the combined frame for all those views
        var combinedPageFrame = CGRect.zero
        
        var activePageViews = [VersoPageView]()
        if zoomingPageIndexes.count > 0 {
            for pageIndex in zoomingPageIndexes {
                if let pageView = pageViewsByPageIndex[pageIndex] {
                    
                    activePageViews.append(pageView)
                    
                    let pageViewFrame = pageView.convert(pageView.bounds, to: zoomView)
                    combinedPageFrame = combinedPageFrame==CGRect.zero ? pageViewFrame : combinedPageFrame.union(pageViewFrame)
                }
            }
        }
    
        zoomView.contentSize = combinedPageFrame.size
        zoomViewContents.frame = combinedPageFrame
        
        for pageView in activePageViews {
            
            let newPageFrame = zoomViewContents.convert(pageView.bounds, from: pageView)
            pageView.frame = newPageFrame
            zoomViewContents.addSubview(pageView)
        }
        
        zoomViewContents.frame = CGRect(origin: CGPoint.zero, size: combinedPageFrame.size)
        
        zoomView.targetContentFrame = combinedPageFrame
        
        _updateSpreadOverlay()
    }
    
    fileprivate func _didStartZooming() {
        if zoomingPageIndexes.count > 0 {
            delegate?.didStartZoomingPages(verso:self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
            
            zoomTargetBackgroundColor = dataSourceOptional.zoomBackgroundColor(verso:self, zoomingPageIndexes:zoomingPageIndexes)
        }
    }
    
    fileprivate func _didZoom() {
        
        // fade in the zoomView's background as we zoom
        
        if zoomTargetBackgroundColor == nil {
            zoomTargetBackgroundColor = dataSourceOptional.zoomBackgroundColor(verso:self, zoomingPageIndexes:zoomingPageIndexes)
        }
        
        var maxAlpha:CGFloat = 1.0
        zoomTargetBackgroundColor!.getWhite(nil, alpha: &maxAlpha)
        
        // alpha 0->0.7 zoom 1->1.5
        // x0 + ((x1-x0) / (y1-y0)) * (y-y0)
        let targetAlpha = min(0 + ((maxAlpha-0) / (1.5-1)) * (zoomView.zoomScale-1), maxAlpha)
        zoomView.backgroundColor = zoomTargetBackgroundColor!.withAlphaComponent(targetAlpha)
        
        if zoomingPageIndexes.count > 0 {
            delegate?.didZoomPages(verso:self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
        }
    }
    
    fileprivate func _didEndZooming() {
        if zoomView.zoomScale <= zoomView.minimumZoomScale + 0.01 {
            pageScrollView.isScrollEnabled = true
        }
        else {
            pageScrollView.isScrollEnabled = false
        }
        
        
        if zoomingPageIndexes.count > 0 {
            delegate?.didEndZoomingPages(verso:self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
        }
    }
    
    
    
    
    
    // MARK: - Subviews
    
    fileprivate lazy var pageScrollView:UIScrollView = {
        let view = UIScrollView(frame:self.frame)
        view.delegate = self
        view.decelerationRate = UIScrollViewDecelerationRateFast
        view.delaysContentTouches = false
        
        return view
    }()
    
    
    fileprivate lazy var zoomView:InsetZoomView = {
        let view = InsetZoomView(frame:self.frame)
        
        view.addSubview(self.zoomViewContents)

        
        view.delegate = self
        view.maximumZoomScale = 1.0
        
        view.sgn_enableDoubleTapGestures()
        
        return view
    }()
    
    fileprivate lazy var zoomViewContents:UIView = {
        let view = UIView()
        return view
    }()
    
    
}





// MARK: - UIScrollViewDelegate

extension VersoView : UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            
            // only update spreadIndex and pageViews during scroll when it was manually triggered
            if scrollView.isDragging == true || scrollView.isDecelerating == true || scrollView.isTracking == true {
                _updateCenteredSpreadIndex()
                _updateVisiblePageIndexes()
                _preparePageViews()
            }
            
        }
    }
    
    
    // MARK: Animation
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            _didFinishScrolling()
        }
    }
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            // cancel any delayed didFinishScrolling requests - see `scrollViewDidEndDecelerating`
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(VersoView._didFinishScrolling), object: nil)
        }
    }
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            
            var delay:TimeInterval = 0
            // There are some edge cases where, when dragging rapidly, we get a decel finished event, and then a bounce-back decel again
            // In that case (where scrolled out of bounds and decel finished) wait before triggering didEndScrolling
            // We delay rather than just not calling to make sure we dont end up in the situation where didEndScrolling is never called
            if scrollView.bounces && (scrollView.bounds.maxX > scrollView.contentSize.width || scrollView.bounds.minX < 0 || scrollView.bounds.maxY > scrollView.contentSize.height || scrollView.bounds.minY < 0) {
                delay = 0.2
            }
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(VersoView._didFinishScrolling), object: nil)
            self.perform(#selector(VersoView._didFinishScrolling), with: nil, afterDelay: delay)
        }
    }
    
    
    // MARK: Dragging
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            
            guard spreadConfiguration?.spreadCount > 0 else {
                return
            }
            
            // calculate the spreadIndex that was centered when  we started this drag
            dragStartSpreadIndex = centeredSpreadIndex ?? 0
            dragStartVisibleRect = scrollView.bounds
            _didStartScrolling()
        }
    }
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == pageScrollView {
            guard let config = spreadConfiguration , config.spreadCount > 0 else {
                return
            }
            
            var targetSpreadIndex = centeredSpreadIndex ?? 0
            
            // spread hasnt changed, use velocity to inc/dec spread
            if targetSpreadIndex == dragStartSpreadIndex {
                if velocity.x > 0.5 {
                    targetSpreadIndex += 1
                }
                else if velocity.x < -0.5 {
                    targetSpreadIndex -= 1
                }
                else {
                    // no velocity, so se if the next or prev spreads are a certain % visible
                    let visibleRect = scrollView.bounds
                    
                    let changeOnPercentageVisible:CGFloat = 0.1                    
                    
                    if visibleRect.origin.x > dragStartVisibleRect.origin.x && VersoView.calc_spreadVisibilityPercentage(spreadIndex:targetSpreadIndex+1, visibleRect: visibleRect, spreadFrames: spreadFrames) > changeOnPercentageVisible {
                        targetSpreadIndex += 1
                    }
                    else if visibleRect.origin.x < dragStartVisibleRect.origin.x &&  VersoView.calc_spreadVisibilityPercentage(spreadIndex:targetSpreadIndex-1, visibleRect: visibleRect, spreadFrames: spreadFrames) > changeOnPercentageVisible {
                        targetSpreadIndex -= 1
                    }
                }
            }
            
            
            
            // clamp targetSpread
            targetSpreadIndex = min(max(targetSpreadIndex, 0), config.spreadCount-1)
            
            // generate offset for the new target spread
            targetContentOffset.pointee = VersoView.calc_scrollOffset(spreadIndex:targetSpreadIndex, spreadFrames: spreadFrames, versoSize: versoSize)
        }
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == pageScrollView {
            if !decelerate && !scrollView.isZoomBouncing {
                _didFinishScrolling()
            }
        }
    }
    
    
    
    
    // MARK: Zooming
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        if scrollView == zoomView {
            _didStartZooming()
        }
    }
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView == zoomView {
            
            _didZoom()
        }
    }
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scrollView == zoomView {
            _didEndZooming()
        }
    }
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if scrollView == zoomView {
            return zoomViewContents
        }
        return nil
    }
    
}







// MARK: - Layout Utilities

extension VersoView {
    
    /// Calculate all the frames of all the spreads
    fileprivate static func calc_spreadFrames(versoSize:CGSize, spreadConfig:VersoSpreadConfiguration) -> [CGRect] {
        
        let spreadSpacing:CGFloat = spreadConfig.spreadSpacing
        
        // recalculate frames for all spreads
        var newSpreadFrames:[CGRect] = []
        
        var prevSpreadFrame = CGRect.zero
        for properties in spreadConfig.spreadProperties {
            
            var spreadFrame = CGRect.zero
            spreadFrame.size.width = floor(versoSize.width * properties.widthPercentage)
            spreadFrame.size.height = versoSize.height
            spreadFrame.origin.x = prevSpreadFrame.maxX + spreadSpacing
            
            newSpreadFrames.append(spreadFrame)
            
            prevSpreadFrame = spreadFrame
        }
        return newSpreadFrames
    }
    
    /// Calculate all the frames of all the pages
    fileprivate static func calc_pageFrames(spreadFrames:[CGRect], spreadConfig:VersoSpreadConfiguration) -> [CGRect] {
        
        var pageFrames:[CGRect] = []
        
        for (spreadIndex, spreadFrame) in spreadFrames.enumerated() {
            
            let spreadType = spreadConfig.spreadType(forSpreadIndex:spreadIndex)
            
            switch spreadType {
            case .double(_,_):
                var versoPageFrame = spreadFrame
                versoPageFrame.size.width /= 2
                
                var rectoPageFrame = versoPageFrame
                rectoPageFrame.origin.x = versoPageFrame.maxX
                
                pageFrames.append(versoPageFrame)
                pageFrames.append(rectoPageFrame)
                
            case .single(_):
                pageFrames.append(spreadFrame)
            default:
                break
            }
        }
        
        return pageFrames
    }
    
    
    /// Calculate the size of all the spreads
    fileprivate static func calc_contentSize(spreadFrames:[CGRect]) -> CGSize {
        var size = CGSize.zero
        if let lastFrame = spreadFrames.last {
            size.width = lastFrame.maxX
            size.height = lastFrame.size.height
        }
        return size
    }
    
    /// Calculate the scroll position of a specific spread
    fileprivate static func calc_scrollOffset(spreadIndex:Int, spreadFrames:[CGRect], versoSize:CGSize) -> CGPoint {
        
        var offset = CGPoint.zero
        
        if let spreadFrame = spreadFrames[verso_safe:spreadIndex] {
            
            if spreadIndex == 0 {
                offset.x = spreadFrame.origin.x
            }
            else if spreadIndex == spreadFrames.count-1 {
                offset.x = spreadFrame.maxX - versoSize.width
            }
            else {
                offset.x = spreadFrame.midX - (versoSize.width/2)
            }
        }
        
        return offset
    }
    
    /// Calculate the visibility % of a specific spread within a certain rect
    fileprivate static func calc_spreadVisibilityPercentage(spreadIndex:Int, visibleRect:CGRect, spreadFrames:[CGRect]) -> CGFloat {
        
        if let spreadFrame = spreadFrames[verso_safe:spreadIndex] , spreadFrame.width > 0 {
            let spreadIntersection = spreadFrame.intersection(visibleRect)
            
            if spreadIntersection.isEmpty == false {
                return spreadIntersection.width / spreadFrame.width
            }
        }
        
        return 0
    }
    
    /// Calculate which pages are visible within a certain rect. Called frequently.
    fileprivate static func calc_visiblePageIndexes(in visibleRect:CGRect, pageFrames:[CGRect], fullyVisible:Bool) -> IndexSet {
    
        // TODO: optimize?
        
        let visiblePageIndexes = NSMutableIndexSet()
        for (pageIndex, pageFrame) in pageFrames.enumerated() {
            
            if (fullyVisible && visibleRect.contains(pageFrame)) ||
                (!fullyVisible && visibleRect.intersects(pageFrame)){
                visiblePageIndexes.add(pageIndex)
            }
        }
        
        return visiblePageIndexes as IndexSet
    }
    
}





// MARK: - Utility Zooming View subclass
extension VersoView {
    
    // A Utility zooming view that will modify the contentInsets to keep the content matching a target frame
    class InsetZoomView : UIScrollView {
        
        /// This is the frame we wish the contentsView to occupy. contentInset is adjusted to maintain that frame.
        /// If this is nil the contents will be centered
        var targetContentFrame:CGRect? {
            didSet {
                _updateZoomContentInsets()
            }
        }
        override func layoutSublayers(of layer: CALayer) {
            super.layoutSublayers(of: layer)
            
            _updateZoomContentInsets()
        }
        
        fileprivate func _updateZoomContentInsets() {
            
            if let contentView = delegate?.viewForZooming?(in: self) {
                self.contentInset = _targetedInsets(contentView)
            }
        }
        
        fileprivate func _targetedInsets(_ contentView:UIView) -> UIEdgeInsets {
            
            var edgeInset = UIEdgeInsets.zero
            
            // the goal frame of the contentsView when not zoomed in
            let unscaledTargetFrame = self.targetContentFrame ?? CGRect(origin:CGPoint(x: bounds.midX-(contentView.bounds.size.width/2), y: bounds.midY-(contentView.bounds.size.height/2)), size:contentView.bounds.size)
            
            // calc what percentage of non-contents space the origin distance is
            var percentageOfRemainingSpace = CGPoint.zero
            percentageOfRemainingSpace.x = bounds.size.width != unscaledTargetFrame.size.width ? unscaledTargetFrame.origin.x/(bounds.size.width-unscaledTargetFrame.size.width) : 1
            percentageOfRemainingSpace.y = bounds.size.height != unscaledTargetFrame.size.height ? unscaledTargetFrame.origin.y/(bounds.size.height-unscaledTargetFrame.size.height) : 1
            
            
            // scale the contentFrame's origin based on desired percentage of remaining space
            var scaledTargetFrame = contentView.frame
            scaledTargetFrame.origin.x = (bounds.size.width - scaledTargetFrame.size.width) * percentageOfRemainingSpace.x
            scaledTargetFrame.origin.y = (bounds.size.height - scaledTargetFrame.size.height) * percentageOfRemainingSpace.y
            
            
            if bounds.size.height > scaledTargetFrame.size.height {
                edgeInset.top = scaledTargetFrame.origin.y + (bounds.origin.y - contentOffset.y)
                edgeInset.bottom = edgeInset.top
            }
            if bounds.size.width > scaledTargetFrame.size.width {
                edgeInset.left = scaledTargetFrame.origin.x + (bounds.origin.x - contentOffset.x)
                edgeInset.right = edgeInset.left
            }
            
            return edgeInset
        }
    }
}








// MARK: - SpreadConfiguration & Properties

/// This contains all the properties necessary to configure a single spread.
@objc public class VersoSpreadProperty : NSObject {
    let pageIndexes:[Int]
    let maxZoomScale:CGFloat
    let widthPercentage:CGFloat
    
    public init(pageIndexes:[Int], maxZoomScale:CGFloat = 4.0, widthPercentage:CGFloat = 1.0) {
        
        assert(pageIndexes.count <= 2, "VersoSpreadProperties does not currently support more than 2 pages in a spread (\(pageIndexes))")
        assert(pageIndexes.count >= 1, "VersoSpreadProperties does not currently support empty spreads")
        
        self.pageIndexes = pageIndexes
        self.maxZoomScale = max(maxZoomScale, 1.0)
        self.widthPercentage = max(min(widthPercentage, 1.0), 0.0)
    }
    
    
    
    // MARK: Equatable
    override public func isEqual(_ object: Any?) -> Bool {
        if let object = object as? VersoSpreadProperty {
            if maxZoomScale != object.maxZoomScale || widthPercentage != object.widthPercentage {
                return false
            }
            return pageIndexes == object.pageIndexes
        } else {
            return false
        }
    }
    
    override public var hash: Int {
        return (pageIndexes as NSArray).hashValue ^ maxZoomScale.hashValue ^ widthPercentage.hashValue
    }
}



/// This contains the properties of all the spreads in a VersoView
@objc public class VersoSpreadConfiguration : NSObject {
    public let spreadProperties:[VersoSpreadProperty]
    
    public fileprivate(set) var pageCount:Int = 0
    public fileprivate(set) var spreadCount:Int = 0
    public fileprivate(set) var spreadSpacing:CGFloat = 0
    
    public init(_ spreadProperties:[VersoSpreadProperty], spreadSpacing:CGFloat = 0) {
        self.spreadProperties = spreadProperties
        
        self.spreadCount = spreadProperties.count
        
        // calculate pageCount
        var newPageCount = 0
        for (_, properties) in spreadProperties.enumerated() {
            newPageCount += properties.pageIndexes.count
        }
        self.pageCount = newPageCount
        
        self.spreadSpacing = spreadSpacing
    }
    
    
    func spreadIndex(forPageIndex pageIndex:Int) -> Int? {
        for (spreadIndex, properties) in self.spreadProperties.enumerated() {
            if properties.pageIndexes.contains(pageIndex) {
                return spreadIndex
            }
        }
        return nil
    }
    
    func pageIndexes(forSpreadIndex spreadIndex:Int) -> IndexSet {
        let pageIndexes = NSMutableIndexSet()
        
        if let properties = spreadProperties[verso_safe:spreadIndex] {
            for pageIndex in properties.pageIndexes {
                pageIndexes.add(pageIndex)
            }
        }
        return pageIndexes as IndexSet
    }

    func spreadProperty(forSpreadIndex spreadIndex:Int) -> VersoSpreadProperty? {
        return spreadProperties[verso_safe:spreadIndex]
    }
    func spreadProperty(forPageIndex pageIndex:Int) -> VersoSpreadProperty? {
        if let spreadIndex = spreadIndex(forPageIndex: pageIndex) {
            return spreadProperty(forSpreadIndex:spreadIndex)
        }
        return nil
    }
    
    
    
    // MARK: Equatable
    override public func isEqual(_ object: Any?) -> Bool {
        if let object = object as? VersoSpreadConfiguration {
            if pageCount != object.pageCount || spreadCount != object.spreadCount {
                return false
            }
            return (spreadProperties as NSArray).isEqual(to: object.spreadProperties)
        } else {
            return false
        }
    }
    
    override public var hash: Int {
        return (spreadProperties as NSArray).hashValue
    }
    
    
    override public var description: String {
        
        var propertyStr:String = ""
        for property in spreadProperties {
            propertyStr += "["
            for pageIndex in property.pageIndexes {
                propertyStr += "[\(pageIndex)]"
            }
            propertyStr += "]"
        }
        
        return "<VersoSpreadConfiguration \(pageCount) pages, \(spreadCount) spreads \(propertyStr)>"
    }
}




// MARK: VersoSpreadProperty: Spread Type

extension VersoSpreadProperty {
    
    enum SpreadType {
        case none
        case single(pageIndex:Int)
        case double(versoIndex:Int, rectoIndex:Int)
        
        
        // get a set of all the page indexes
        func allPageIndexes() -> IndexSet {
            
            let pageIndexes = NSMutableIndexSet()
            switch self {
            case let .single(pageIndex):
                pageIndexes.add(pageIndex)
            case let .double(verso, recto):
                pageIndexes.add(verso)
                pageIndexes.add(recto)
            default:break
            }
            return pageIndexes as IndexSet
        }
    }
    
    
    func getSpreadType() -> SpreadType {
        
        if pageIndexes.count == 1 {
            return .single(pageIndex: pageIndexes[0])
        }
        else if pageIndexes.count == 2 {
            return .double(versoIndex: pageIndexes[0], rectoIndex: pageIndexes[1])
        }
        else {
            return .none
        }
    }
}

extension VersoSpreadProperty.SpreadType: Equatable { }
func ==(lhs: VersoSpreadProperty.SpreadType, rhs: VersoSpreadProperty.SpreadType) -> Bool {
    switch (lhs, rhs) {
    case (let .single(pageIndex1), let .single(pageIndex2)):
        return pageIndex1 == pageIndex2
        
    case (let .double(verso1, recto1), let .double(verso2, recto2)):
        return verso1 == verso2 && recto1 == recto2
        
    case (.none, .none):
        return true
        
    default:
        return false
    }
}

extension VersoSpreadConfiguration {
    func spreadType(forSpreadIndex spreadIndex:Int) -> VersoSpreadProperty.SpreadType {
        return spreadProperty(forSpreadIndex:spreadIndex)?.getSpreadType() ?? .none
    }
}





// MARK: VersoSpreadProperty: Page Alignment

extension VersoSpreadProperty {
    enum SpreadPageAlignment {
        case center
        case left
        case right
    }
    
    func pageAlignment(forPageIndex pageIndex:Int) -> SpreadPageAlignment {
        
        guard pageIndexes.contains(pageIndex) else {
            return .center
        }
        
        let type = getSpreadType()
            
        switch type {
        case let .double(versoIndex, _) where versoIndex == pageIndex:
            return .right
        case let .double(_, rectoIndex) where rectoIndex == pageIndex:
            return .left
        default:
            return .center
        }
    }
    
}

extension VersoSpreadConfiguration {
    
    func pageAlignment(forPageIndex pageIndex:Int) -> VersoSpreadProperty.SpreadPageAlignment {
        if let properties = spreadProperty(forPageIndex:pageIndex) {
            return properties.pageAlignment(forPageIndex:pageIndex)
        }
        return .center
    }
}








// MARK: Configuration utility constructors

extension VersoSpreadConfiguration {
    
    /// This is a utility configuration builder that helps you construct a SpreadConfiguration.
    public static func buildPageSpreadConfiguration(pageCount:Int, spreadSpacing:CGFloat, spreadPropertyConstructor:((_ spreadIndex:Int, _ nextPageIndex:Int)->(spreadPageCount:Int, maxZoomScale:CGFloat, widthPercentage:CGFloat))? = nil) -> VersoSpreadConfiguration {
        
        var spreadProperties:[VersoSpreadProperty] = []
        
        var nextPageIndex = 0
        
        var spreadIndex = 0
        while nextPageIndex < pageCount {
            
            let constructorResults = spreadPropertyConstructor?(spreadIndex, nextPageIndex) ?? (spreadPageCount:1, maxZoomScale:4.0, widthPercentage:1.0)

            
            let lastSpreadPageIndex = min(nextPageIndex + max(constructorResults.spreadPageCount,1) - 1, pageCount - 1)
            
            var pageIndexes:[Int] = []
            for pageIndex in nextPageIndex ... lastSpreadPageIndex {
                pageIndexes.append(pageIndex)
            }
            
            
            let properties = VersoSpreadProperty(pageIndexes: pageIndexes, maxZoomScale:constructorResults.maxZoomScale, widthPercentage:constructorResults.widthPercentage)
            
            spreadProperties.append(properties)
            
            nextPageIndex += pageIndexes.count
            spreadIndex += 1
        }
        

        return VersoSpreadConfiguration(spreadProperties, spreadSpacing: spreadSpacing)
    }
}



// MARK: - Double-Tappable ScrollView

import ObjectiveC
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


private var doubleTapGestureAssociationKey: UInt8 = 0
private var doubleTapAnimatedAssociationKey: UInt8 = 0

extension UIScrollView {
    /// The double-tap gesture that performs the zoom
    /// This is nil until `sgn_enableDoubleTapGestures` is called
    public fileprivate(set) var sgn_doubleTapGesture:UITapGestureRecognizer? {
        get {
            return objc_getAssociatedObject(self, &doubleTapGestureAssociationKey) as? UITapGestureRecognizer
        }
        set(newValue) {
            objc_setAssociatedObject(self, &doubleTapGestureAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    /// Should the double-tap zoom be animated? Defaults to true
    public var sgn_doubleTapZoomAnimated:Bool {
        get {
            return objc_getAssociatedObject(self, &doubleTapAnimatedAssociationKey) as? Bool ?? true
        }
        set(newValue) {
            objc_setAssociatedObject(self, &doubleTapAnimatedAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    /// This will create, add, and enable, the double-tap gesture to this scrollview.
    public func sgn_enableDoubleTapGestures() {
        var doubleTap = sgn_doubleTapGesture
        if doubleTap == nil {
            doubleTap = UITapGestureRecognizer(target: self, action: #selector(UIScrollView._sgn_didDoubleTap(_:)))
            doubleTap!.numberOfTapsRequired = 2
            
            sgn_doubleTapGesture = doubleTap
        }

        addGestureRecognizer(doubleTap!)
        doubleTap!.isEnabled = true
    }
    
    /// This will remove and nil-out the double-tap gesture.
    public func sgn_disableDoubleTapGestures() {
        guard let doubleTap = sgn_doubleTapGesture else {
            return
        }
        
        removeGestureRecognizer(doubleTap)
        sgn_doubleTapGesture = nil
    }
    
    
    
    
    
    @objc
    fileprivate func _sgn_didDoubleTap(_ tap:UITapGestureRecognizer) {
        guard tap.state == .ended else {
            return
        }
        
        // no-op if zoom is disabled
        guard pinchGestureRecognizer != nil && pinchGestureRecognizer!.isEnabled == true else {
            return
        }
        
        // no zoom, so eject
        guard minimumZoomScale < maximumZoomScale else {
            return
        }
        
        guard let zoomedView = delegate?.viewForZooming?(in: self) else {
            return
        }
        
        // fake 'willBegin'
        delegate?.scrollViewWillBeginZooming?(self, with:zoomedView)

        let zoomedIn = zoomScale > minimumZoomScale
        
        
        let zoomAnimations = {
            if zoomedIn {
                // zoomed in - so zoom out again
                self.setZoomScale(self.minimumZoomScale, animated: false)
            }
            else {
                // zoomed out - find the rect we want to zoom to
                let targetScale = self.maximumZoomScale
                let targetCenter = tap.location(in: zoomedView)
                    //zoomedView.convertPoint(tap.locationInView(self), fromView: self)
                
                var targetZoomRect = CGRect.zero
                targetZoomRect.size = CGSize(width: zoomedView.frame.size.width / targetScale,
                                             height: zoomedView.frame.size.height / targetScale)
                
                targetZoomRect.origin = CGPoint(x: targetCenter.x - ((targetZoomRect.size.width / 2.0)),
                                                y: targetCenter.y - ((targetZoomRect.size.height / 2.0)))
                
                self.zoom(to: targetZoomRect, animated: false)
            }

        }
    
        
        let animated = sgn_doubleTapZoomAnimated
        
        // here we use a custom animation to make zooming faster/nicer
        let duration:TimeInterval = zoomedIn ? 0.30 : 0.40
        let damping:CGFloat = zoomedIn ? 0.9 : 0.8
        let initialVelocity:CGFloat = zoomedIn ? 0.9 : 0.75

    
        UIView.animate(withDuration: animated ? duration : 0, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: initialVelocity, options: [.beginFromCurrentState], animations: zoomAnimations) { [weak self] finished in
            
            if self != nil && finished {
                // fake 'didZoom'
                self!.delegate?.scrollViewDidEndZooming?(self!, with:zoomedView, atScale:self!.zoomScale)
            }
        }
    }
}



private extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (verso_safe index: Index) -> Iterator.Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}

