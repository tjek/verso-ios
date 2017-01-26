
import UIKit

import Verso


class PlanetsViewController: UIViewController {
    
    lazy var versoView:VersoView = {
        let verso = VersoView()
        
        verso.dataSource = self
        verso.delegate = self
        
        verso.frame = self.view.bounds
        verso.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return verso
    }()
    
    var planetData:[String] = {
        return ["Mercury",
                "Venus",
                "Earth",
                "Mars",
                "Jupiter",
                "Saturn",
                "Uranus",
                "Neptune"]
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(versoView)
    }
}



/// The view that renders the planet info
class PlanetPageView : VersoPageView {
    lazy var nameLabel:UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.boldSystemFont(ofSize: 30)
        lbl.adjustsFontSizeToFitWidth = true
        lbl.textColor = UIColor.white
        return lbl
    }()
    
    required init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(nameLabel)
        
        backgroundColor = UIColor.black
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var frame = nameLabel.frame
        frame.size = nameLabel.sizeThatFits(bounds.size)
        nameLabel.frame = frame
        
        nameLabel.center = CGPoint(x:bounds.midX, y:bounds.midY)
    }
}


extension PlanetsViewController : VersoViewDataSource {
    
    
    /// This method is called whenever VersoView is about to relayout.
    /// It gives you a chance to define the configuration of all the spreads.
    func spreadConfiguration(with size:CGSize, for verso:VersoView) -> VersoSpreadConfiguration {
        
        let isLandscape:Bool = size.width > size.height
        
        return VersoSpreadConfiguration.buildPageSpreadConfiguration(pageCount:planetData.count, spreadSpacing: 20, spreadPropertyConstructor: { (spreadIndex, nextPageIndex) -> (spreadPageCount: Int, maxZoomScale: CGFloat, widthPercentage: CGFloat) in
            
            let isFirstPage = nextPageIndex == 0
            
            let isSinglePage = isFirstPage || !isLandscape
            
            let spreadPageCount = isSinglePage ? 1 : 2
            
            return (spreadPageCount, 4.0, 1.0)
        })
    }
    
    /// Gives the dataSource a chance to configure the pageView.
    /// This must not take a long time, as it is called during scrolling.
    /// The pageView's `pageIndex` property will have been set, but its size will not be correct
    func configure(pageView:VersoPageView, for verso:VersoView) {
        
        guard let planetPage = pageView as? PlanetPageView else {
            return
        }
        
        let planetInfo = planetData[planetPage.pageIndex]
        
        planetPage.nameLabel.text = planetInfo
    }
    
    
    /// What subclass of VersoPageView should be used.
    func pageViewClass(on pageIndex:Int, for verso:VersoView) -> VersoPageViewClass {
        return PlanetPageView.self
    }
    
}

extension PlanetsViewController : VersoViewDelegate {

}




let vc = PlanetsViewController()
vc.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)




import PlaygroundSupport

PlaygroundPage.current.liveView = vc.view
