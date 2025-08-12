import GoogleMobileAds
import UIKit

class NewsArticleNativeAdFactory: FLTNativeAdFactory {
    
    func createNativeAd(_ nativeAd: GADNativeAd, customOptions: [AnyHashable : Any]? = nil) -> GADNativeAdView? {
        
        // Create the native ad view programmatically to match your news article design
        let adView = GADNativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.backgroundColor = UIColor.black
        
        // Create main container
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(containerView)
        
        // Create media view for ad image/video
        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.backgroundColor = UIColor.darkGray
        mediaView.layer.cornerRadius = 12
        mediaView.clipsToBounds = true
        containerView.addSubview(mediaView)
        
        // Create headline label (title)
        let headlineLabel = UILabel()
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.font = UIFont.boldSystemFont(ofSize: 18)
        headlineLabel.textColor = UIColor.white
        headlineLabel.numberOfLines = 2
        headlineLabel.text = nativeAd.headline
        containerView.addSubview(headlineLabel)
        
        // Create body label (description)
        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = UIFont.systemFont(ofSize: 16)
        bodyLabel.textColor = UIColor.lightGray
        bodyLabel.numberOfLines = 0
        bodyLabel.text = nativeAd.body
        containerView.addSubview(bodyLabel)
        
        // Create bottom container
        let bottomContainer = UIView()
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        bottomContainer.layer.cornerRadius = 12
        containerView.addSubview(bottomContainer)
        
        // Create icon image view
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.backgroundColor = UIColor.darkGray
        iconView.layer.cornerRadius = 20
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        if let icon = nativeAd.icon {
            iconView.image = icon.image
        }
        bottomContainer.addSubview(iconView)
        
        // Create advertiser label
        let advertiserLabel = UILabel()
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        advertiserLabel.font = UIFont.boldSystemFont(ofSize: 13)
        advertiserLabel.textColor = UIColor.white
        advertiserLabel.text = nativeAd.advertiser ?? "Advertiser"
        bottomContainer.addSubview(advertiserLabel)
        
        // Create sponsored label
        let sponsoredLabel = UILabel()
        sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
        sponsoredLabel.font = UIFont.systemFont(ofSize: 10)
        sponsoredLabel.textColor = UIColor.lightGray
        sponsoredLabel.text = "Sponsored"
        bottomContainer.addSubview(sponsoredLabel)
        
        // Create call to action button
        let ctaButton = UIButton(type: .system)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.backgroundColor = UIColor.orange
        ctaButton.setTitleColor(UIColor.white, for: .normal)
        ctaButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        ctaButton.layer.cornerRadius = 18
        ctaButton.setTitle(nativeAd.callToAction ?? "Learn More", for: .normal)
        bottomContainer.addSubview(ctaButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Container constraints
            containerView.topAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.topAnchor, constant: 70),
            containerView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Media view constraints
            mediaView.topAnchor.constraint(equalTo: containerView.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            mediaView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.3),
            
            // Headline constraints
            headlineLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 16),
            headlineLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headlineLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Body constraints
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Bottom container constraints
            bottomContainer.topAnchor.constraint(greaterThanOrEqualTo: bodyLabel.bottomAnchor, constant: 16),
            bottomContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bottomContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Icon constraints
            iconView.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: bottomContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
            
            // Advertiser label constraints
            advertiserLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            advertiserLabel.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 12),
            
            // Sponsored label constraints
            sponsoredLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            sponsoredLabel.topAnchor.constraint(equalTo: advertiserLabel.bottomAnchor, constant: 2),
            
            // CTA button constraints
            ctaButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor, constant: -16),
            ctaButton.centerYAnchor.constraint(equalTo: bottomContainer.centerYAnchor),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            ctaButton.heightAnchor.constraint(equalToConstant: 36),
        ])
        
        // Register views with the native ad
        adView.mediaView = mediaView
        adView.headlineView = headlineLabel
        adView.bodyView = bodyLabel
        adView.iconView = iconView
        adView.advertiserView = advertiserLabel
        adView.callToActionView = ctaButton
        
        // Set the native ad
        adView.nativeAd = nativeAd
        
        return adView
    }
}