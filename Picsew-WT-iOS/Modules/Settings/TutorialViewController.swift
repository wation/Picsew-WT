import UIKit

class TutorialViewController: UIViewController, UIScrollViewDelegate {
    
    private let tutorials = [
        "1. Use the video capture feature to record your screen",
        "2. Import existing videos from your photo library",
        "3. Auto stitch will automatically combine your screenshots",
        "4. Manual stitch allows you to adjust each image manually",
        "5. Export your long screenshot in different formats"
    ]
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.isPagingEnabled = true
        return scrollView
    }()
    
    private lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.numberOfPages = tutorials.count
        pageControl.currentPage = 0
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
        return pageControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Tutorial"
        
        view.addSubview(scrollView)
        view.addSubview(pageControl)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor),
            
            pageControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            pageControl.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        setupTutorialPages()
    }
    
    private func setupTutorialPages() {
        let pageWidth = view.frame.width
        let pageHeight = scrollView.frame.height
        
        scrollView.contentSize = CGSize(width: pageWidth * CGFloat(tutorials.count), height: pageHeight)
        
        for (index, tutorial) in tutorials.enumerated() {
            let pageView = UIView(frame: CGRect(x: pageWidth * CGFloat(index), y: 0, width: pageWidth, height: pageHeight))
            
            let label = UILabel()
            label.text = tutorial
            label.textAlignment = .center
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            
            pageView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: pageView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: pageView.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: pageView.trailingAnchor, constant: -20)
            ])
            
            scrollView.addSubview(pageView)
        }
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let width = scrollView.frame.width
        if width > 0 {
            let pageIndex = Int(scrollView.contentOffset.x / width)
            pageControl.currentPage = pageIndex
        }
    }
    
    // MARK: - Actions
    
    @objc private func pageControlChanged(_ pageControl: UIPageControl) {
        let pageIndex = pageControl.currentPage
        scrollView.setContentOffset(CGPoint(x: scrollView.frame.width * CGFloat(pageIndex), y: 0), animated: true)
    }
}
